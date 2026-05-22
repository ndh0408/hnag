import { Injectable, Logger, HttpException, HttpStatus, Inject } from '@nestjs/common';
import IORedis from 'ioredis';
import { createHash } from 'crypto';
import { v4 as uuid } from 'uuid';

import { PrismaService } from '../../../common/prisma/prisma.service';
import { REDIS } from '../../../common/redis/redis.module';

import { TasteMemoryService } from './taste-memory.service';
import { MoodEngineService } from './mood-engine.service';
import { ContextBuilderService } from './context-builder.service';
import { CandidateGeneratorService } from './candidate-generator.service';
import { RankerService } from './ranker.service';
import { LlmReasonService } from './llm-reason.service';

export interface SuggestRequest {
  userId: string;
  isPremium: boolean;
  mode: 'quick' | 'detail' | 'mood' | 'voice' | 'fridge' | 'group';
  context: Record<string, unknown>;
  limit: number;
}

@Injectable()
export class AiOrchestratorService {
  private readonly logger = new Logger(AiOrchestratorService.name);
  private readonly cacheTtlSec = 300; // 5 min

  constructor(
    private readonly prisma: PrismaService,
    @Inject(REDIS) private readonly redis: IORedis,
    private readonly taste: TasteMemoryService,
    private readonly mood: MoodEngineService,
    private readonly ctx: ContextBuilderService,
    private readonly candidates: CandidateGeneratorService,
    private readonly ranker: RankerService,
    private readonly reason: LlmReasonService,
  ) {}

  /**
   * Core suggestion pipeline — see docs/09-RECO-REALTIME.md §1.
   * Target p95 < 1.4s.
   */
  async suggest(req: SuggestRequest) {
    // Free quota
    if (!req.isPremium) {
      const quota = await this.consumeDailyQuota(req.userId);
      if (!quota.ok) {
        throw new HttpException(
          { code: 'AI_QUOTA_EXCEEDED', message: 'Hết lượt gợi ý miễn phí hôm nay — nâng cấp HNAG+ nhé', meta: quota },
          HttpStatus.PAYMENT_REQUIRED,
        );
      }
    }

    // Cache by (user, context-hash)
    const contextHash = hash(JSON.stringify({ mode: req.mode, ctx: req.context, limit: req.limit }));
    const cacheKey = `ai:suggest:${req.userId}:${contextHash}`;
    const cached = await this.redis.get(cacheKey);
    if (cached) return JSON.parse(cached);

    const t0 = Date.now();

    // 1. Context enrichment
    const enriched = await this.ctx.enrich(req.userId, req.context);

    // 2. Candidate generation (parallel sources)
    const userTaste = await this.taste.load(req.userId);
    let candidates = await this.candidates.generate({
      userId: req.userId,
      userTaste,
      enriched,
      mode: req.mode,
    });

    // 3. Mood bias if applicable
    if (req.mode === 'mood' || enriched.inferredMood) {
      candidates = await this.mood.bias(candidates, enriched.mood ?? enriched.inferredMood!);
    }

    // 4. Rank
    const ranked = await this.ranker.rank({
      userId: req.userId,
      candidates,
      enriched,
    });

    // 5. Selection. Bounded by a per-user daily LLM budget so a scripted account
    // (even premium) can't run up unbounded OpenAI spend.
    const allowLlm = await this.consumeLlmBudget(req.userId, req.isPremium);
    const wantLlmSelect = allowLlm && (req.mode === 'mood' || req.mode === 'detail' || !!enriched.mood || !!enriched.inferredMood);

    let finalTop: typeof ranked = [];
    let reasons: string[] = [];

    // 5a. Let the LLM actually choose for mood/detail flows (validated → no hallucination).
    if (wantLlmSelect) {
      const picks = await this.reason.select(ranked.slice(0, 15), enriched, req.limit);
      if (picks?.length) {
        const byId = new Map(ranked.map((c) => [c.foodId, c] as const));
        for (const p of picks) {
          const c = byId.get(p.foodId);
          if (c) { finalTop.push(c); reasons.push(p.reason); }
        }
      }
    }
    const usedLlmForSelect = reasons.some((r) => !!r);

    // 5b. Heuristic diversify to fill / as the default path.
    if (finalTop.length < req.limit) {
      for (const c of this.ranker.diversify(ranked, req.limit)) {
        if (!finalTop.includes(c)) { finalTop.push(c); reasons.push(''); }
        if (finalTop.length >= req.limit) break;
      }
    }
    finalTop = finalTop.slice(0, req.limit);
    reasons = reasons.slice(0, req.limit);

    // 6. Fill any empty reasons with captions. If the LLM already chose, use the
    // cheap fallback for the remainder to bound cost.
    if (reasons.some((r) => !r)) {
      const captions = await this.reason.batch(finalTop, enriched, { allowLlm: allowLlm && !usedLlmForSelect });
      reasons = finalTop.map((_, i) => (reasons[i] && reasons[i].length ? reasons[i] : (captions[i] ?? '')));
    }

    // 7. Build cards
    const sessionId = uuid();
    const cards = finalTop.map((c, idx) => ({
      cardId: uuid(),
      foodId: c.foodId,
      title: c.title,
      subtitle: c.subtitle,
      media: c.media,
      price: c.price,
      rating: c.rating,
      distance: c.distance,
      calories: c.calories,
      tags: c.tags,
      badges: c.badges,
      liveStatus: c.liveStatus,
      aiReason: reasons[idx] ?? '',
      actions: c.actions,
      socialProof: c.socialProof,
      _scores: c.scores,
    }));

    const response = { sessionId, cards, reasonCodes: finalTop.flatMap((c) => c.reasonCodes) };

    // Cache
    await this.redis.setex(cacheKey, this.cacheTtlSec, JSON.stringify(response));

    // Log
    const latencyMs = Date.now() - t0;
    this.logger.log(`/ai/suggest user=${req.userId} mode=${req.mode} latency=${latencyMs}ms cards=${cards.length}`);
    await this.prisma.ai_sessions.create({
      data: {
        id: sessionId,
        user_id: req.userId,
        mode: req.mode,
        input: req.context as any,
        output_cards: cards as any,
        ranker_scores: finalTop.map((c) => c.scores) as any,
        reason_codes: finalTop.flatMap((c) => c.reasonCodes),
        latency_ms: latencyMs,
      },
    });

    return response;
  }

