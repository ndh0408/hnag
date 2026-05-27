import { Controller, Get, Inject, Query, Optional, BadRequestException } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import IORedis from 'ioredis';

import { Roles } from '../common/decorators/roles.decorator';
import { Audit } from '../common/interceptors/audit-log.interceptor';
import { PrismaService } from '../common/prisma/prisma.service';
import { REDIS } from '../common/redis/redis.module';

/**
 * Admin observability surface.
 *
 * Audit production-killer §6 — operators previously had no in-app way to
 * see queue depth, AI spend, slow-query trends, etc. (only via `docker
 * logs` + `redis-cli`). This controller exposes those signals over HTTP
 * behind `@Roles('admin', 'super_admin')`.
 *
 * Every endpoint is also tagged with `@Audit(...)` so the access pattern
 * itself is recorded in `analytics_events`. If a curious admin starts
 * pulling spend reports more often than expected, ops can spot it.
 *
 * NB: these routes are intentionally NOT under /v1 — they're operator
 * tools, not part of the public API contract. Path is `/admin/...`.
 */
@ApiTags('Admin · Observability')
@Controller('admin')
export class ObservabilityController {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(REDIS) private readonly redis: IORedis,
    @Optional() @InjectQueue('otp-email') private readonly otpQueue?: Queue,
    @Optional() @InjectQueue('push-fcm') private readonly pushQueue?: Queue,
  ) {}

  /**
   * Snapshot of every queue's depth. Use this from a Grafana scrape job
   * or just curl when investigating a notification backlog.
   */
  @Roles('admin', 'super_admin')
  @Audit({ event: 'admin.observability.queues', level: 'info' })
  @Get('queues')
  async queues() {
    const out: Record<string, any> = {};
    if (this.otpQueue) out['otp-email'] = await this.summarize(this.otpQueue);
    if (this.pushQueue) out['push-fcm'] = await this.summarize(this.pushQueue);
    return { queues: out, ts: new Date().toISOString() };
  }

  /**
   * AI spend report — sum + per-user breakdown of llm_cost_usd over a
   * date window. Defaults to the last 7 days. Pairs with the daily Redis
   * counter (`ai:spend:<userId>:<YYYY-MM-DD>`) for real-time alerting.
   *
   * Query:
   *   ?from=2026-05-20  inclusive ISO date
   *   ?to=2026-05-27    inclusive ISO date
   *   ?top=20           how many top spenders to list
   */
  @Roles('admin', 'super_admin')
  @Audit({ event: 'admin.observability.ai_spend', level: 'warn' })
  @Get('ai-spend')
  async aiSpend(
    @Query('from') fromStr?: string,
    @Query('to') toStr?: string,
    @Query('top') topStr?: string,
  ) {
    const to = parseDate(toStr) ?? new Date();
    const from = parseDate(fromStr) ?? new Date(Date.now() - 7 * 24 * 3600 * 1000);
    if (from > to) throw new BadRequestException('from > to');
    const topN = Math.min(Math.max(Number(topStr ?? '20'), 1), 200);

    // Aggregate spend per user. Decimal column → Prisma returns a string-y
    // Decimal; cast in SQL so we get JS numbers in the response.
    const rows: any[] = await this.prisma.$queryRawUnsafe(
      `SELECT user_id,
              SUM(llm_cost_usd)::float8 AS total_usd,
              COUNT(*)::int             AS sessions,
              AVG(latency_ms)::int      AS avg_latency_ms,
              MAX(created_at)           AS last_at
         FROM ai_sessions
        WHERE created_at >= $1 AND created_at < ($2::timestamp + INTERVAL '1 day')
          AND llm_cost_usd IS NOT NULL
        GROUP BY user_id
        ORDER BY total_usd DESC NULLS LAST
        LIMIT $3`,
      from,
      to,
      topN,
    );
    const totalRows: any[] = await this.prisma.$queryRawUnsafe(
      `SELECT SUM(llm_cost_usd)::float8 AS total_usd,
              COUNT(*)::int             AS sessions
         FROM ai_sessions
        WHERE created_at >= $1 AND created_at < ($2::timestamp + INTERVAL '1 day')`,
      from,
      to,
    );
    return {
      window: { from: from.toISOString(), to: to.toISOString() },
      total: totalRows[0] ?? { total_usd: 0, sessions: 0 },
      topSpenders: rows,
    };
  }

  /**
   * Pulled from analytics_events — distribution of event names + counts
   * over the last 24h. Quick "is anything moving?" signal.
   */
  @Roles('admin', 'super_admin')
  @Audit({ event: 'admin.observability.events', level: 'info' })
  @Get('events')
  async events(@Query('hours') hoursStr?: string) {
    const hours = Math.min(Math.max(Number(hoursStr ?? '24'), 1), 24 * 14);
    const since = new Date(Date.now() - hours * 3600 * 1000);
    try {
      const rows: any[] = await this.prisma.$queryRawUnsafe(
        `SELECT event, COUNT(*)::int AS n
           FROM analytics_events
          WHERE occurred_at >= $1
          GROUP BY event
          ORDER BY n DESC
          LIMIT 100`,
        since,
      );
      return { since: since.toISOString(), events: rows };
    } catch (err) {
      // Table may not exist yet (sql/13 not applied). Don't 500 — just say so.
      const msg = (err as Error).message;
      if (/relation .* does not exist/i.test(msg)) {
        return { since: since.toISOString(), events: [], note: 'analytics_events not yet applied (sql/13)' };
      }
      throw err;
    }
  }

  private async summarize(q: Queue) {
    const counts = await q.getJobCounts(
      'waiting', 'active', 'completed', 'failed', 'delayed', 'paused',
    );
    return counts;
  }
}

function parseDate(s?: string): Date | null {
  if (!s) return null;
  const d = new Date(s);
  return Number.isNaN(d.getTime()) ? null : d;
}
