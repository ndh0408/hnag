import { Inject, Injectable, Logger } from '@nestjs/common';
import IORedis from 'ioredis';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../../common/prisma/prisma.service';
import { REDIS } from '../../common/redis/redis.module';

/**
 * Computes a REAL trending_score from recent user interactions.
 *
 * Previously trending_score was a frozen RANDOM() value from the seed and was
 * never recomputed — so "trending" was fake. This job recomputes it hourly from
 * food_interactions over the last 7 days, with exponential recency decay.
 *
 * Cold-start safety: foods with no recent interactions are left untouched (we do
 * NOT zero the whole catalog while the app is pre-launch). As soon as real
 * interactions exist, those foods get a genuine, normalized 0–100 score.
 *
 * Distributed lock (audit workflow-trace §20): with backend-2 replica the cron
 * runs in BOTH processes hourly → two parallel UPDATEs on `foods` with the
 * same result. We use Redis SET NX EX as a single-flight gate keyed on the
 * hour bucket; only one replica's call survives, the other returns fast.
 */
@Injectable()
export class TrendingService {
  private readonly logger = new Logger(TrendingService.name);

  constructor(
    private readonly prisma: PrismaService,
    @Inject(REDIS) private readonly redis: IORedis,
  ) {}

  @Cron(CronExpression.EVERY_HOUR)
  async recompute(): Promise<void> {
    // Distributed lock — bucket by hour, 55-minute TTL so a stuck job
    // releases before the next cron tick. SET NX guarantees only one
    // replica claims the slot.
    const bucket = new Date().toISOString().slice(0, 13); // YYYY-MM-DDTHH
    const lockKey = `cron:trending:${bucket}`;
    const claimed = await this.redis.set(lockKey, '1', 'EX', 55 * 60, 'NX');
    if (claimed !== 'OK') {
      this.logger.debug(`trending recompute skipped — another replica is doing this bucket (${bucket})`);
      return;
    }
    try {
      const affected = await this.prisma.$executeRawUnsafe(`
        WITH scored AS (
          SELECT food_id,
            SUM(
              (CASE action
                 WHEN 'order' THEN 5 WHEN 'dine' THEN 5
                 WHEN 'cook'  THEN 3 WHEN 'save' THEN 3
                 WHEN 'rate'  THEN 2 WHEN 'view' THEN 1
                 WHEN 'skip'  THEN -1 ELSE 0 END)
              * EXP(-EXTRACT(EPOCH FROM (NOW() - created_at)) / 86400.0 / 3.0)
            ) AS raw
          FROM food_interactions
          WHERE created_at > NOW() - INTERVAL '7 days'
          GROUP BY food_id
        ),
        mx AS (SELECT GREATEST(MAX(raw), 1) AS m FROM scored WHERE raw > 0)
        UPDATE foods f
           SET trending_score = LEAST(100, GREATEST(0, 100.0 * s.raw / (SELECT m FROM mx)))
          FROM scored s
         WHERE f.id = s.food_id AND s.raw > 0
      `);
      if (affected) this.logger.log(`trending_score recomputed for ${affected} foods`);
    } catch (e) {
      this.logger.error(`trending recompute failed: ${(e as Error).message}`);
    }
  }
}
