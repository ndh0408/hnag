import { Inject, Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import IORedis from 'ioredis';

import { PrismaService } from '../../common/prisma/prisma.service';
import { REDIS } from '../../common/redis/redis.module';

/**
 * Nightly retention cron. Closes audit db-trace §C-12.
 *
 * Calls the PL/pgSQL functions installed by sql/21_retention_policies.sql:
 *   - purge_old_auth_sessions     (revoked > 7d)
 *   - compact_old_ai_sessions     (NULL output_cards > 30d)
 *   - purge_old_analytics_events  (> 90d)
 *   - purge_old_account_deletions (> 365d — Decree 13/2023 minimum)
 *
 * Single-replica safety: SETNX leader-election per day bucket so adding
 * more backend pods doesn't run the same DELETE 4× simultaneously.
 *
 * Threshold knobs via env:
 *   RETENTION_AUTH_SESSIONS_DAYS     default 7
 *   RETENTION_AI_SESSIONS_COMPACT_DAYS default 30
 *   RETENTION_ANALYTICS_DAYS         default 90
 *   RETENTION_ACCOUNT_DELETIONS_DAYS default 365
 */
@Injectable()
export class RetentionCron {
  private readonly logger = new Logger(RetentionCron.name);

  constructor(
    private readonly prisma: PrismaService,
    @Inject(REDIS) private readonly redis: IORedis,
  ) {}

  @Cron(CronExpression.EVERY_DAY_AT_3AM)
  async run(): Promise<void> {
    const day = new Date().toISOString().slice(0, 10);
    const lockKey = `cron:retention:${day}`;
    const claimed = await this.redis.set(lockKey, '1', 'EX', 6 * 3600, 'NX');
    if (claimed !== 'OK') {
      this.logger.debug(`retention skipped — another replica owns ${day}`);
      return;
    }

    const cfg = {
      auth: Number(process.env.RETENTION_AUTH_SESSIONS_DAYS ?? '7'),
      aiCompact: Number(process.env.RETENTION_AI_SESSIONS_COMPACT_DAYS ?? '30'),
      analytics: Number(process.env.RETENTION_ANALYTICS_DAYS ?? '90'),
      accountDel: Number(process.env.RETENTION_ACCOUNT_DELETIONS_DAYS ?? '365'),
    };

    await this.callFn('purge_old_auth_sessions', cfg.auth);
    await this.callFn('compact_old_ai_sessions', cfg.aiCompact);
    await this.callFn('purge_old_analytics_events', cfg.analytics);
    await this.callFn('purge_old_account_deletions', cfg.accountDel);

    this.logger.log('retention sweep complete');
  }

  private async callFn(fnName: string, days: number): Promise<void> {
    try {
      const rows = await this.prisma.$queryRawUnsafe<{ [k: string]: number }[]>(
        `SELECT ${fnName}($1::int) AS n`,
        days,
      );
      const n = Number(rows?.[0]?.n ?? 0);
      this.logger.log(`${fnName}(${days}d) → ${n} rows`);
    } catch (err) {
      // The functions are idempotent + use IF EXISTS-style. If they're
      // missing, sql/21 hasn't been applied yet — warn loudly so ops
      // notices but don't crash the cron.
      this.logger.warn(`${fnName} failed: ${(err as Error).message}`);
    }
  }
}
