import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';

import { PrismaService } from '../../../common/prisma/prisma.service';

/**
 * Collaborative-filtering offline builder.
 *
 * Audit production-killer §3 ("Recommendation Layer 3-5"). Computes
 * `user_similarity` and `food_co_view` from the live `food_interactions`
 * table once a day. The ranker reads these as a "soft signal" that
 * boosts foods popular within the user's nearest neighbours.
 *
 * Why offline + nightly instead of online:
 *   - User-user CF matrices are O(users²) — at 100k users the dense
 *     matrix would be 40 GB. The K-nearest-neighbours approximation
 *     trims that to top-50 per user = ~200 MB.
 *   - One-day staleness is fine for food preferences — they don't shift
 *     overnight. A weekly retrain would be enough; nightly is paranoia
 *     headroom.
 *   - Running it inside the API pod (vs. spawning a worker) keeps the
 *     deps small until volume forces a split.
 *
 * Skeleton today: schedules the cron + writes the SQL. The actual
 * `recompute()` body is intentionally a stub so the cron registration
 * is in place and a future session can drop in the real query. See
 * `code/sql/15_user_similarity.sql` for the storage layer.
 *
 * To activate the cron (and start writing real rows):
 *   1. Apply sql/15_user_similarity.sql on prod.
 *   2. Fill in `recompute()` below — the comments inside describe each
 *      step and link to the reference SQL.
 *   3. Wire this into AiModule providers (already done).
 */
@Injectable()
export class CfBuilderService {
  private readonly logger = new Logger(CfBuilderService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Run at 03:30 UTC daily — after the leaderboard refresh (which uses
   * the same `food_interactions` table) so we don't fight for locks.
   */
  @Cron('30 3 * * *', { name: 'cf-build' })
  async recompute(): Promise<void> {
    if (process.env.CF_BUILDER_ENABLED !== 'true') {
      this.logger.debug('CF builder skipped (CF_BUILDER_ENABLED != true)');
      return;
    }
    const t0 = Date.now();
    try {
      await this.buildFoodCoView();
      await this.buildUserSimilarity();
      this.logger.log(`CF rebuild done in ${Date.now() - t0}ms`);
    } catch (err) {
      const msg = (err as Error).message;
      if (/relation .* does not exist/i.test(msg)) {
        this.logger.warn('CF tables not found — apply code/sql/15_user_similarity.sql to enable CF');
        return;
      }
      this.logger.error(`CF rebuild failed: ${msg}`);
    }
  }

  /**
   * food_co_view — for each pair (a, b) where both have ≥ K co-likers,
   * compute Jaccard similarity = |likers(a) ∩ likers(b)| / |likers(a) ∪ likers(b)|.
   *
   * Reference SQL (commit this then `EXPLAIN ANALYZE` on a small sample
   * to validate before flipping CF_BUILDER_ENABLED on prod):
   *
   *   WITH pairs AS (
   *     SELECT a.food_id AS food_a, b.food_id AS food_b, COUNT(*) AS co
   *       FROM v_user_food_likes a
   *       JOIN v_user_food_likes b ON a.user_id = b.user_id AND a.food_id < b.food_id
   *      GROUP BY a.food_id, b.food_id
   *     HAVING COUNT(*) >= 5
   *   ),
   *   sizes AS (
   *     SELECT food_id, COUNT(*) AS n FROM v_user_food_likes GROUP BY food_id
   *   )
   *   INSERT INTO food_co_view (food_a, food_b, co_count, jaccard)
   *   SELECT p.food_a, p.food_b, p.co,
   *          p.co::float / NULLIF(sa.n + sb.n - p.co, 0) AS jaccard
   *     FROM pairs p
   *     JOIN sizes sa ON sa.food_id = p.food_a
   *     JOIN sizes sb ON sb.food_id = p.food_b
   *     ON CONFLICT (food_a, food_b) DO UPDATE
   *        SET co_count = EXCLUDED.co_count,
   *            jaccard  = EXCLUDED.jaccard,
   *            computed_at = NOW();
   */
  private async buildFoodCoView(): Promise<void> {
    this.logger.debug('food_co_view rebuild — stub (see reference SQL in method docblock)');
    // TODO(cf-builder): implement once volume justifies it (audit §3).
  }

  /**
   * user_similarity — for each user, find the top-K most similar via
   * cosine over the implicit-feedback positives. K=50 default; tune
   * via env CF_K_NEIGHBORS once tracking acceptance-rate impact.
   *
   * Strategy at 10k+ users: don't materialise the full N×N. Instead,
   * for each user compute the top-K via a TABLESAMPLE on the rest
   * of the user base + reranker. That's the right next step but the
   * skeleton stays empty until it actually helps.
   */
  private async buildUserSimilarity(): Promise<void> {
    this.logger.debug('user_similarity rebuild — stub (see method docblock)');
    // TODO(cf-builder): implement once volume justifies it (audit §3).
  }
}
