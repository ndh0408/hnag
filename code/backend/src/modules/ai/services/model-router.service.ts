import { Injectable, Logger } from '@nestjs/common';

import { PromptDefinition } from '../prompts/prompt-registry.service';

/**
 * Multi-model cost router.
 *
 * Closes audit prompt-pack §6 ("cost-defense layer" → multi-model routing,
 * cheap-fallback). Without routing, every LLM call goes to one model and:
 *   - free-tier users burn the same per-call cost as premium
 *   - high-quality prompts (long-context, complex reasoning) run on the
 *     same tiny model as one-liner caption generation
 *   - we can't escape gpt-4o-mini's quality ceiling for premium without
 *     refactoring every call site
 *
 * The router takes the prompt definition + caller context (user tier,
 * mode) and returns the model name + token caps. Callers pass that into
 * the OpenAI completion call.
 *
 * Defaults (override via env):
 *   - MODEL_CHEAP    = gpt-4o-mini  (default for caption / low-stakes)
 *   - MODEL_PREMIUM  = gpt-4o       (premium users on detail/mood/voice)
 *   - MODEL_FALLBACK = gpt-4o-mini  (used when premium fails or budget exceeded)
 *
 * The router is stateless — no Redis, no DB. Pure function over inputs.
 * For per-user spend caps, see consumeLlmBudget in ai-orchestrator.
 */
export type ModelTier = 'cheap' | 'premium' | 'fallback';

export interface ModelChoice {
  model: string;
  tier: ModelTier;
  maxOutputTokens: number;
  /** Why this model was picked — useful for debug logs + analytics. */
  reason: string;
}

export interface RouteContext {
  /** Is the calling user on a paid plan today? */
  isPremium: boolean;
  /** Coarse mode — drives quality requirements. */
  mode?: 'quick' | 'detail' | 'mood' | 'voice' | 'fridge' | 'group';
  /** Whether the per-user daily LLM budget is still under cap. */
  withinBudget: boolean;
  /** Backend-side mood-or-quality bump (e.g. fridge-scan needs better reasoning). */
  needsHighQuality?: boolean;
}

@Injectable()
export class ModelRouter {
  private readonly logger = new Logger(ModelRouter.name);
  private readonly CHEAP = process.env.MODEL_CHEAP ?? 'gpt-4o-mini';
  private readonly PREMIUM = process.env.MODEL_PREMIUM ?? 'gpt-4o';
  private readonly FALLBACK = process.env.MODEL_FALLBACK ?? 'gpt-4o-mini';

  /**
   * Pick the right model for a given (prompt × context) pair.
   *
   * Routing matrix (top-to-bottom precedence):
   *   1. Over budget                                → FALLBACK (cheap, just keep working)
   *   2. Prompt explicitly cheap-tier               → CHEAP
   *   3. Free user                                  → CHEAP
   *   4. Premium user + (high-quality mode OR
   *      prompt premium-tier)                       → PREMIUM
   *   5. Premium user, low-stakes (caption)         → CHEAP (don't waste $)
   */
  pick(prompt: PromptDefinition, ctx: RouteContext): ModelChoice {
    if (!ctx.withinBudget) {
      return {
        model: this.FALLBACK,
        tier: 'fallback',
        maxOutputTokens: Math.min(prompt.estimatedTokens.output, 200),
        reason: 'budget_exceeded',
      };
    }
    if (prompt.preferredTier === 'cheap' && !ctx.needsHighQuality) {
      return {
        model: this.CHEAP,
        tier: 'cheap',
        maxOutputTokens: prompt.estimatedTokens.output,
        reason: 'prompt_cheap_tier',
      };
    }
    if (!ctx.isPremium) {
      return {
        model: this.CHEAP,
        tier: 'cheap',
        maxOutputTokens: prompt.estimatedTokens.output,
        reason: 'free_user',
      };
    }
    const highQualityMode = ['detail', 'voice', 'fridge'].includes(ctx.mode ?? '');
    if (highQualityMode || prompt.preferredTier === 'premium' || ctx.needsHighQuality) {
      return {
        model: this.PREMIUM,
        tier: 'premium',
        maxOutputTokens: prompt.estimatedTokens.output,
        reason: highQualityMode ? `premium_mode:${ctx.mode}` : 'premium_prompt',
      };
    }
    // Premium user, low-stakes prompt — still pick cheap to bound monthly spend.
    return {
      model: this.CHEAP,
      tier: 'cheap',
      maxOutputTokens: prompt.estimatedTokens.output,
      reason: 'premium_user_low_stakes',
    };
  }
}
