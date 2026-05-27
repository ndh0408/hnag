import { Inject, Logger } from '@nestjs/common';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { JwtService } from '@nestjs/jwt';
import IORedis from 'ioredis';
import { PrismaService } from '../../common/prisma/prisma.service';
import { REDIS } from '../../common/redis/redis.module';
import { RoomEventStreamService } from './room-stream.service';

const wsCorsOrigins = (process.env.CORS_ORIGINS ?? '')
  .split(',')
  .map((o) => o.trim())
  .filter(Boolean);

@WebSocketGateway({
  cors: { origin: wsCorsOrigins.length ? wsCorsOrigins : false, credentials: true },
  transports: ['websocket'],
  // Audit realtime-trace §9, §10: Vietnamese carrier NAT timeouts can be
  // ≤30s. Defaults are pingInterval 25s / pingTimeout 20s — adequate for
  // wifi but tight for mobile. Tighten both so dead clients are surfaced
  // sooner without blowing battery.
  pingInterval: 20_000,
  pingTimeout: 15_000,
})
export class RealtimeGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer() server!: Server;
  private readonly logger = new Logger(RealtimeGateway.name);

  /** Audit realtime-trace §14: cached existence to avoid DB hammer on reconnect storms. */
  private static readonly MEMBERSHIP_TTL_SEC = 60;
  private static readonly RESTAURANT_TTL_SEC = 3600;
  /** Per-socket subscribe budget (audit #3 from original audit). */
  private static readonly SUBSCRIBE_BUCKET_WINDOW_SEC = 60;
  private static readonly SUBSCRIBE_BUCKET_MAX = 30;
  /** Per-user subscribe budget (audit realtime-trace §16/§D) — across all
   *  sockets the user has open, prevents per-socket-rotation bypass. */
  private static readonly USER_SUBSCRIBE_WINDOW_SEC = 60;
  private static readonly USER_SUBSCRIBE_MAX = 90; // ~3 devices × 30
  private static readonly USER_STATUS_TTL_SEC = 60;
  /** App-layer heartbeat tolerance (audit realtime-trace §10). */
  private static readonly HEARTBEAT_INTERVAL_MS = 30_000;
  private static readonly HEARTBEAT_TIMEOUT_MS = 90_000;

  constructor(
    private readonly jwt: JwtService,
    private readonly prisma: PrismaService,
    @Inject(REDIS) private readonly redis: IORedis,
    private readonly stream: RoomEventStreamService,
  ) {}

  async handleConnection(client: Socket) {
    try {
      const token = (client.handshake.auth?.token ?? client.handshake.query?.token) as string;
      if (!token) throw new Error('No token');
      const payload = await this.jwt.verifyAsync(token);
      const userId = payload.sub as string | undefined;
      if (!userId) throw new Error('Token missing sub');

      const active = await this.isUserActiveCached(userId);
      if (!active) throw new Error('User inactive or deleted');

      client.data.userId = userId;
      client.data.subscribeBucketAt = 0;
      client.data.subscribeBucketCount = 0;
      client.data.lastPongAt = Date.now();
      client.join(`user:${userId}`);

      // Schedule app-layer heartbeat watchdog — if client hasn't pong'd in
      // HEARTBEAT_TIMEOUT_MS, terminate. Catches the "TCP up but app frozen"
      // ghost socket described in realtime-trace §10.
      const watchdog = setInterval(() => {
        const last = (client.data.lastPongAt ?? 0) as number;
        if (Date.now() - last > RealtimeGateway.HEARTBEAT_TIMEOUT_MS) {
          this.logger.warn(`WS heartbeat timeout user=${userId} sock=${client.id}`);
          clearInterval(watchdog);
          this.sendForceDisconnect(client, 'heartbeat_timeout', 5);
        }
      }, RealtimeGateway.HEARTBEAT_INTERVAL_MS);
      client.data.watchdog = watchdog;

      this.logger.debug(`WS connect user=${userId}`);
    } catch (e) {
      this.logger.warn(`WS reject: ${(e as Error).message}`);
      client.disconnect(true);
    }
  }

  handleDisconnect(client: Socket) {
    const w = client.data.watchdog as NodeJS.Timeout | undefined;
    if (w) clearInterval(w);
    this.logger.debug(`WS disconnect ${client.id}`);
  }

  // ─── App-layer heartbeat ──────────────────────────────────────────────
  // Audit realtime-trace §10: catches half-open TCP states the transport
  // ping doesn't (NAT in middle keeping the TCP alive while traffic dies).
  @SubscribeMessage('ping')
  ping(@ConnectedSocket() client: Socket, @MessageBody() body: { ts?: number }) {
    client.data.lastPongAt = Date.now();
    return { pong: true, serverTs: Date.now(), clientTs: body?.ts ?? null };
  }

  // ─── subscribe:group with snapshot + replay (audit §3, §6, §16) ───────
  @SubscribeMessage('subscribe:group')
  async joinGroup(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { groupId: string; sinceSeq?: number },
  ) {
    const userId = client.data.userId as string | undefined;
    if (!userId || !isUuid(body?.groupId)) return { ok: false, error: 'bad_request' };

    if (!this.consumeSubscribeBudget(client)) {
      this.logger.warn(`WS subscribe rate-limit (socket) user=${userId}`);
      this.sendForceDisconnect(client, 'rate_limited', 60);
      return { ok: false, error: 'rate_limited' };
    }
    if (!(await this.consumeUserSubscribeBudget(userId))) {
      this.logger.warn(`WS subscribe rate-limit (user) user=${userId}`);
      this.sendForceDisconnect(client, 'rate_limited', 120);
      return { ok: false, error: 'rate_limited' };
    }

    const isMember = await this.isGroupMemberCached(body.groupId, userId);
    if (!isMember) return { ok: false, error: 'not_a_member' };

    client.join(`group:${body.groupId}`);

    // Snapshot: open polls + tally for instant hydration. Audit §6.
    const polls = await this.prisma.group_polls.findMany({
      where: { group_id: body.groupId, status: 'open' },
      orderBy: { created_at: 'desc' },
      take: 5,
      select: { id: true, options: true, votes: true, closes_at: true, status: true },
    });
    const latestSeq = await this.stream.latestSeq(`group:${body.groupId}`);
    // Replay missed events if client provided sinceSeq.
    const missed = typeof body.sinceSeq === 'number'
      ? await this.stream.replay(`group:${body.groupId}`, body.sinceSeq)
      : [];

    return { ok: true, polls, latestSeq, missed };
  }

  @SubscribeMessage('subscribe:restaurant')
  async joinRestaurant(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { restaurantId: string; sinceSeq?: number },
  ) {
    if (!client.data.userId || !isUuid(body?.restaurantId)) {
      return { ok: false, error: 'bad_request' };
    }
    if (!this.consumeSubscribeBudget(client)) {
      this.sendForceDisconnect(client, 'rate_limited', 60);
      return { ok: false, error: 'rate_limited' };
    }
    if (!(await this.consumeUserSubscribeBudget(client.data.userId as string))) {
      this.sendForceDisconnect(client, 'rate_limited', 120);
      return { ok: false, error: 'rate_limited' };
    }
    const exists = await this.restaurantExistsCached(body.restaurantId);
    if (!exists) return { ok: false, error: 'not_found' };
    client.join(`restaurant:${body.restaurantId}`);

    const live = await this.prisma.restaurant_live.findUnique({
      where: { restaurant_id: body.restaurantId },
      select: { is_open: true, crowdedness: true, wait_minutes: true, updated_at: true },
    });
    const latestSeq = await this.stream.latestSeq(`restaurant:${body.restaurantId}`);
    const missed = typeof body.sinceSeq === 'number'
      ? await this.stream.replay(`restaurant:${body.restaurantId}`, body.sinceSeq)
      : [];
    return { ok: true, live, latestSeq, missed };
  }

  // ─── Backwards-compat (deprecated; kept so old clients don't break) ───
  @SubscribeMessage('vote:cast')
  voteCast(@ConnectedSocket() _client: Socket, @MessageBody() _body: any) {
    return { ack: true };
  }

  // ─── Producer helpers — replace direct emit() with stamped broadcast ──
  // Audit realtime-trace §3/§4/§6: every broadcast carries _seq + _ts so
  // clients can dedup + detect ordering. Stream-persisted for replay.

  async broadcastUser(userId: string, event: string, data: Record<string, unknown>): Promise<void> {
    const room = `user:${userId}`;
    const env = await this.stream.stamp(room, event, data);
    this.server.to(room).emit(env.event, env.data);
  }
  async broadcastGroup(groupId: string, event: string, data: Record<string, unknown>): Promise<void> {
    const room = `group:${groupId}`;
    const env = await this.stream.stamp(room, event, data);
    this.server.to(room).emit(env.event, env.data);
  }
  async broadcastRestaurant(restaurantId: string, event: string, data: Record<string, unknown>): Promise<void> {
    const room = `restaurant:${restaurantId}`;
    const env = await this.stream.stamp(room, event, data);
    this.server.to(room).emit(env.event, env.data);
  }

  // ─── internals ────────────────────────────────────────────────────────

  /**
   * Politely tell the client to back off + then disconnect. Replaces the
   * old `client.disconnect(true)` which made socket.io auto-reconnect
   * loop on rate-limit (audit realtime-trace §2/§8).
   */
  private sendForceDisconnect(client: Socket, reason: string, retryAfterSec: number) {
    try {
      client.emit('force_disconnect', { reason, retryAfterSec });
      // Give the emit a beat to flush before tearing down the transport.
      setTimeout(() => {
        try { client.disconnect(true); } catch {/* swallow */}
      }, 250);
    } catch {
      try { client.disconnect(true); } catch {/* swallow */}
    }
  }

  private consumeSubscribeBudget(client: Socket): boolean {
    const now = Date.now();
    const winAgo = (client.data.subscribeBucketAt ?? 0) as number;
    if (now - winAgo > RealtimeGateway.SUBSCRIBE_BUCKET_WINDOW_SEC * 1000) {
      client.data.subscribeBucketAt = now;
      client.data.subscribeBucketCount = 0;
    }
    const next = ((client.data.subscribeBucketCount ?? 0) as number) + 1;
    client.data.subscribeBucketCount = next;
    return next <= RealtimeGateway.SUBSCRIBE_BUCKET_MAX;
  }

  /** Per-userId subscribe budget shared across all of the user's sockets. */
  private async consumeUserSubscribeBudget(userId: string): Promise<boolean> {
    const key = `ws:subbudget:user:${userId}`;
    const count = await this.redis.incr(key);
    if (count === 1) await this.redis.expire(key, RealtimeGateway.USER_SUBSCRIBE_WINDOW_SEC);
    return count <= RealtimeGateway.USER_SUBSCRIBE_MAX;
  }

  private async isUserActiveCached(userId: string): Promise<boolean> {
    const key = `ws:userstatus:${userId}`;
    try {
      const cached = await this.redis.get(key);
      if (cached === 'active') return true;
      if (cached === 'inactive') return false;
    } catch {/* fall through */}
    const u = await this.prisma.users.findUnique({ where: { id: userId }, select: { status: true } });
    const ok = !!u && u.status === 'active';
    try {
      await this.redis.setex(key, RealtimeGateway.USER_STATUS_TTL_SEC, ok ? 'active' : 'inactive');
    } catch {/* best-effort */}
    return ok;
  }

  private async isGroupMemberCached(groupId: string, userId: string): Promise<boolean> {
    const key = `ws:gmember:${groupId}:${userId}`;
    try {
      const cached = await this.redis.get(key);
      if (cached === '1') return true;
      if (cached === '0') return false;
    } catch {/* fall through */}
    const member = await this.prisma.group_members.findUnique({
      where: { group_id_user_id: { group_id: groupId, user_id: userId } },
    });
    const ok = !!member;
    try {
      await this.redis.setex(key, RealtimeGateway.MEMBERSHIP_TTL_SEC, ok ? '1' : '0');
    } catch {/* best-effort */}
    return ok;
  }

  private async restaurantExistsCached(restaurantId: string): Promise<boolean> {
    const key = `ws:restexists:${restaurantId}`;
    try {
      const cached = await this.redis.get(key);
      if (cached === '1') return true;
      if (cached === '0') return false;
    } catch {/* fall through */}
    const r = await this.prisma.restaurants.findUnique({
      where: { id: restaurantId },
      select: { id: true },
    });
    const ok = !!r;
    try {
      await this.redis.setex(key, RealtimeGateway.RESTAURANT_TTL_SEC, ok ? '1' : '0');
    } catch {/* best-effort */}
    return ok;
  }
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
function isUuid(s: unknown): s is string {
  return typeof s === 'string' && UUID_RE.test(s);
}
