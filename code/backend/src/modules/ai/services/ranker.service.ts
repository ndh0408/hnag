import { Inject, Injectable } from '@nestjs/common';
import IORedis from 'ioredis';

import { REDIS } from '../../../common/redis/redis.module';
import { Candidate } from './candidate-generator.service';
import { EnrichedContext } from './context-builder.service';

function cosine(a: number[], b: number[]): number {
  let dot = 0, na = 0, nb = 0;
  const n = Math.min(a.length, b.length);
  for (let i = 0; i < n; i++) { dot += a[i] * b[i]; na += a[i] * a[i]; nb += b[i] * b[i]; }
  return na === 0 || nb === 0 ? 0 : dot / Math.sqrt(na * nb);
}

@Injectable()
export class RankerService {
  constructor(@Inject(REDIS) private readonly redis: IORedis) {}

  /**
   * LightGBM-substitute pure-TS scoring.
   * Production: call BentoML model via gRPC; this is a sensible heuristic for skeleton.
   *
   * Audit production-killer §3 ("Recommendation intelligence — rejection
   * memory"): we look up the user's recent skip counts per foodId from
   * Redis and apply an exponentially-decaying penalty. A food the user
   * skipped 5+ times in the last 7 days is effectively removed from the
   * suggestion set; one skip nudges it down without hiding it forever.
   */
  async rank(args: {
    userId: string;
    candidates: Candidate[];
    enriched: EnrichedContext;
  }): Promise<Candidate[]> {
    const { candidates, enriched, userId } = args;

    // Batch-fetch skip counts for the candidate set — one Redis MGET so
    // ranking stays O(1) network calls regardless of candidate count.
    const skipPenalties = await this.fetchSkipPenalties(userId, candidates.map((c) => c.foodId));

    return candidates
      .map((c) => {
        const scores: Record<string, number> = {};
        const codes: string[] = [];

        // Relevance proxy
        scores.cuisine = enriched.cuisinePref?.includes(c.cuisine) ? 1 : 0.3;
        if (scores.cuisine === 1) codes.push(`high_cuisine_match:${c.cuisine}`);

        // Price match
        if (enriched.budget) {
          const max = enriched.budget.max;
          scores.price = c.priceVnd <= max ? 1 : Math.max(0, 1 - (c.priceVnd - max) / max);
        } else scores.price = 0.7;

        // Time match
        if (enriched.timeMin) {
          scores.time = c.tags.includes('nhanh') || c.category === 'street' ? 1 : 0.6;
        } else scores.time = 0.8;

        // Mood
        if (enriched.mood) {
          const m = enriched.mood;
          const moodFitTagSet: Record<string, string[]> = {
            stress: ['lẩu', 'mì cay', 'đồ nướng'],
            sad: ['cháo', 'phở', 'bún bò'],
            chill: ['brunch', 'bánh mì', 'cafe'],
            late_night: ['cháo', 'mì gói', 'xôi mặn', 'bánh mì'],
          };
          const fits = moodFitTagSet[m] ?? [];
          scores.mood = fits.some((kw) => c.title.toLowerCase().includes(kw)) ? 1 : 0.4;
          if (scores.mood === 1) codes.push(`mood_match:${m}`);
        } else scores.mood = 0.5;

        // Weather
        if (enriched.weather.condition === 'rain' && /phở|cháo|bún bò|lẩu|canh/.test(c.title)) {
          scores.weather = 1;
          codes.push('weather_match:rain→warm');
        } else scores.weather = 0.6;

        // Quality
        scores.quality = (c.rating.avg / 5) * Math.min(1, Math.log10(c.rating.count + 1) / 3);

        // Popularity / trending
        scores.trending = Math.min(1, c.trendingScore / 100);

        // Personal taste — real embedding cosine (set by candidate generator).
        scores.taste = typeof c.scores.embSim === 'number' ? c.scores.embSim : 0.5;
        if (scores.taste > 0.65) codes.push('taste_match');

        // Late night adjustment
        if (enriched.isLateNight) {
          const safe = ['cháo', 'mì gói', 'xôi', 'bánh mì'].some((k) => c.title.toLowerCase().includes(k));
          scores.lateNight = safe ? 1 : 0.2;
        } else scores.lateNight = 1;

        // Rejection memory penalty — subtract from final score so the
        // sort drops habitually-skipped foods to the bottom. Penalty curves:
        //   0 skips → 1.0   (no change)
        //   1 skip  → 0.85
        //   3 skips → 0.55
        //   5+      → ~0.30 (rarely picked at all)
        const skipPenalty = skipPenalties.get(c.foodId) ?? 1;
        scores.skipMemory = skipPenalty;
        if (skipPenalty < 0.5) codes.push('rejection_memory_penalty');

        // Final blend (taste embedding now carries real personalization weight)
        const finalRaw =
          scores.taste * 0.22 +
          scores.cuisine * 0.13 +
          scores.price * 0.12 +
          scores.time * 0.08 +
          scores.mood * 0.13 +
          scores.weather * 0.08 +
          scores.quality * 0.12 +
          scores.trending * 0.07 +
          scores.lateNight * 0.05;
        const final = finalRaw * skipPenalty;

        scores.final = final;
        c.scores = scores;
        c.reasonCodes = codes;
        return c;
      })
      .sort((a, b) => (b.scores.final ?? 0) - (a.scores.final ?? 0));
  }

