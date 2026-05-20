import { Injectable, Inject, Logger } from '@nestjs/common';
import IORedis from 'ioredis';
import { PrismaService } from '../../../common/prisma/prisma.service';
import { REDIS } from '../../../common/redis/redis.module';

export interface TasteVector {
  embedding: number[]; // 64-dim mini for runtime
  interp: Record<string, number>;
  updatedAt: string;
}

@Injectable()
export class TasteMemoryService {
  private readonly logger = new Logger(TasteMemoryService.name);
  private readonly dim = 64;

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
  async applyImplicitFeedback(userId: string, foodId: string, action: string) {
    const vec = await this.load(userId);
    const item = await this.itemEmbedding(foodId);
    if (!item) return;

    const w = WEIGHTS[action] ?? 0;
    if (w === 0) return;

    const alpha = Math.min(0.05 * Math.abs(w), 0.15);
    const sign = Math.sign(w);

    for (let i = 0; i < this.dim; i++) {
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

const WEIGHTS: Record<string, number> = {
  viewed: 0.05,
  saved: 0.20,
  ordered: 0.50,
  cooked: 0.40,
  ate: 0.60,
  rated: 0,
  rated_5: 0.80,
  rated_1: -0.50,
  skipped: -0.10,
  dine: 0.55,
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
