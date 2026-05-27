import { Injectable, Inject, Logger } from '@nestjs/common';
import OpenAI from 'openai';
import IORedis from 'ioredis';
import { createHash } from 'crypto';

import { REDIS } from '../../../common/redis/redis.module';
import { Candidate } from './candidate-generator.service';
import { EnrichedContext } from './context-builder.service';
import { PromptRegistry } from '../prompts/prompt-registry.service';
import { ModelRouter } from './model-router.service';

/**
 * Pricing per 1M tokens, in USD as of 2026-05. Used by chargeUsage().
 * Update via env (`<inputUsd>:<outputUsd>` per 1M) if rates change.
 *
 *   gpt-4o-mini   input  $0.15 / 1M    output $0.60 / 1M
 *   gpt-4o        input  $5.00 / 1M    output $15.00 / 1M
 *   whisper-1                          $0.006 / minute (charge by duration, not tokens)
 */
const [OPENAI_INPUT_PER_TOKEN, OPENAI_OUTPUT_PER_TOKEN] = (() => {
  const raw = process.env.OPENAI_PRICING_USD_PER_M ?? '0.15:0.60';
  const [i, o] = raw.split(':').map((s) => Number(s.trim()));
  const inP = Number.isFinite(i) ? i / 1_000_000 : 0.00000015;
  const ouP = Number.isFinite(o) ? o / 1_000_000 : 0.00000060;
  return [inP, ouP];
})();
/** gpt-4o costs ~33x mini — surface separately so cost-router accounting is honest. */
export const OPENAI_GPT4O_INPUT_PER_TOKEN = Number(process.env.OPENAI_GPT4O_INPUT_USD_PER_M ?? '5.00') / 1_000_000;
export const OPENAI_GPT4O_OUTPUT_PER_TOKEN = Number(process.env.OPENAI_GPT4O_OUTPUT_USD_PER_M ?? '15.00') / 1_000_000;
/** Whisper billed by minute, not token. */
export const OPENAI_WHISPER_USD_PER_MIN = Number(process.env.OPENAI_WHISPER_USD_PER_MIN ?? '0.006');

/**
 * Per-request cost tracker, mutated by every LLM call made during a single
 * `suggest()` invocation. The orchestrator instantiates one and writes the
 * final `costUsd` into `ai_sessions.llm_cost_usd` (audit hnag-audit-2026-05
 * §15: previously NEVER populated → impossible to alert on spend anomalies).
 *
 * Plain object + mutation chosen over a service so each request gets a
 * fresh isolated tracker — no cross-request leakage under concurrency.
 */
export interface LlmCostTracker {
  costUsd: number;
  promptTokens: number;
  completionTokens: number;
  calls: number;
}

export function newCostTracker(): LlmCostTracker {
  return { costUsd: 0, promptTokens: 0, completionTokens: 0, calls: 0 };
}

function chargeUsage(
  tracker: LlmCostTracker | undefined,
  usage: { prompt_tokens?: number; completion_tokens?: number } | null | undefined,
  model?: string,
): void {
  if (!tracker || !usage) return;
  const p = usage.prompt_tokens ?? 0;
  const c = usage.completion_tokens ?? 0;
  tracker.promptTokens += p;
  tracker.completionTokens += c;
  // Audit AI-trace §C-1/§C-2: per-model pricing so gpt-4o (premium) is
  // properly charged at 33x the gpt-4o-mini rate. Default to mini.
  const isGpt4o = (model ?? '').startsWith('gpt-4o') && !(model ?? '').includes('mini');
  const inRate = isGpt4o ? OPENAI_GPT4O_INPUT_PER_TOKEN : OPENAI_INPUT_PER_TOKEN;
  const outRate = isGpt4o ? OPENAI_GPT4O_OUTPUT_PER_TOKEN : OPENAI_OUTPUT_PER_TOKEN;
  tracker.costUsd += p * inRate + c * outRate;
  tracker.calls += 1;
}

