import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';

import { PrismaService } from '../../common/prisma/prisma.service';

/**
 * Refresh the leaderboard materialized views every 5 minutes.
 *
 * Audit hnag-audit-2026-05 §11 / §34: live leaderboard query was scanning
 * users × reviews on every page view (2-5s). Migrated to materialized
 * views (see code/sql/11_leaderboard_mv.sql). This cron keeps them fresh
 * without requiring the `pg_cron` extension to be available on the
 * production server.
 *
 * `REFRESH MATERIALIZED VIEW CONCURRENTLY` is non-blocking (other queries
 * keep reading the prior snapshot while the new one is built), but it
 * requires a unique index — already created in 11_leaderboard_mv.sql.
 *
 * If the MV is missing (e.g. on a fresh DB before the SQL was applied) the
 * cron logs a warning and continues — it does not crash the app.
 */
@Injectable()
export class LeaderboardRefreshCron {
  private readonly logger = new Logger(LeaderboardRefreshCron.name);

  constructor(private readonly prisma: PrismaService) {}

  @Cron(CronExpression.EVERY_5_MINUTES, { name: 'refresh-leaderboards' })
  async refresh(): Promise<void> {
    const t0 = Date.now();
    try {
      await this.prisma.$executeRawUnsafe('SELECT refresh_leaderboards();');
      this.logger.debug(`Leaderboard MVs refreshed in ${Date.now() - t0}ms`);
    } catch (err) {
      const msg = (err as Error).message;
      if (/relation .* does not exist|function .* does not exist/i.test(msg)) {
        // SQL not applied yet — log once per session at warn level (loud
        // enough to notice on first boot, quiet enough not to spam Loki).
        this.logger.warn(
          'refresh_leaderboards() not found — apply code/sql/11_leaderboard_mv.sql to enable fast leaderboard reads',
        );
      } else {
        this.logger.error(`Leaderboard refresh failed: ${msg}`);
      }
    }
  }
}
