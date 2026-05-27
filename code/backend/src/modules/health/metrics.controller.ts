import { Controller, Get, Header, Inject, Optional, Res } from '@nestjs/common';
import { ApiExcludeController } from '@nestjs/swagger';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { Response } from 'express';
import IORedis from 'ioredis';

import { REDIS } from '../../common/redis/redis.module';
import { PrismaService } from '../../common/prisma/prisma.service';

/**
 * Prometheus scrape endpoint at `/metrics`.
 *
 * Closes audit production-killer §1 ("Observability: missing metrics").
 * Until now the only ops signal was the JSON `/health` endpoint, which is
 * great for synthetic monitors (UptimeRobot) but doesn't give Grafana a
 * time-series to chart.
 *
 * Why this is a hand-rolled controller and not the `prom-client` Express
 * middleware:
 *   - prom-client isn't in package.json yet — adding a dep + auto-register
 *     hooks would pull a lot of process-level instrumentation that's nice
 *     but heavy.
 *   - The cheap version below covers the 5 dimensions that actually move
 *     dashboards in week 1: process memory, uptime, DB latency, Redis
 *     latency, queue depth. Add prom-client later if we want HTTP-route
 *     histograms + GC pauses.
 *
 * Output is the standard Prometheus text-exposition format. Scrape config:
 *
 *   - job_name: hnag-backend
 *     static_configs:
 *       - targets: ['hnag-backend:4000']
 *     metrics_path: /metrics
 *
 * The endpoint is intentionally NOT under /v1 and NOT behind RBAC — most
 * Prometheus deployments don't authenticate scrapes (they live on a
 * private network). Lock it down at the nginx / Cloudflare Tunnel layer
 * by restricting `/metrics` to the Prometheus IP.
 */
@ApiExcludeController()
@Controller('metrics')
export class MetricsController {
  // Process-start timestamp for uptime gauge.
  private readonly bootMs = Date.now();

  constructor(
    private readonly prisma: PrismaService,
    @Inject(REDIS) private readonly redis: IORedis,
    @Optional() @InjectQueue('otp:email') private readonly otpQueue?: Queue,
    @Optional() @InjectQueue('push:fcm') private readonly pushQueue?: Queue,
  ) {}

  @Get()
  @Header('Content-Type', 'text/plain; version=0.0.4; charset=utf-8')
  async metrics(@Res() res: Response): Promise<void> {
    const lines: string[] = [];

    // ── Process gauges ────────────────────────────────────────────────
    const mem = process.memoryUsage();
    push(lines, 'hnag_process_uptime_seconds', 'Seconds since process boot', 'gauge', [
      ['', Math.round((Date.now() - this.bootMs) / 1000)],
    ]);
    push(lines, 'hnag_process_memory_bytes', 'Process memory usage in bytes', 'gauge', [
      ['type="rss"', mem.rss],
      ['type="heap_used"', mem.heapUsed],
      ['type="heap_total"', mem.heapTotal],
      ['type="external"', mem.external],
    ]);

    const cpu = process.cpuUsage();
    push(lines, 'hnag_process_cpu_microseconds_total', 'CPU time used by the process', 'counter', [
      ['type="user"', cpu.user],
      ['type="system"', cpu.system],
    ]);

    push(lines, 'hnag_build_info', 'Build information', 'gauge', [
      [`version="${escape(process.env.HNAG_VERSION ?? 'dev')}",env="${escape(process.env.NODE_ENV ?? 'development')}"`, 1],
    ]);

    // ── Dependency probes ─────────────────────────────────────────────
    const dbProbe = await this.timed(() => this.prisma.$queryRawUnsafe('SELECT 1'));
    push(lines, 'hnag_db_up', 'Postgres health (1 = ok, 0 = down)', 'gauge', [['', dbProbe.ok ? 1 : 0]]);
    push(lines, 'hnag_db_probe_latency_seconds', 'Roundtrip time for SELECT 1', 'gauge', [['', dbProbe.ms / 1000]]);

    const cacheProbe = await this.timed(() => this.redis.ping());
    const cacheOk = cacheProbe.ok && cacheProbe.value === 'PONG';
    push(lines, 'hnag_redis_up', 'Redis health (1 = ok, 0 = down)', 'gauge', [['', cacheOk ? 1 : 0]]);
    push(lines, 'hnag_redis_probe_latency_seconds', 'Roundtrip time for PING', 'gauge', [['', cacheProbe.ms / 1000]]);

    // ── Queue depths ──────────────────────────────────────────────────
    const queueRows: [string, number][] = [];
    if (this.otpQueue) {
      const c = await safeJobCounts(this.otpQueue);
      for (const [state, n] of Object.entries(c)) queueRows.push([`queue="otp:email",state="${state}"`, n]);
    }
    if (this.pushQueue) {
      const c = await safeJobCounts(this.pushQueue);
      for (const [state, n] of Object.entries(c)) queueRows.push([`queue="push:fcm",state="${state}"`, n]);
    }
    if (queueRows.length) {
      push(lines, 'hnag_bullmq_jobs', 'BullMQ jobs by queue × state', 'gauge', queueRows);
    }

    // ── AI spend (today, all users) ───────────────────────────────────
    // Use the per-day Redis SUM key written by ai-orchestrator. Scaled
    // to USD (the counter is in 1e-5 USD precision = cents/1000).
    const today = new Date().toISOString().slice(0, 10);
    try {
      const keys = await this.redis.keys(`ai:spend:*:${today}`);
      let totalScaled = 0;
      if (keys.length) {
        const vals = await this.redis.mget(...keys);
        for (const v of vals) totalScaled += Number(v ?? 0);
      }
      push(lines, 'hnag_ai_spend_usd_today', 'Sum of LLM cost today (USD, all users)', 'gauge', [
        ['', totalScaled / 100_000],
      ]);
      push(lines, 'hnag_ai_spend_users_today', 'Distinct users who triggered LLM today', 'gauge', [
        ['', keys.length],
      ]);
    } catch {/* best-effort */}

    res.send(lines.join('\n') + '\n');
  }

  // ── helpers ────────────────────────────────────────────────────────
  private async timed<T>(fn: () => Promise<T>): Promise<{ ok: boolean; ms: number; value?: T }> {
    const t = Date.now();
    try {
      const v = await fn();
      return { ok: true, ms: Date.now() - t, value: v };
    } catch {
      return { ok: false, ms: Date.now() - t };
    }
  }
}

async function safeJobCounts(q: Queue): Promise<Record<string, number>> {
  try {
    return await q.getJobCounts('waiting', 'active', 'completed', 'failed', 'delayed', 'paused');
  } catch {
    return {};
  }
}

function push(
  out: string[],
  name: string,
  help: string,
  type: 'gauge' | 'counter',
  rows: Array<[string, number]>,
): void {
  out.push(`# HELP ${name} ${help}`);
  out.push(`# TYPE ${name} ${type}`);
  for (const [labels, value] of rows) {
    const labelPart = labels ? `{${labels}}` : '';
    out.push(`${name}${labelPart} ${value}`);
  }
}

function escape(s: string): string {
  return s.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n');
}