/** Exported so VoiceService / FridgeService can charge the same tracker. */
export function chargeOpenaiUsage(
  tracker: LlmCostTracker | undefined,
  usage: { prompt_tokens?: number; completion_tokens?: number } | null | undefined,
  model?: string,
): void {
  chargeUsage(tracker, usage, model);
}

/** Whisper is billed by audio minute. Estimate duration from the buffer
 *  size — a reasonable approximation for opus/m4a/mp3 at ~32-64 kbps
 *  speech codecs (~5-8 KB/sec). Caller can pass exact duration if known. */
export function chargeWhisperUsage(
  tracker: LlmCostTracker | undefined,
  audioBytes: number,
  exactSeconds?: number,
): void {
  if (!tracker) return;
  const seconds = exactSeconds ?? Math.max(1, audioBytes / 6500); // ~52 kbps avg
  const minutes = seconds / 60;
  tracker.costUsd += minutes * OPENAI_WHISPER_USD_PER_MIN;
  tracker.calls += 1;
}

@Injectable()
export class LlmReasonService {
  private readonly logger = new Logger(LlmReasonService.name);
  private readonly client: OpenAI | null;

  constructor(
    @Inject(REDIS) private readonly redis: IORedis,
    private readonly prompts: PromptRegistry,
    private readonly router: ModelRouter,
  ) {
    this.client = process.env.OPENAI_API_KEY
      ? new OpenAI({
          apiKey: process.env.OPENAI_API_KEY,
          // Hard deadline + one retry so a slow OpenAI response can't stall the
          // request budget (falls back to the static lines on timeout).
          timeout: 8000,
          maxRetries: 1,
        })
      : null;
  }

  async batch(
    cards: Candidate[],
    ctx: EnrichedContext,
    opts?: { allowLlm?: boolean; costTracker?: LlmCostTracker },
  ): Promise<string[]> {
    const allowLlm = opts?.allowLlm !== false;
    // Cache key per (food_id × context-bucket)
    const bucket = this.bucketize(ctx);
    const keys = cards.map((c) => `ai:reason:${c.foodId}:${bucket}`);
    const cached = await this.redis.mget(...keys);

    const missingIdx: number[] = [];
    const reasons: string[] = cards.map((_, i) => {
      const v = cached[i];
      if (v) return v;
      missingIdx.push(i);
      return '';
    });

    if (missingIdx.length === 0) return reasons;
    // No client, or the caller's daily LLM budget is exhausted → static fallback.
    if (!this.client || !allowLlm) {
      for (const i of missingIdx) {
        reasons[i] = this.fallback(cards[i], ctx);
      }
      return reasons;
    }

    const toGenerate = missingIdx.map((i) => cards[i]);
    try {
      const generated = await this.callLlm(toGenerate, ctx, opts?.costTracker);
      const pipe = this.redis.pipeline();
      missingIdx.forEach((idx, j) => {
        reasons[idx] = generated[j] ?? this.fallback(cards[idx], ctx);
        pipe.setex(keys[idx], 3600, reasons[idx]);
      });
      await pipe.exec();
    } catch (e) {
      this.logger.warn(`LLM batch failed, using fallback: ${(e as Error).message}`);
      for (const i of missingIdx) reasons[i] = this.fallback(cards[i], ctx);
    }
    return reasons;
  }

