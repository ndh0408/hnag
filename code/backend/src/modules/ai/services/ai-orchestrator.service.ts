import { Injectable, Logger, HttpException, HttpStatus, Inject } from '@nestjs/common';
import IORedis from 'ioredis';
import { createHash } from 'crypto';
import { v4 as uuid } from 'uuid';

import { PrismaService } from '../../../common/prisma/prisma.service';
import { REDIS } from '../../../common/redis/redis.module';
import { AnalyticsService } from '../../../common/analytics/analytics.service';

import { TasteMemoryService } from './taste-memory.service';
import { MoodEngineService } from './mood-engine.service';
import { ContextBuilderService } from './context-builder.service';
import { CandidateGeneratorService } from './candidate-generator.service';
import { RankerService } from './ranker.service';
import { LlmReasonService, newCostTracker, LlmCostTracker } from './llm-reason.service';
import { ModerationService } from './moderation.service';

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
    private readonly analytics: AnalyticsService,
    private readonly moderation: ModerationService,
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

    // Cache by (user, context-hash) — exact-match short-window cache.
    const contextHash = hash(JSON.stringify({ mode: req.mode, ctx: req.context, limit: req.limit }));
    const cacheKey = `ai:suggest:${req.userId}:${contextHash}`;
    // Audit incident-readiness §10 ("cache corruption"): wrap JSON.parse
    // in try/catch + auto-DEL on parse fail so a corrupted key stops
    // poisoning the next 5 minutes of suggests for this user.
    const cached = await this.safeReadJson(cacheKey);
    if (cached) return cached;

    // Org-wide LLM cost kill switch (audit #8): refuse to call OpenAI at all
    // when the global daily spend has crossed OPENAI_DAILY_HARD_CAP_USD. The
    // pipeline still serves results from the heuristic ranker + static
    // fallback captions, with `degraded: true` so the UI can say "Hà nghỉ
    // trưa". Cap defaults to $50/day if unset — adjust per growth stage.
    const orgBudgetOk = await this.checkOrgLlmBudget();

    // Single-flight dedup — concurrent identical requests should NOT all
    // hit the LLM. The first claim wins (`SET NX EX 8s`); the rest poll the
    // cache key for up to 3s with a tighter cadence so the Node event loop
    // doesn't sit busy under reconnect storms (audit #18).
    const inflightKey = `ai:inflight:${req.userId}:${contextHash}`;
    const acquired = await this.redis.set(inflightKey, '1', 'EX', 8, 'NX');
    if (acquired !== 'OK') {
      // Poll: 6 × 250ms ≈ 1.5s. Worst-case waiter unblocks in 1.5s or falls
      // through to compute. Was 10 × 500ms = 5s of busy-waiting per request.
      for (let attempt = 0; attempt < 6; attempt++) {
        await new Promise((r) => setTimeout(r, 250));
        const winner = await this.safeReadJson(cacheKey);
        if (winner) return winner;
      }
      this.logger.warn(`/ai/suggest single-flight timeout user=${req.userId} hash=${contextHash}`);
    }

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

    // 5. Selection. Bounded by:
    //  - per-user daily LLM budget (scripted-account abuse)
    //  - org-wide kill switch (#8 OPENAI_DAILY_HARD_CAP_USD) — refuses LLM
    //    when the day's total spend has crossed the configured cap
    const perUserBudgetOk = await this.consumeLlmBudget(req.userId, req.isPremium);
    const allowLlm = perUserBudgetOk && orgBudgetOk;
    const wantLlmSelect = allowLlm && (req.mode === 'mood' || req.mode === 'detail' || !!enriched.mood || !!enriched.inferredMood);

    let finalTop: typeof ranked = [];
    let reasons: string[] = [];

    // Per-request cost accumulator. Mutated by every LLM call and written
    // into `ai_sessions.llm_cost_usd` so we can alert on spend anomalies
    // (audit hnag-audit-2026-05 §15 — column existed, never populated).
    const costTracker = newCostTracker();

    // 5a. Let the LLM actually choose for mood/detail flows (validated → no hallucination).
    // Audit AI-trace §M-9: gate behind a Redis-counter concurrency semaphore
    // so a traffic burst can't blow past the OpenAI org-level rate limit.
    let llmSelectSlot = false;
    if (wantLlmSelect) {
      llmSelectSlot = await this.acquireConcurrencySlot();
      if (llmSelectSlot) {
        try {
          const picks = await this.reason.select(ranked.slice(0, 15), enriched, req.limit, costTracker);
          if (picks?.length) {
            const byId = new Map(ranked.map((c) => [c.foodId, c] as const));
            for (const p of picks) {
              const c = byId.get(p.foodId);
              if (c) { finalTop.push(c); reasons.push(p.reason); }
            }
          }
        } finally {
          await this.releaseConcurrencySlot();
        }
      } else {
        this.logger.warn(`/ai/suggest concurrency-cap hit user=${req.userId} mode=${req.mode}`);
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
      let llmBatchSlot = false;
      const llmBatchWanted = allowLlm && !usedLlmForSelect;
      if (llmBatchWanted) llmBatchSlot = await this.acquireConcurrencySlot();
      try {
        const captions = await this.reason.batch(finalTop, enriched, {
          allowLlm: llmBatchWanted && llmBatchSlot,
          costTracker,
        });
        reasons = finalTop.map((_, i) => (reasons[i] && reasons[i].length ? reasons[i] : (captions[i] ?? '')));
      } finally {
        if (llmBatchSlot) await this.releaseConcurrencySlot();
      }
    }

    // Audit AI-trace §C-5: moderate AI-generated captions BEFORE sending to
    // client. The model can occasionally produce off-tone output (slurs,
    // hallucinations, jailbreak echo). Strip + replace with a safe fallback.
    // Moderation is cached + fast — runs once per unique caption text.
    if (reasons.length > 0) {
      const safeReasons = await Promise.all(
        reasons.map(async (r, i) => {
          if (!r) return r;
          try {
            const v = await this.moderation.check(r, { userId: req.userId });
            if (!v.allowed) {
              this.logger.warn(`/ai/suggest caption blocked: ${v.reason} — replaced with fallback`);
              const card = finalTop[i];
              return card ? `${card.title} — Hà thấy hợp tâm trạng bạn lúc này` : '';
            }
            return r;
          } catch {
            return r; // moderation blip → don't block UX, ship original
          }
        }),
      );
      reasons = safeReasons;
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

    // Degraded mode marker — flag when we couldn't reach LLM and fell
    // back to static captions. Client can show "Hà đang nghỉ trưa" copy
    // instead of pretending the LLM picked the cards.
    // Audit production-killer §10 "degraded mode": the suggest endpoint
    // must surface its own degradation so the UI doesn't lie about it.
    const degraded = wantLlmSelect && !usedLlmForSelect;
    const degradedReasons: string[] = [];
    if (degraded) degradedReasons.push('llm_unavailable');
    if (!perUserBudgetOk) degradedReasons.push('user_budget_exhausted');
    if (!orgBudgetOk) degradedReasons.push('org_budget_exhausted');

    const response: Record<string, unknown> = {
      sessionId,
      cards,
      reasonCodes: finalTop.flatMap((c) => c.reasonCodes),
    };
    if (degraded || degradedReasons.length > 0) {
      response.degraded = degraded;
      response.degradedReasons = degradedReasons;
    }

    // Cache + release single-flight lock (await this so concurrent waiters
    // can read the cache key before this request returns).
    await this.redis.setex(cacheKey, this.cacheTtlSec, JSON.stringify(response));
    this.redis.del(inflightKey).catch(() => null);

    const latencyMs = Date.now() - t0;
    this.logger.log(
      `/ai/suggest user=${req.userId} mode=${req.mode} latency=${latencyMs}ms cards=${cards.length} ` +
        `llm_calls=${costTracker.calls} llm_cost_usd=${costTracker.costUsd.toFixed(6)}`,
    );

    // Audit #17: ai_sessions write + spend bookkeeping + analytics used to
    // happen synchronously, blowing the p95 budget. Now fire-and-forget —
    // failures are logged at debug level. Reads of `ai_sessions` are
    // read-after-write only via /ai/refresh, which already polls.
    this.persistSessionAsync({
      sessionId,
      userId: req.userId,
      mode: req.mode,
      input: req.context,
      cards,
      rankerScores: finalTop.map((c) => c.scores),
      reasonCodes: finalTop.flatMap((c) => c.reasonCodes),
      latencyMs,
      llmCostUsd: costTracker.costUsd,
      llmCalls: costTracker.calls,
      llmUsed: usedLlmForSelect,
      isPremium: req.isPremium,
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
    // Audit workflow-trace §17: prior code had no idempotency, so a
    // double-tap from the client created two `food_interactions` rows,
    // doubling the skip-counter / taste-vector update. Use a short
    // Redis SETNX gate keyed on (session,food,action) — within 30s, a
    // second call is dropped.
    const idemKey = `ai:fb:${input.sessionId}:${input.foodId}:${input.action}`;
    const claimed = await this.redis.set(idemKey, '1', 'EX', 30, 'NX');
    if (claimed !== 'OK') {
      this.logger.debug(`feedback dedup ${idemKey}`);
      return;
    }
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

    // Analytics — `ai:feedback` is the canonical event for computing AI
    // acceptance rate, swipe-reject rate, save-through-rate per session.
    this.analytics.track({
      event: `ai:feedback:${input.action}`,
      userId: input.userId,
      sessionId: input.sessionId,
      properties: {
        foodId: input.foodId,
        action: input.action,
        rating: input.rating,
      },
    });
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

  /**
   * Persist `ai_sessions` + spend bookkeeping + analytics without blocking
   * the request thread (audit #17). Errors are logged at debug — a missing
   * row is acceptable; the cards already shipped to the user.
   */
  private persistSessionAsync(args: {
    sessionId: string;
    userId: string;
    mode: string;
    input: Record<string, unknown>;
    cards: unknown[];
    rankerScores: unknown[];
    reasonCodes: string[];
    latencyMs: number;
    llmCostUsd: number;
    llmCalls: number;
    llmUsed: boolean;
    isPremium: boolean;
  }): void {
    void (async () => {
      try {
        await this.prisma.ai_sessions.create({
          data: {
            id: args.sessionId,
            user_id: args.userId,
            mode: args.mode,
            input: args.input as any,
            output_cards: args.cards as any,
            ranker_scores: args.rankerScores as any,
            reason_codes: args.reasonCodes,
            latency_ms: args.latencyMs,
            llm_cost_usd: args.llmCostUsd.toFixed(5),
          },
        });
        if (args.llmCostUsd > 0) {
          const day = new Date().toISOString().slice(0, 10);
          const userDayKey = `ai:spend:${args.userId}:${day}`;
          const orgDayKey = `ai:spend:org:${day}`;
          const cents = Math.round(args.llmCostUsd * 100_000); // 1e-5 USD precision
          const pipe = this.redis.pipeline();
          pipe.incrby(userDayKey, cents);
          pipe.expire(userDayKey, 7 * 24 * 3600);
          pipe.incrby(orgDayKey, cents);
          pipe.expire(orgDayKey, 7 * 24 * 3600);
          await pipe.exec();
        }
        this.analytics.track({
          event: 'ai:suggest',
          userId: args.userId,
          sessionId: args.sessionId,
          properties: {
            mode: args.mode,
            cardCount: args.cards.length,
            latencyMs: args.latencyMs,
            llmUsed: args.llmUsed,
            llmCalls: args.llmCalls,
            llmCostUsd: Number(args.llmCostUsd.toFixed(6)),
            isPremium: args.isPremium,
          },
        });
      } catch (err) {
        this.logger.debug(`persistSessionAsync failed (${args.sessionId}): ${(err as Error).message}`);
      }
    })();
  }

  /**
   * Read a JSON-encoded Redis value with corruption protection.
   * If the stored value won't parse, DEL it and return null so the
   * caller falls through to recompute. Audit incident-readiness §10:
   * previously bad JSON in cache poisoned every request for the next
   * 5 minutes (until TTL expired).
   */
  private async safeReadJson<T = unknown>(key: string): Promise<T | null> {
    let raw: string | null;
    try {
      raw = await this.redis.get(key);
    } catch (err) {
      // Redis blip — don't cascade, just miss the cache.
      this.logger.debug(`safeReadJson(${key}) redis err: ${(err as Error).message}`);
      return null;
    }
    if (!raw) return null;
    try {
      return JSON.parse(raw) as T;
    } catch {
      this.logger.warn(`safeReadJson(${key}) bad JSON — DEL + recompute`);
      this.redis.del(key).catch(() => null);
      return null;
    }
  }

  /**
   * Charge cost from a standalone (non-suggest) LLM call into the same
   * per-user + org-wide spend counters used by suggest(). Audit AI-trace
   * §C-1/§C-2: previously voice/fridge spend invisible to kill switch.
   *
   * Fire-and-forget; failures debug-only because the spend metric should
   * never block a user-facing response.
   */
  async chargeStandaloneCall(userId: string, tracker: LlmCostTracker, label: string): Promise<void> {
    if (!tracker || tracker.costUsd <= 0) return;
    void (async () => {
      try {
        const day = new Date().toISOString().slice(0, 10);
        const userDayKey = `ai:spend:${userId}:${day}`;
        const orgDayKey = `ai:spend:org:${day}`;
        const cents = Math.round(tracker.costUsd * 100_000); // 1e-5 USD precision
        const pipe = this.redis.pipeline();
        pipe.incrby(userDayKey, cents);
        pipe.expire(userDayKey, 7 * 24 * 3600);
        pipe.incrby(orgDayKey, cents);
        pipe.expire(orgDayKey, 7 * 24 * 3600);
        await pipe.exec();
        this.analytics.track({
          event: `ai:${label}:cost`,
          userId,
          properties: {
            costUsd: Number(tracker.costUsd.toFixed(6)),
            calls: tracker.calls,
            promptTokens: tracker.promptTokens,
            completionTokens: tracker.completionTokens,
          },
        });
      } catch (err) {
        this.logger.debug(`chargeStandaloneCall(${label}) failed: ${(err as Error).message}`);
      }
    })();
  }

  /**
   * Org-wide concurrent LLM call cap (audit AI-trace §M-9). Returns false
   * if the org-wide in-flight counter is at OPENAI_MAX_CONCURRENT. Caller
   * MUST call `releaseConcurrencySlot` after the LLM call. Uses a Redis
   * counter with auto-expiry so a process crash doesn't leak slots.
   */
  async acquireConcurrencySlot(): Promise<boolean> {
    const cap = Number(process.env.OPENAI_MAX_CONCURRENT ?? '50');
    if (!Number.isFinite(cap) || cap <= 0) return true;
    const key = 'ai:concurrency:org';
    const count = await this.redis.incr(key);
    // 60s safety expiry — if a process dies mid-call, the slot frees itself
    // within a minute rather than leaking forever.
    if (count === 1) await this.redis.expire(key, 60);
    if (count > cap) {
      // Roll back immediately — we didn't actually get a slot.
      await this.redis.decr(key).catch(() => null);
      return false;
    }
    return true;
  }

  async releaseConcurrencySlot(): Promise<void> {
    try { await this.redis.decr('ai:concurrency:org'); } catch {/* swallow */}
  }

  /**
   * Org-wide LLM cost kill switch (audit #8). Returns false once today's
   * total spend in `ai:spend:org:YYYY-MM-DD` exceeds OPENAI_DAILY_HARD_CAP_USD.
   * Defaults to $50/day if unset — set this explicitly per growth stage.
   * Returns true on Redis errors (fail-open to avoid breaking the whole
   * surface from a Redis blip; the per-user budget still applies).
   */
  private async checkOrgLlmBudget(): Promise<boolean> {
    const capUsd = Number(process.env.OPENAI_DAILY_HARD_CAP_USD ?? '50');
    if (!Number.isFinite(capUsd) || capUsd <= 0) return true;
    try {
      const day = new Date().toISOString().slice(0, 10);
      const raw = await this.redis.get(`ai:spend:org:${day}`);
      const cents = Number(raw ?? '0');
      const usdToday = cents / 100_000;
      if (usdToday >= capUsd) {
        this.logger.warn(`ORG LLM kill-switch: today $${usdToday.toFixed(2)} >= cap $${capUsd}`);
        return false;
      }
      return true;
    } catch {
      return true;
    }
  }

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
