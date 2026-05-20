import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../../common/prisma/prisma.service';
import { TasteVector } from './taste-memory.service';
import { EnrichedContext } from './context-builder.service';

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
  constructor(private readonly prisma: PrismaService) {}

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

    return candidates
      .filter((f) => !recent.has(f.id))
      .map((f) => ({
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
        origin: 'trending' as const,
        scores: {},
        reasonCodes: [],
      }));
  }
}