  /**
   * Let the LLM actually CHOOSE the best `limit` dishes for the context and
   * explain each. Returns picks by foodId with reasons. Strictly validated
   * against the candidate set (indices only) so it cannot hallucinate a dish.
   * Returns null on any failure → caller falls back to the heuristic ranker.
   */
  async select(
    cards: Candidate[],
    ctx: EnrichedContext,
    limit: number,
    tracker?: LlmCostTracker,
  ): Promise<{ foodId: string; reason: string }[] | null> {
    const client = this.client;
    if (!client || cards.length === 0) return null;
    const list = cards
      .map((c, i) => `${i}. ${c.title} | ${c.cuisine}, tags: ${c.tags.slice(0, 4).join(',')} | ${c.priceVnd}đ | ${c.rating.avg}★`)
      .join('\n');
    const user = `NGỮ CẢNH user:
- Thời tiết: ${ctx.weather.condition}, ${ctx.weather.temp}°C · Giờ: ${ctx.hour}h
- Mood: ${ctx.mood ?? ctx.inferredMood ?? 'không rõ'} · Đi cùng: ${ctx.with ?? 'solo'} · Ngân sách tối đa: ${ctx.budget?.max ?? '?'}đ

DANH SÁCH MÓN (chọn TỪ đây, theo index):
${list}

Chọn ${limit} món hợp NHẤT với ngữ cảnh, đa dạng (không trùng kiểu). Mỗi món 1 câu ≤22 từ giải thích vì sao hợp.
CHỈ trả về index có trong danh sách. JSON: { "picks": [ {"i": 0, "reason": "..."}, ... ] }`;

    try {
      const prompt = this.prompts.get('reason.select');
      const choice = this.router.pick(prompt, {
        isPremium: false, // caller hasn't threaded tier through yet — accept the cheap pick
        mode: undefined,
        withinBudget: true,
      });
      const completion = await client.chat.completions.create({
        model: choice.model,
        response_format: { type: 'json_object' },
        messages: [
          { role: 'system', content: prompt.system },
          { role: 'user', content: user },
        ],
        temperature: 0.4,
        max_tokens: choice.maxOutputTokens,
      });
      chargeUsage(tracker, completion.usage, choice.model);
      const parsed = JSON.parse(completion.choices[0]?.message?.content ?? '{}');
      const picks: { i: number; reason: string }[] = parsed.picks ?? [];
      const out: { foodId: string; reason: string }[] = [];
      const seen = new Set<number>();
      for (const p of picks) {
        const i = Number(p.i);
        if (Number.isInteger(i) && i >= 0 && i < cards.length && !seen.has(i)) {
          seen.add(i);
          out.push({ foodId: cards[i].foodId, reason: String(p.reason ?? '').slice(0, 160) });
        }
        if (out.length >= limit) break;
      }
      return out.length ? out : null;
    } catch (e) {
      this.logger.warn(`LLM select failed, falling back to ranker: ${(e as Error).message}`);
      return null;
    }
  }

  private async callLlm(cards: Candidate[], ctx: EnrichedContext, tracker?: LlmCostTracker): Promise<string[]> {
    const user = `CONTEXT chung:
- Thời tiết: ${ctx.weather.condition}, ${ctx.weather.temp}°C
- Giờ: ${ctx.hour}h
- Mood: ${ctx.mood ?? ctx.inferredMood ?? 'không nói'}
- Ngân sách: ${ctx.budget?.max ?? '?'}đ
- Đi cùng: ${ctx.with ?? 'solo'}

DANH SÁCH MÓN:
${cards.map((c, i) => `${i + 1}. ${c.title} | ${c.cuisine}, tags: ${c.tags.slice(0, 3).join(',')} | giá ${c.priceVnd}đ`).join('\n')}

YÊU CẦU: mỗi món 1 câu ≤25 từ; mỗi lý do KHÁC NHAU.
Trả JSON: { "reasons": [{"food_idx": 1, "reason": "..."}, ...] }.`;

    const prompt = this.prompts.get('reason.caption');
    const choice = this.router.pick(prompt, {
      isPremium: false,
      mode: undefined,
      withinBudget: true,
    });
    const completion = await this.client!.chat.completions.create({
      model: choice.model,
      response_format: { type: 'json_object' },
      messages: [
        { role: 'system', content: prompt.system },
        { role: 'user', content: user },
      ],
      temperature: 0.5,
      max_tokens: choice.maxOutputTokens,
    });
    chargeUsage(tracker, completion.usage, choice.model);

    const raw = completion.choices[0]?.message?.content ?? '{}';
    const parsed = JSON.parse(raw);
    const arr: { food_idx: number; reason: string }[] = parsed.reasons ?? [];
    const out: string[] = new Array(cards.length).fill('');
    for (const r of arr) {
      const i = (r.food_idx ?? 1) - 1;
      if (i >= 0 && i < cards.length) out[i] = r.reason ?? '';
    }
    return out;
  }

