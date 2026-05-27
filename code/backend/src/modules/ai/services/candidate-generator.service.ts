import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../../common/prisma/prisma.service';
import { TasteVector } from './taste-memory.service';
import { EnrichedContext } from './context-builder.service';
import { EmbeddingService, cosine } from './embedding.service';

export interface Candidate {
  foodId: string;
  title: string;
  subtitle?: string;
  cuisine: string;
  category: string;
  priceVnd: number;
  rating: { avg: number; count: number };
  calories?: number;
  tags: string[];
  popularity: number;
  trendingScore: number;
  origin: 'similar' | 'cf' | 'trending' | 'editorial' | 'friend' | 'mood';
  scores: Record<string, number>;
  reasonCodes: string[];
  // Filled later by enrichment:
  media?: any;
  price?: any;
  distance?: any;
  badges?: any[];
  liveStatus?: any;
  actions?: any;
  socialProof?: any;
}

@Injectable()
export class CandidateGeneratorService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly embeddings: EmbeddingService,
  ) {}

  async generate(args: {
    userId: string;
    userTaste: TasteVector;
    enriched: EnrichedContext;
    mode: string;
  }): Promise<Candidate[]> {
    // For skeleton — use Postgres-direct candidate pool of ~200.
    // Production: parallel Pinecone retrieval + CF + trending + editorial + friend.
    const hardFilters: string[] = [];
    if (args.enriched.diet === 'vegetarian') hardFilters.push('vegetarian');
    if (args.enriched.diet === 'vegan')      hardFilters.push('vegan');

    // Filter allergens HARD
    const allergens = args.enriched.allergies;

    const candidates = await this.prisma.foods.findMany({
      where: {
        status: 'active',
        ...(allergens.length > 0 ? { NOT: { allergens: { hasSome: allergens } } } : {}),
        ...(hardFilters.length > 0 ? { diet_tags: { hasSome: hardFilters } } : {}),
        ...(args.enriched.budget?.max ? { avg_price_vnd: { lte: args.enriched.budget.max + 20000 } } : {}),
        ...(args.enriched.timeMin ? { cook_time_min: { lte: Math.max(args.enriched.timeMin, 15) } } : {}),
      },
      orderBy: [{ trending_score: 'desc' }, { popularity: 'desc' }],
      take: 200,
    });

    // Suppress recently shown
    const recent = new Set(args.enriched.recentFoodIds);
    const pool = candidates.filter((f) => !recent.has(f.id));

    // Content-based personalization: if the user's taste vector has signal,
    // score every candidate by cosine similarity to it (real embeddings from
    // Redis) and order by that. Cold users keep the trending order.
    const userVec = args.userTaste?.embedding ?? [];
    const hasTasteSignal = userVec.some((x) => x !== 0);
    const embMap = hasTasteSignal
      ? await this.embeddings.getFoodEmbeddings(pool.map((f) => f.id))
      : new Map<string, number[]>();

    const mapped = pool.map((f) => {
      const emb = embMap.get(f.id);
      const sim = emb ? cosine(userVec, emb) : 0;        // -1..1
      const embSim = (sim + 1) / 2;                       // 0..1 for the ranker
      return {
        foodId: f.id,
        title: f.name_vi,
        subtitle: undefined,
        cuisine: f.cuisine ?? 'vietnamese',
        category: String(f.category ?? ''),
        priceVnd: f.avg_price_vnd ?? 0,
        rating: { avg: Number(f.rating_avg ?? 0), count: f.rating_count ?? 0 },
        calories: f.avg_calories ?? undefined,
        tags: [...(f.flavor_tags ?? []), ...(f.mood_tags ?? []), ...(f.vibe_tags ?? [])],
        popularity: f.popularity ?? 0,
        trendingScore: Number(f.trending_score ?? 0),
        origin: (hasTasteSignal && emb ? 'similar' : 'trending') as 'similar' | 'trending',
        scores: { embSim },
        reasonCodes: hasTasteSignal && emb && sim > 0.3 ? ['taste_match'] : [],
        _sim: sim,
      };
    });

    if (hasTasteSignal) {
      mapped.sort((a, b) => (b._sim - a._sim) || (b.trendingScore - a.trendingScore));
    } else {
      // Audit AI-quality §C-3: cold-start user has no taste signal. The
      // default `taste=0.5` in the ranker pushes everything to the middle;
      // trending alone would beat that. So for cold users, surface
      // strictly by trending+popularity then add slight randomisation so
      // they don't see literally the same top-N every session.
      mapped.sort((a, b) => (b.trendingScore - a.trendingScore) || (b.popularity - a.popularity));
    }
    // Audit AI-quality §L-5: NOVELTY INJECTION — within the top 2× requested
    // slice, do a per-user-seeded shuffle on the lower half so two callers
    // with similar context don't get IDENTICAL output every time. The top
    // 5 stay in rank order (highest-confidence picks); positions 6-30 get
    // a deterministic-but-per-user-shuffled permutation.
    const TOP_LOCK = 5;
    if (mapped.length > TOP_LOCK + 1) {
      const seed = stableSeed(args.userId);
      const tail = mapped.slice(TOP_LOCK);
      // Fisher-Yates with seeded RNG.
      const rng = mulberry32(seed);
      for (let i = tail.length - 1; i > 0; i--) {
        const j = Math.floor(rng() * (i + 1));
        [tail[i], tail[j]] = [tail[j], tail[i]];
      }
      mapped.splice(TOP_LOCK, tail.length, ...tail);
    }
    return mapped.map(({ _sim, ...c }) => c);
  }
}

/** Hash userId + day → 32-bit seed. Per-day rotation so users see fresh
 *  ordering every day even if their taste vector doesn't shift. */
function stableSeed(userId: string): number {
  const day = new Date().toISOString().slice(0, 10);
  let h = 0;
  const s = userId + ':' + day;
  for (let i = 0; i < s.length; i++) {
    h = (h * 31 + s.charCodeAt(i)) | 0;
  }
  return Math.abs(h);
}

function mulberry32(seed: number): () => number {
  let t = seed + 0x6D2B79F5;
  return () => {
    t = (t + 0x6D2B79F5) | 0;
    let r = Math.imul(t ^ (t >>> 15), 1 | t);
    r = (r + Math.imul(r ^ (r >>> 7), 61 | r)) ^ r;
    return ((r ^ (r >>> 14)) >>> 0) / 4294967296;
  };
}