  async suggestByMood(args: { userId: string; isPremium: boolean; mood: string; location?: { lat: number; lng: number } }) {
    return this.suggest({
      userId: args.userId,
      isPremium: args.isPremium,
      mode: 'mood',
      context: { mood: args.mood, location: args.location },
      limit: 8,
    });
  }

  async refresh(userId: string, sessionId: string) {
    const session = await this.prisma.ai_sessions.findUnique({ where: { id: sessionId } });
    if (!session || session.user_id !== userId) {
      throw new HttpException({ code: 'NOT_FOUND', message: 'Session không tồn tại' }, HttpStatus.NOT_FOUND);
    }
    return this.suggest({
      userId,
      isPremium: false,
      mode: session.mode as any,
      context: (session.input as Record<string, unknown>) ?? {},
      limit: ((session.output_cards as unknown as { length: number })?.length ?? 5) as number,
    });
  }

  async recordFeedback(input: {
    userId: string;
    sessionId: string;
    foodId: string;
    action: 'view' | 'save' | 'skip' | 'cook' | 'order' | 'dine' | 'rate';
    rating?: number;
    reason?: string;
  }) {
    // Persist feedback
    await this.prisma.food_interactions.create({
      data: {
        user_id: input.userId,
        food_id: input.foodId,
        action: input.action as any,
        rating: input.rating,
        session_id: input.sessionId,
        context: { reason: input.reason } as any,
      },
    });

    // Update taste vector online (real embedding EMA; rating-aware)
    await this.taste.applyImplicitFeedback(input.userId, input.foodId, input.action, input.rating);

    // Update streak if action triggers it
    if (['save', 'order', 'dine', 'cook'].includes(input.action)) {
      await this.bumpDecideStreak(input.userId);
    }
  }

  async matchViralLink(input: { userId: string; url: string; location?: { lat: number; lng: number } }) {
    // 1. Resolve URL → detect platform
    const platform = detectPlatform(input.url);
    if (platform === 'unknown') {
      throw new HttpException({ code: 'UNSUPPORTED_LINK', message: 'Hà chưa hỗ trợ link này' }, HttpStatus.BAD_REQUEST);
    }

    // 2. Fetch video metadata + analyze (delegate to worker / TikTok analysis pipeline)
    //    For skeleton we return a stub.
    // 3. Find nearby restaurants serving the detected dish.
    return {
      detectedDish: 'Bánh tráng cuốn thịt heo Đà Nẵng',
      food: null,
      restaurants: [],
      sourceUrl: input.url,
      platform,
    };
  }

  // ---- internals ----

  private async consumeDailyQuota(userId: string): Promise<{ ok: boolean; remaining?: number }> {
    const key = `ai:quota:${userId}:${today()}`;
    const count = await this.redis.incr(key);
    if (count === 1) await this.redis.expire(key, 86400);
    const free = 10;
    return { ok: count <= free, remaining: Math.max(0, free - count) };
  }

  /** Per-user daily cap on real LLM calls (caption generation). Returns whether the LLM may be used. */
  private async consumeLlmBudget(userId: string, isPremium: boolean): Promise<boolean> {
    const cap = Number(process.env.LLM_DAILY_CAP ?? (isPremium ? 300 : 30));
    const key = `ai:llmbudget:${userId}:${today()}`;
    const count = await this.redis.incr(key);
    if (count === 1) await this.redis.expire(key, 86400);
    return count <= cap;
  }

  private async bumpDecideStreak(userId: string) {
    const today_ = new Date(); today_.setHours(0, 0, 0, 0);
    const row = await this.prisma.streaks.findUnique({ where: { user_id: userId } });
    if (!row) {
      await this.prisma.streaks.create({ data: { user_id: userId, daily_decide: 1, last_decide: today_ } });
      return;
    }
    if (row.last_decide && sameDay(row.last_decide, today_)) return;
    const yesterday = new Date(today_); yesterday.setDate(yesterday.getDate() - 1);
    const consecutive = row.last_decide && sameDay(row.last_decide, yesterday);
    await this.prisma.streaks.update({
      where: { user_id: userId },
      data: {
        daily_decide: consecutive ? (row.daily_decide ?? 0) + 1 : 1,
        last_decide: today_,
        best_decide: Math.max(row.best_decide ?? 0, (row.daily_decide ?? 0) + 1),
      },
    });
  }
}

function hash(s: string): string {
  return createHash('sha1').update(s).digest('hex').slice(0, 16);
}

function today(): string {
  return new Date().toISOString().slice(0, 10);
}

function sameDay(a: Date, b: Date): boolean {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

function detectPlatform(url: string): 'tiktok' | 'instagram' | 'facebook' | 'youtube' | 'unknown' {
  if (/tiktok\.com|vt\.tiktok\.com/.test(url)) return 'tiktok';
  if (/instagram\.com/.test(url)) return 'instagram';
  if (/facebook\.com|fb\.watch/.test(url)) return 'facebook';
  if (/youtube\.com|youtu\.be/.test(url)) return 'youtube';
  return 'unknown';
}