  private bucketize(ctx: EnrichedContext): string {
    const part = [
      ctx.weather.condition,
      ctx.hour < 11 ? 'morning' : ctx.hour < 14 ? 'lunch' : ctx.hour < 17 ? 'afternoon' : ctx.hour < 22 ? 'evening' : 'night',
      ctx.mood ?? 'none',
      Math.floor((ctx.budget?.max ?? 0) / 30000),
    ].join('|');
    return createHash('md5').update(part).digest('hex').slice(0, 12);
  }

  private fallback(c: Candidate, ctx: EnrichedContext): string {
    const t = c.title.toLowerCase();
    // Weather-aware
    if (ctx.weather.condition === 'rain') {
      if (t.includes('phở') || t.includes('bún bò') || t.includes('cháo')) return `Trời mưa, tô ${t} ấm bụng — đúng vibe Hà Nội`;
      if (t.includes('lẩu')) return `Mưa lạnh, lẩu nóng — combo trời cho`;
      return `Mưa rồi, ${t} ấm bụng nha`;
    }
    // Late night
    if (ctx.isLateNight) {
      if (t.includes('cháo')) return `Khuya rồi, cháo nhẹ bụng dễ ngủ`;
      if (t.includes('xôi') || t.includes('bánh mì')) return `Đói khuya à? ${t} nhanh gọn`;
      return `Khuya khoét, ${t} nhẹ bụng thôi`;
    }
    // Time of day
    if (ctx.hour < 11) {
      if (t.includes('phở') || t.includes('bún')) return `Sáng đói rồi, ${t} bao no nguyên buổi`;
      if (t.includes('xôi') || t.includes('bánh mì') || t.includes('cà phê')) return `Sáng nay làm ${t}, vừa nhanh vừa ấm`;
      return `Bữa sáng ngon: ${t}`;
    }
    if (ctx.hour >= 17 && ctx.hour < 21) {
      if (t.includes('lẩu') || t.includes('nướng') || t.includes('bbq')) return `Tối rồi, ${t} hợp bạn bè`;
      if (t.includes('cơm')) return `Tối nay cơm nhà — ${t}`;
      return `Bữa tối: ${t} — ngon mà nhẹ`;
    }
    // Quality signals
    if (c.rating.avg >= 4.7 && c.rating.count > 500) return `${c.title} — ${c.rating.avg}★ với ${c.rating.count} người khen`;
    if (c.trendingScore > 80) return `${c.title} đang hot tuần này, đáng thử`;
    if (c.priceVnd < 35000) return `Hấp dẫn ${c.title} mà chỉ ${Math.round(c.priceVnd / 1000)}k`;
    if (c.priceVnd > 150000) return `Tự thưởng nha: ${c.title}`;

    // Category fallbacks
    if (t.includes('chè') || t.includes('kem')) return `Ngọt ngào cho buổi chiều, ${t}`;
    if (t.includes('trà sữa')) return `Ly ${t} — đúng vibe Gen Z hôm nay`;
    if (t.includes('salad') || t.includes('healthy')) return `${c.title} — clean mà vẫn ngon`;
    if (t.includes('bún') || t.includes('mì')) return `${c.title} — bữa quen mà không chán`;
    if (t.includes('cơm')) return `Bữa cơm tử tế: ${c.title}`;

    return `Hà thấy ${c.title.toLowerCase()} hợp tâm trạng bạn lúc này`;
  }
}
