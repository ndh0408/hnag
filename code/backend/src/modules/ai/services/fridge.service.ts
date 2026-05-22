import { Injectable, Logger, BadRequestException } from '@nestjs/common';
import OpenAI from 'openai';
import { PrismaService } from '../../../common/prisma/prisma.service';

/**
 * Real Fridge Scan: GPT-4o-mini vision detects ingredients from a photo, then we
 * match cookable dishes. The matching logic is shared with the public text-only
 * endpoint.
 */
@Injectable()
export class FridgeService {
  private readonly logger = new Logger(FridgeService.name);
  private readonly client: OpenAI | null;

  constructor(private readonly prisma: PrismaService) {
    this.client = process.env.OPENAI_API_KEY
      ? new OpenAI({ apiKey: process.env.OPENAI_API_KEY, timeout: 30_000, maxRetries: 1 })
      : null;
  }

  /** Detect ingredients from a fridge/pantry image (data URL or https URL). */
  async detectIngredients(image: string): Promise<string[]> {
    const client = this.client;
    if (!client) throw new BadRequestException('Tính năng nhận diện ảnh chưa được bật');
    if (!/^data:image\/[a-z]+;base64,/i.test(image) && !/^https?:\/\//.test(image)) {
      throw new BadRequestException('Ảnh không hợp lệ (cần data URL base64 hoặc https URL)');
    }
    const completion = await client.chat.completions.create({
      model: 'gpt-4o-mini',
      response_format: { type: 'json_object' },
      temperature: 0.2,
      max_tokens: 300,
      messages: [
        { role: 'system', content: 'Bạn nhận diện nguyên liệu nấu ăn trong ảnh tủ lạnh/bếp. Chỉ liệt kê nguyên liệu ăn được, tên tiếng Việt thường dùng.' },
        {
          role: 'user',
          content: [
            { type: 'text', text: 'Liệt kê nguyên liệu thấy trong ảnh. JSON: {"ingredients":["trứng","cà chua",...]} (tối đa 25, không trùng, không bịa).' },
            { type: 'image_url', image_url: { url: image } },
          ] as any,
        },
      ],
    });
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
