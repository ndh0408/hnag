import { Injectable, Logger, BadRequestException, HttpException, HttpStatus } from '@nestjs/common';
import OpenAI from 'openai';
import { PrismaService } from '../../../common/prisma/prisma.service';
import { ModerationService } from './moderation.service';
import { PromptRegistry } from '../prompts/prompt-registry.service';
import { LlmCostTracker, chargeOpenaiUsage } from './llm-reason.service';

/**
 * Real Fridge Scan: GPT-4o-mini vision detects ingredients from a photo, then we
 * match cookable dishes. The matching logic is shared with the public text-only
 * endpoint.
 *
 * Audit #34: any user-supplied image MUST pass an image moderation gate
 * before being forwarded to the vision model. Otherwise an attacker can
 * upload CSAM / violence and get our OpenAI org banned. We use OpenAI's
 * `omni-moderation-latest` which supports image inputs as data URLs.
 */
@Injectable()
export class FridgeService {
  private readonly logger = new Logger(FridgeService.name);
  private readonly client: OpenAI | null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly moderation: ModerationService,
    private readonly prompts: PromptRegistry,
  ) {
    this.client = process.env.OPENAI_API_KEY
      ? new OpenAI({ apiKey: process.env.OPENAI_API_KEY, timeout: 30_000, maxRetries: 1 })
      : null;
  }

  /** Detect ingredients from a fridge/pantry image (data URL or https URL). */
  async detectIngredients(image: string, opts: { userId?: string; tracker?: LlmCostTracker } = {}): Promise<string[]> {
    const client = this.client;
    if (!client) throw new BadRequestException('Tính năng nhận diện ảnh chưa được bật');
    // Only allow data URLs for our own JPEG/PNG/WEBP, or https URLs hosted on
    // our CDN. Reject arbitrary https to prevent SSRF / abuse via 3rd-party
    // image hosts (audit #34 + defence in depth).
    const isDataUrl = /^data:image\/(jpeg|jpg|png|webp);base64,/i.test(image);
    const isOurCdn = /^https:\/\/(app|cdn|media)\.tothanhthuy\.cloud\//i.test(image);
    if (!isDataUrl && !isOurCdn) {
      throw new BadRequestException('Ảnh không hợp lệ');
    }
    // Image moderation gate (audit #34). Vision moderation API call adds
    // ~200ms; we accept that since the route is Premium-gated + rate-limited.
    const verdict = await this.moderation.checkImage(image, { userId: opts.userId });
    if (!verdict.allowed) {
      this.logger.warn(`Fridge-scan image rejected by moderation: reason=${verdict.reason}`);
      throw new HttpException(
        { code: 'MODERATION_BLOCKED', message: 'Ảnh không phù hợp', reason: verdict.reason },
        HttpStatus.UNPROCESSABLE_ENTITY,
      );
    }
    // Audit AI-trace §C-6: system prompt moved to PromptRegistry (versioned).
    const prompt = this.prompts.get('fridge.detect');
    const completion = await client.chat.completions.create({
      model: 'gpt-4o-mini',
      response_format: { type: 'json_object' },
      temperature: 0.2,
      max_tokens: prompt.estimatedTokens.output,
      messages: [
        { role: 'system', content: prompt.system },
        {
          role: 'user',
          content: [
            { type: 'text', text: 'Liệt kê nguyên liệu thấy trong ảnh. JSON: {"ingredients":["trứng","cà chua",...]} (tối đa 25, không trùng, không bịa).' },
            { type: 'image_url', image_url: { url: image } },
          ] as any,
        },
      ],
    });
    // Audit AI-trace §C-2: charge vision spend to the shared tracker so
    // org-wide kill-switch + per-user budget see it.
    chargeOpenaiUsage(opts.tracker, completion.usage, 'gpt-4o-mini');
    const parsed = JSON.parse(completion.choices[0]?.message?.content ?? '{}');
    const arr: unknown[] = Array.isArray(parsed.ingredients) ? parsed.ingredients : [];
    return Array.from(new Set(
      arr.map((s) => String(s).toLowerCase().trim().slice(0, 40)).filter(Boolean),
    )).slice(0, 25);
  }

  /** Match foods cookable from a list of ingredients. */
  async matchRecipes(ingredients: string[], maxTimeIn = 60) {
    const ings = ingredients.map((s) => String(s).toLowerCase().trim()).filter(Boolean).slice(0, 30);
    if (!ings.length) return { ingredients: [], recipes: [] };
    const maxTime = Math.min(Math.max(Number(maxTimeIn) || 60, 1), 240);

    const all = await this.prisma.foods.findMany({
      where: { status: 'active', cook_time_min: { lte: maxTime } },
      take: 200,
    });

    // Match on whole ingredient phrase OR any of its words, so "cà chua bi"
    // still matches a food that lists "cà chua".
    const tokens = (s: string) => s.split(/\s+/).filter((w) => w.length >= 2);
    const scored = all
      .map((f) => {
        const haystack = [
          f.name_vi ?? '', f.description ?? '',
          JSON.stringify(f.ingredients ?? {}), JSON.stringify(f.recipe ?? {}),
          (f.flavor_tags ?? []).join(' '), (f.diet_tags ?? []).join(' '),
        ].join(' ').toLowerCase();
        const phraseHits = ings.filter((i) => haystack.includes(i));
        const tokenHits = ings.filter(
          (i) => !phraseHits.includes(i) && tokens(i).some((w) => haystack.includes(w)),
        );
        const matched = [...phraseHits, ...tokenHits];
        return { food: f, matched, hits: matched.length, phrase: phraseHits.length };
      })
      // Meaningful overlap only: at least one exact ingredient, or >=2 token hits.
      // Otherwise we'd present an unrelated dish as "cookable" (the old bug).
      .filter((s) => s.phrase >= 1 || s.hits >= 2)
      .sort((a, b) => (b.hits - a.hits) || ((a.food.cook_time_min ?? 60) - (b.food.cook_time_min ?? 60)))
      .slice(0, 5);

    // Honest result: if nothing genuinely matches, return an empty list so the
    // app can say "no dish found" instead of suggesting irrelevant food.
    return {
      ingredients: ings,
      recipes: scored.map((s) => ({
        food: s.food,
        uses: s.matched,
        missing: ings.filter((i) => !s.matched.includes(i)),
        tip: `Tận dụng ${s.hits}/${ings.length} nguyên liệu bạn có. Khoảng ${s.food.cook_time_min ?? 30} phút.`,
      })),
    };
  }
}
