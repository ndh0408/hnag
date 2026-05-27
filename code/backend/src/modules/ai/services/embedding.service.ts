import { Injectable, Inject, Logger, OnModuleInit } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import OpenAI from 'openai';
import IORedis from 'ioredis';
import { PrismaService } from '../../../common/prisma/prisma.service';
import { REDIS } from '../../../common/redis/redis.module';

/** Embedding dimension — kept small for fast in-memory cosine (no pgvector needed). */
export const EMB_DIM = 256;

/**
 * Real content-based embeddings via OpenAI text-embedding-3-small.
 *
 * Food embeddings are stored in Redis under `food:emb:{id}` (the exact key the
 * TasteMemoryService already reads). With ~hundreds–thousands of foods, cosine
 * similarity in Node is sub-10ms, so we don't need pgvector to ship real
 * semantic personalization.
 */
@Injectable()
export class EmbeddingService implements OnModuleInit {
  private readonly logger = new Logger(EmbeddingService.name);
  private readonly client: OpenAI | null;

  constructor(
    private readonly prisma: PrismaService,
    @Inject(REDIS) private readonly redis: IORedis,
  ) {
    this.client = process.env.OPENAI_API_KEY
      ? new OpenAI({ apiKey: process.env.OPENAI_API_KEY, timeout: 20_000, maxRetries: 2 })
      : null;
  }

  get enabled(): boolean {
    return !!this.client;
  }

  async onModuleInit(): Promise<void> {
    // Lazy, non-blocking backfill on boot so embeddings exist after a deploy.
    this.backfillFoods().catch((e) =>
      this.logger.warn(`food embedding backfill on boot failed: ${(e as Error).message}`),
    );
  }

  foodText(f: any): string {
    return [
      f.name_vi,
      f.name_en,
      f.description,
      `cuisine: ${f.cuisine ?? ''}`,
      `category: ${f.category ?? ''}`,
      `tags: ${[...(f.flavor_tags ?? []), ...(f.mood_tags ?? []), ...(f.vibe_tags ?? [])].join(', ')}`,
      `region: ${f.origin_region ?? ''}`,
    ].filter(Boolean).join(' · ');
  }

  async embed(texts: string[]): Promise<number[][]> {
    if (!this.client || texts.length === 0) return [];
    const resp = await this.client.embeddings.create({
      model: 'text-embedding-3-small',
      input: texts,
      dimensions: EMB_DIM,
    });
    return resp.data.map((d) => d.embedding as number[]);
  }

  async embedOne(text: string): Promise<number[] | null> {
    const [v] = await this.embed([text]);
    return v ?? null;
  }

  async getFoodEmbedding(foodId: string): Promise<number[] | null> {
    const c = await this.redis.get(`food:emb:${foodId}`);
    return c ? JSON.parse(c) : null;
  }

  /** Batch fetch food embeddings from Redis (one round-trip). */
  async getFoodEmbeddings(ids: string[]): Promise<Map<string, number[]>> {
    const map = new Map<string, number[]>();
    if (!ids.length) return map;
    const vals = await this.redis.mget(...ids.map((id) => `food:emb:${id}`));
    ids.forEach((id, i) => { if (vals[i]) map.set(id, JSON.parse(vals[i] as string)); });
    return map;
  }

  /** Embed any foods missing an embedding. Idempotent; cheap after first run.
   *
   *  Audit AI-quality §M-4: previously triggered from `onModuleInit` AND
   *  `@Cron(4am)` AND on every replica. With backend-2 added, two
   *  replicas booting at the same time both ran `backfillFoods()` → 2x
   *  OpenAI embedding spend. Now we acquire a Redis SETNX lease at the
   *  start; only one replica per day-bucket runs the work, others skip.
   */
  @Cron(CronExpression.EVERY_DAY_AT_4AM)
  async backfillFoods(): Promise<number> {
    if (!this.client) return 0;
    const day = new Date().toISOString().slice(0, 10);
    const lockKey = `cron:emb-backfill:${day}`;
    const claimed = await this.redis.set(lockKey, '1', 'EX', 6 * 3600, 'NX');
    if (claimed !== 'OK') {
      this.logger.debug(`embedding backfill skipped — another replica owns ${day}`);
      return 0;
    }
    const foods = await this.prisma.foods.findMany({ where: { status: 'active' } });
    if (!foods.length) return 0;
    const existing = await this.redis.mget(...foods.map((f) => `food:emb:${f.id}`));
    const todo = foods.filter((_, i) => !existing[i]);
    if (!todo.length) return 0;

    let done = 0;
    for (let i = 0; i < todo.length; i += 50) {
      const batch = todo.slice(i, i + 50);
      const vecs = await this.embed(batch.map((f) => this.foodText(f)));
      const pipe = this.redis.pipeline();
      batch.forEach((f, j) => { if (vecs[j]) pipe.set(`food:emb:${f.id}`, JSON.stringify(vecs[j])); });
      await pipe.exec();
      done += batch.length;
    }
    this.logger.log(`Embedded ${done} foods (dim ${EMB_DIM})`);
    return done;
  }
}

export function cosine(a: number[], b: number[]): number {
  let dot = 0, na = 0, nb = 0;
  const n = Math.min(a.length, b.length);
  for (let i = 0; i < n; i++) { dot += a[i] * b[i]; na += a[i] * a[i]; nb += b[i] * b[i]; }
  return na === 0 || nb === 0 ? 0 : dot / Math.sqrt(na * nb);
}
