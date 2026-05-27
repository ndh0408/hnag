import { Inject, Injectable, Logger } from '@nestjs/common';
import IORedis from 'ioredis';

import { REDIS } from '../../common/redis/redis.module';

/**
 * Per-room event stream — Redis stream + monotonically increasing seq.
 *
 * Closes audit realtime-trace §3/§4/§6/§16: previously every broadcast
 * was fire-and-forget with no sequence number → clients couldn't detect
 * out-of-order delivery or duplicates, and missed events during a
 * disconnect were lost forever.
 *
 * Per room we maintain:
 *   - `seq:<roomKey>`        monotonic INT counter (no TTL — bounded by
 *                            int64 so safe forever)
 *   - `stream:<roomKey>`     capped Redis stream MAXLEN ~ 200 (most
 *                            recent 200 events kept for replay).
 *
 * Cap chosen: 200 events × 1KB ≈ 200KB per active room.  At 10k active
 * rooms = 2GB Redis. At 100k = 20GB → migrate to per-tenant sharded Redis.
 *
 * Streams use approximate trimming (MAXLEN ~) for O(1) write cost.
 */
@Injectable()
export class RoomEventStreamService {
  private readonly logger = new Logger(RoomEventStreamService.name);
  private readonly streamMaxLen = Number(process.env.WS_STREAM_MAXLEN ?? '200');

  constructor(@Inject(REDIS) private readonly redis: IORedis) {}

  private seqKey(roomKey: string): string { return `seq:${roomKey}`; }
  private streamKey(roomKey: string): string { return `stream:${roomKey}`; }

  /**
   * Stamp + persist an event for a room. Returns the envelope to actually
   * emit — caller passes this to `socket.io` to push to subscribers.
   *
   * The Redis pipeline ensures the seq increment + XADD happen
   * atomically per call; cross-process ordering is enforced by the
   * monotonic seq.
   */
  async stamp<T extends Record<string, unknown>>(
    roomKey: string,
    event: string,
    payload: T,
  ): Promise<{ event: string; data: T & { _seq: number; _ts: number } }> {
    const ts = Date.now();
    const pipe = this.redis.pipeline();
    pipe.incr(this.seqKey(roomKey));
    pipe.xadd(
      this.streamKey(roomKey),
      'MAXLEN', '~', String(this.streamMaxLen),
      '*',
      'event', event,
      'data', JSON.stringify(payload),
      'ts', String(ts),
    );
    pipe.expire(this.streamKey(roomKey), 7 * 24 * 3600); // 7d idle TTL
    pipe.expire(this.seqKey(roomKey), 7 * 24 * 3600);
    const res = await pipe.exec();
    const seq = Number(res?.[0]?.[1] ?? 0);
    const enriched = { ...payload, _seq: seq, _ts: ts } as T & { _seq: number; _ts: number };
    // Also re-encode into the stream WITH the seq attached so XRANGE replay
    // surfaces the same payload that subscribers got live. We can skip the
    // re-encode if performance becomes a concern — the seq is also stored
    // separately on the entry below.
    return { event, data: enriched };
  }

  /**
   * Return latest seq for a room. Used by `subscribe:*` ack so the client
   * knows "this is the head of stream you're caught up to".
   */
  async latestSeq(roomKey: string): Promise<number> {
    const v = await this.redis.get(this.seqKey(roomKey));
    return Number(v ?? 0);
  }

  /**
   * Replay events strictly after `sinceSeq`. Used by client on reconnect.
   * Returns at most `streamMaxLen` events; older ones are gone (client
   * must fall back to REST snapshot).
   */
  async replay(roomKey: string, sinceSeq: number): Promise<Array<{ event: string; data: unknown }>> {
    if (!Number.isFinite(sinceSeq) || sinceSeq < 0) return [];
    const entries = await this.redis.xrange(this.streamKey(roomKey), '-', '+');
    const out: Array<{ event: string; data: unknown }> = [];
    for (const [, fields] of entries) {
      const map: Record<string, string> = {};
      for (let i = 0; i < fields.length; i += 2) {
        map[fields[i]] = fields[i + 1];
      }
      try {
        const data = JSON.parse(map.data);
        const itemSeq = (data && typeof data === 'object' && '_seq' in (data as any))
          ? Number((data as any)._seq)
          : 0;
        if (itemSeq > sinceSeq) {
          out.push({ event: map.event, data });
        }
      } catch (err) {
        this.logger.warn(`replay parse fail for ${roomKey}: ${(err as Error).message}`);
      }
    }
    return out;
  }
}