  /**
   * Diversity injection (MMR-lite): cap same cuisine to 2 in top-N,
   * mix action types when possible.
   */
  diversify(ranked: Candidate[], n: number): Candidate[] {
    const selected: Candidate[] = [];
    const cuisineCount: Record<string, number> = {};
    const categoryCount: Record<string, number> = {};

    for (const c of ranked) {
      if (selected.length >= n) break;
      const cuisineHit = cuisineCount[c.cuisine] ?? 0;
      const categoryHit = categoryCount[c.category] ?? 0;
      if (cuisineHit >= 2) continue;
      if (categoryHit >= 2) continue;
      selected.push(c);
      cuisineCount[c.cuisine] = cuisineHit + 1;
      categoryCount[c.category] = categoryHit + 1;
    }

    // Fill if we don't have enough
    let i = 0;
    while (selected.length < n && i < ranked.length) {
      if (!selected.includes(ranked[i])) selected.push(ranked[i]);
      i++;
    }
    return selected;
  }

  /**
   * Bulk-fetch skip-count → penalty for a candidate set. Returns a map
   * keyed by foodId; missing entries default to 1.0 (no penalty).
   *
   * The skip counter is written by TasteMemoryService.applyImplicitFeedback
   * when action='skip' fires from `recordFeedback`. Key format:
   *   skip:<userId>:<foodId>    (7-day TTL)
   *
   * The penalty curve is exp-decay so a single skip is a small nudge,
   * five+ skips effectively removes the dish:
   *   penalty = max(0.3, exp(-skips / 3))
   *
   *   skips=0 → 1.00     skips=1 → 0.72
   *   skips=2 → 0.51     skips=3 → 0.37
   *   skips=5 → 0.30     skips=10 → 0.30 (floor)
   */
  private async fetchSkipPenalties(userId: string, foodIds: string[]): Promise<Map<string, number>> {
    const out = new Map<string, number>();
    if (!foodIds.length) return out;
    const keys = foodIds.map((id) => `skip:${userId}:${id}`);
    let values: (string | null)[] = [];
    try {
      values = await this.redis.mget(...keys);
    } catch {
      return out;
    }
    for (let i = 0; i < foodIds.length; i++) {
      const skips = Number(values[i] ?? 0);
      if (!Number.isFinite(skips) || skips <= 0) {
        out.set(foodIds[i], 1);
        continue;
      }
      const penalty = Math.max(0.3, Math.exp(-skips / 3));
      out.set(foodIds[i], penalty);
    }
    return out;
  }
}
