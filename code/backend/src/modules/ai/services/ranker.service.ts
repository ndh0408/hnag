import { Injectable } from '@nestjs/common';
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
  /**
   * LightGBM-substitute pure-TS scoring.
   * Production: call BentoML model via gRPC; this is a sensible heuristic for skeleton.
   */
  async rank(args: {
    userId: string;
    candidates: Candidate[];
    enriched: EnrichedContext;
  }): Promise<Candidate[]> {
    const { candidates, enriched } = args;

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

        // Final blend (taste embedding now carries real personalization weight)
        const final =
          scores.taste * 0.22 +
          scores.cuisine * 0.13 +
          scores.price * 0.12 +
          scores.time * 0.08 +
          scores.mood * 0.13 +
          scores.weather * 0.08 +
          scores.quality * 0.12 +
          scores.trending * 0.07 +
          scores.lateNight * 0.05;

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
}
