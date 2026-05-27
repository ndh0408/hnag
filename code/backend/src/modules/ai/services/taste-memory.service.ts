import { Injectable, Inject, Logger } from '@nestjs/common';
import IORedis from 'ioredis';
import { PrismaService } from '../../../common/prisma/prisma.service';
import { REDIS } from '../../../common/redis/redis.module';
import { EMB_DIM } from './embedding.service';

export interface TasteVector {
  embedding: number[]; // matches food embedding dim (EMB_DIM)
  interp: Record<string, number>;
  updatedAt: string;
}

@Injectable()
export class TasteMemoryService {
  private readonly logger = new Logger(TasteMemoryService.name);
  private readonly dim = EMB_DIM;

  constructor(
    private readonly prisma: PrismaService,
    @Inject(REDIS) private readonly redis: IORedis,
  ) {}

  async load(userId: string): Promise<TasteVector> {
    const cached = await this.redis.get(`user:taste:${userId}`);
    if (cached) return JSON.parse(cached);

    const user = await this.prisma.users.findUnique({ where: { id: userId } });
    const dna = (user?.food_dna as TasteVector | undefined) ?? this.cold();
    await this.redis.setex(`user:taste:${userId}`, 3600, JSON.stringify(dna));
    return dna;
  }

  async save(userId: string, vec: TasteVector): Promise<void> {
    await this.redis.setex(`user:taste:${userId}`, 3600, JSON.stringify(vec));
    // Persist async (debounced); for skeleton write through immediately
    await this.prisma.users.update({
      where: { id: userId },
      data: { food_dna: { ...vec, updatedAt: new Date().toISOString() } as any },
    });
  }

  /**
   * Online learning — EMA on item embedding, weighted by action strength.
   * Critical: never let allergens be reinforced.
   */
  async applyImplicitFeedback(userId: string, foodId: string, action: string, rating?: number) {
    // Rejection memory — single source of truth for the ranker's
    // skipPenalty (see ranker.service.ts:fetchSkipPenalties).
    if (action === 'skip') {
      try {
        const key = `skip:${userId}:${foodId}`;
        const n = await this.redis.incr(key);
        if (n === 1) await this.redis.expire(key, 7 * 24 * 3600);
      } catch {/* best-effort */}
    }

    const vec = await this.load(userId);
    const item = await this.itemEmbedding(foodId);
    if (!item) return;

    // 'rate' carries a 1–5 score → map to a signed weight; others use the table.
    let w = WEIGHTS[action] ?? 0;
    if (action === 'rate' && rating != null) {
      w = rating >= 4 ? (rating === 5 ? 0.8 : 0.4) : rating <= 2 ? (rating === 1 ? -0.5 : -0.25) : 0;
    }
    if (w === 0) return;

    // Guard against a dimension mismatch (old 64-dim cold vectors etc.).
    if (vec.embedding.length !== item.length) {
      vec.embedding = new Array(item.length).fill(0);
    }

    const alpha = Math.min(0.05 * Math.abs(w) * 2, 0.15);
    const sign = Math.sign(w);

    for (let i = 0; i < item.length; i++) {
      vec.embedding[i] = (1 - alpha) * vec.embedding[i] + alpha * sign * item[i];
    }

    // Update interpretable dimensions from food tags
    const food = await this.prisma.foods.findUnique({ where: { id: foodId } });
    if (food?.cuisine) {
      const key = `cuisine_${food.cuisine}`;
      vec.interp[key] = (vec.interp[key] ?? 0.5) * (1 - alpha) + alpha * (w > 0 ? 1 : 0);
    }
    if (food?.flavor_tags) {
      for (const f of food.flavor_tags) {
        const key = `flavor_${f}`;
        vec.interp[key] = (vec.interp[key] ?? 0.5) * (1 - alpha) + alpha * (w > 0 ? 1 : 0);
      }
    }

    vec.updatedAt = new Date().toISOString();
    await this.save(userId, vec);
  }

  async cosineSim(userId: string, foodId: string): Promise<number> {
    const vec = await this.load(userId);
    const item = await this.itemEmbedding(foodId);
    if (!item) return 0;
    return cosine(vec.embedding, item);
  }

  private async itemEmbedding(foodId: string): Promise<number[] | null> {
    const cached = await this.redis.get(`food:emb:${foodId}`);
    if (cached) return JSON.parse(cached);
    // In prod: fetch from Pinecone; for skeleton return null
    return null;
  }

  private cold(): TasteVector {
    return {
      embedding: new Array(this.dim).fill(0),
      interp: {
        cuisine_vietnamese: 0.6,
        cuisine_korean: 0.4,
        cuisine_japanese: 0.4,
        flavor_spicy: 0.5,
        flavor_sweet: 0.4,
        flavor_umami: 0.7,
        novelty: 0.5,
      },
      updatedAt: new Date().toISOString(),
    };
  }
}

// Keys MUST match the action enum used by recordFeedback / FeedbackDto.
const WEIGHTS: Record<string, number> = {
  view: 0.05,
  save: 0.20,
  cook: 0.40,
  order: 0.50,
  dine: 0.55,
  skip: -0.10,
  rate: 0, // handled via the `rating` argument
};

function cosine(a: number[], b: number[]): number {
  let dot = 0, na = 0, nb = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  if (na === 0 || nb === 0) return 0;
  return dot / Math.sqrt(na * nb);
}
