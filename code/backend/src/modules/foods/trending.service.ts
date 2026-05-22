import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../../common/prisma/prisma.service';

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
 */
@Injectable()
export class TrendingService {
  private readonly logger = new Logger(TrendingService.name);

  constructor(private readonly prisma: PrismaService) {}

  @Cron(CronExpression.EVERY_HOUR)
  async recompute(): Promise<void> {
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
