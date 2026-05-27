import { Controller, Get, Inject, Optional } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import IORedis from 'ioredis';

import { PrismaService } from '../../common/prisma/prisma.service';
import { REDIS } from '../../common/redis/redis.module';

/**
 * Health endpoint — extended in B7 for richer ops observability.
 *
 * Audit production-killer §6 ("Observability is the weakest layer"): the
 * previous version only said db+cache ok. Operators couldn't tell whether
 * the system was healthy-but-slow, queue-backed-up, or about to OOM. The
 * new payload includes:
 *
 *   - db          : SELECT 1 returns (cache: true/false)
 *   - dbLatencyMs : roundtrip time, surfaces PgBouncer / network issues
 *   - cache       : redis PING returns (true/false)
 *   - cacheLatencyMs : redis roundtrip
 *   - queues      : { otp:email, push:fcm } depth — alerts on backup
 *   - memory      : process RSS / heap usage in MB
 *   - uptime      : seconds since boot
 *   - version     : HNAG_VERSION env (commit SHA or tag)
 *   - ts          : ISO timestamp
 *
 * `ok` is true only when EVERY critical sub-check passes. Returns 200
 * with `ok=false` so external monitors (UptimeRobot, healthchecks.io)
 * can pick up the granular state without paging on a false 500.
 *
 * Queue counts are best-effort: if BullMQ isn't bound (unit-test boot,
 * dev without Redis-with-queues), they're reported as null rather than
 * tanking the whole endpoint.
 */
@ApiTags('Health')
@Controller('/health')
export class HealthController {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(REDIS) private readonly redis: IORedis,
    @Optional() @InjectQueue('otp-email') private readonly otpQueue?: Queue,
    @Optional() @InjectQueue('push-fcm') private readonly pushQueue?: Queue,
  ) {}

  @Get()
  async health() {
    const t0 = Date.now();
    const [dbResult, cacheResult, queueStats] = await Promise.all([
      this.timed(() => this.prisma.$queryRawUnsafe('SELECT 1')),
      this.timed(() => this.redis.ping()),
      this.gatherQueueStats(),
    ]);

    const db = dbResult.ok;
    const cache = cacheResult.ok && cacheResult.value === 'PONG';
    const mem = process.memoryUsage();
    const payload = {
      ok: db && cache,
      db,
      dbLatencyMs: dbResult.ms,
      cache,
      cacheLatencyMs: cacheResult.ms,
      queues: queueStats,
      memory: {
        rssMb: Math.round(mem.rss / 1024 / 1024),
        heapUsedMb: Math.round(mem.heapUsed / 1024 / 1024),
        heapTotalMb: Math.round(mem.heapTotal / 1024 / 1024),
      },
      uptimeSec: Math.round(process.uptime()),
      version: process.env.HNAG_VERSION ?? 'dev',
      sentry: process.env.SENTRY_DSN ? 'configured' : 'disabled',
      checkLatencyMs: Date.now() - t0,
      ts: new Date().toISOString(),
    };
    return { __raw__: true, payload };
  }

  // ── helpers ─────────────────────────────────────────────────────────

  private async timed<T>(fn: () => Promise<T>): Promise<{ ok: boolean; ms: number; value?: T }> {
    const t = Date.now();
    try {
      const value = await fn();
      return { ok: true, ms: Date.now() - t, value };
    } catch {
      return { ok: false, ms: Date.now() - t };
    }
  }

  private async gatherQueueStats() {
    const out: Record<string, { waiting: number; active: number; failed: number; delayed: number } | null> = {
      'otp-email': null,
      'push-fcm': null,
    };
    if (this.otpQueue) {
      try { out['otp-email'] = await this.queueDepth(this.otpQueue); } catch {/* leave null */}
    }
    if (this.pushQueue) {
      try { out['push-fcm'] = await this.queueDepth(this.pushQueue); } catch {/* leave null */}
    }
    return out;
  }

  private async queueDepth(q: Queue) {
    const counts = await q.getJobCounts('waiting', 'active', 'failed', 'delayed');
    return {
      waiting: counts.waiting ?? 0,
      active: counts.active ?? 0,
      failed: counts.failed ?? 0,
      delayed: counts.delayed ?? 0,
    };
  }
}
