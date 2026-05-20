/**
 * AI-powered public endpoints (no auth) — for unauthenticated mobile clients
 * to get real food suggestions immediately.
 */
import { Controller, Get, Query, Post, Body } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { ApiTags } from '@nestjs/swagger';
import { PrismaService } from '../../common/prisma/prisma.service';

const MOOD_FILTERS: Record<string, { tags: string[]; categories: string[]; reason: string }> = {
  happy:      { tags: ['vui', 'celebrate'],  categories: ['grill', 'snack', 'dessert'], reason: 'Vui mà — quẩy chút đi' },
  sad:        { tags: ['comfort'],            categories: ['soup', 'noodle'],            reason: 'Buồn hả? Tô ấm ấm cho khỏe' },
  stress:     { tags: ['stress', 'comfort'],  categories: ['soup', 'grill'],             reason: 'Stress thì lẩu / nướng xả đi' },
  lonely:     { tags: ['comfort'],            categories: ['rice', 'noodle'],            reason: 'Cô đơn cũng phải ăn ngon nha' },
  chill:      { tags: ['chill'],              categories: ['drink', 'dessert', 'snack'], reason: 'Chill mode: nhâm nhi nhẹ thôi' },
  late_night: { tags: ['latenight'],          categories: ['noodle', 'snack', 'rice'],   reason: 'Khuya thèm gì? Đây nè, nhẹ bụng' },
  tired:      { tags: ['comfort'],            categories: ['soup', 'noodle', 'rice'],    reason: 'Mệt rồi, tô đầy năng lượng' },
  rushed:     { tags: ['nhanh'],              categories: ['street', 'snack'],           reason: 'Vội nha — ăn nhanh xong việc' },
  broke:      { tags: ['bình dân'],           categories: ['street', 'rice'],            reason: 'Hết tháng rồi mà — gì rẻ ngon ăn nấy' },
  celebrate:  { tags: ['vui', 'sang chảnh'],  categories: ['grill', 'seafood'],          reason: 'Đáng tự thưởng đó!' },
};

@ApiTags('AI Public')
@Throttle({ default: { limit: 30, ttl: 60_000 } })
@Controller('ai')
export class AiPublicController {
  constructor(private readonly prisma: PrismaService) {}

  /** Smart suggestion based on time of day + weather + budget (no auth needed). */
  @Get('suggest-public')
  async suggest(
    @Query('hour') hour?: string,
    @Query('budget') budget?: string,
    @Query('limit') limit?: string,
  ) {
    const h = hour ? parseInt(hour) : new Date().getHours();
    const b = budget ? parseInt(budget) : 200000;
    const n = limit ? Math.min(parseInt(limit), 20) : 8;

    // Time-based category filter
    let categories: string[] = [];
    if (h < 11)        categories = ['noodle', 'rice', 'street', 'drink'];      // breakfast
    else if (h < 14)   categories = ['noodle', 'rice', 'soup'];                  // lunch
    else if (h < 17)   categories = ['snack', 'drink', 'dessert'];               // afternoon
    else if (h < 22)   categories = ['rice', 'grill', 'soup', 'noodle'];         // dinner
    else               categories = ['noodle', 'snack', 'rice'];                 // late

    const foods = await this.prisma.foods.findMany({
      where: {
        status: 'active',
        avg_price_vnd: { lte: b },
        category: { in: categories },
      },
      orderBy: [{ trending_score: 'desc' }, { rating_avg: 'desc' }],
      take: n,
    });

    return foods.map((f) => ({
      ...f,
      _ai_reason: this.contextReason(f, h),
    }));
  }

  /** Mood-based suggestions: filter foods by mood tags. */
  @Get('mood-suggest')
  async byMood(@Query('mood') mood: string, @Query('limit') limit?: string) {
    const filter = MOOD_FILTERS[mood] ?? MOOD_FILTERS.chill;
    const n = limit ? Math.min(parseInt(limit), 20) : 8;

    const tagMatch = filter.tags.length > 0
      ? await this.prisma.foods.findMany({
          where: {
            status: 'active',
            OR: [
              { mood_tags: { hasSome: filter.tags } },
              { vibe_tags: { hasSome: filter.tags } },
            ],
          },
          take: Math.ceil(n * 1.5),
          orderBy: { trending_score: 'desc' },
        })
      : [];

    let foods = tagMatch;
    if (foods.length < n) {
      const catMatch = await this.prisma.foods.findMany({
        where: { status: 'active', category: { in: filter.categories } },
        take: n - foods.length + 5,
        orderBy: { rating_avg: 'desc' },
      });
      // Dedupe + extend
      const seen = new Set(foods.map((f) => f.id));
      for (const c of catMatch) {
        if (!seen.has(c.id)) {
          foods.push(c);
          seen.add(c.id);
        }
        if (foods.length >= n) break;
      }
    }

    return {
      mood,
      theme: filter.reason,
      foods: foods.slice(0, n).map((f) => ({
        ...f,
        _ai_reason: this.moodReason(f, mood, filter.reason),
      })),
    };
  }

  /** Random foods for the wheel — by category if provided. */
  @Get('random')
  async random(@Query('n') n?: string, @Query('category') category?: string) {
    const count = n ? Math.min(parseInt(n), 20) : 8;
    // Postgres RANDOM() ordering — fast enough for 60 foods
    const where: any = { status: 'active' };
    if (category) where.category = category;
    const all = await this.prisma.foods.findMany({ where, take: 100 });
    return shuffle(all).slice(0, count);
  }

  /** From a list of ingredients → return foods that can be made. */
  @Post('fridge-recipes')
  async fridgeRecipes(@Body() body: { ingredients: string[]; timeMin?: number }) {
    const ings = (body.ingredients ?? []).map((s) => s.toLowerCase().trim()).filter(Boolean);
    if (ings.length === 0) return { recipes: [] };
    const maxTime = body.timeMin ?? 60;

    // Match foods by name/description containing any user ingredient.
    const all = await this.prisma.foods.findMany({
      where: {
        status: 'active',
        cook_time_min: { lte: maxTime },
      },
      take: 200,
    });

    const scored = all
      .map((f) => {
        const haystack = [
          f.name_vi ?? '',
          f.description ?? '',
          JSON.stringify(f.ingredients ?? {}),
          JSON.stringify(f.recipe ?? {}),
          (f.flavor_tags ?? []).join(' '),
          (f.diet_tags ?? []).join(' '),
        ].join(' ').toLowerCase();
        const matched = ings.filter((i) => haystack.includes(i));
        return { food: f, hits: matched.length, matched };
      })
      .filter((s) => s.hits > 0)
      .sort((a, b) => {
        if (b.hits !== a.hits) return b.hits - a.hits;
        return (a.food.cook_time_min ?? 60) - (b.food.cook_time_min ?? 60);
      })
      .slice(0, 5);

    if (scored.length > 0) {
      return {
        recipes: scored.map((s) => ({
          food: s.food,
          uses: s.matched,
          missing: ings.filter((i) => !s.matched.includes(i)),
          tip: `Tận dụng ${s.hits}/${ings.length} nguyên liệu bạn có. Khoảng ${s.food.cook_time_min ?? 30} phút.`,
        })),
      };
    }

    // Fallback — pick fastest 3 easy recipes
    const easy = all
      .filter((f) => (f.cook_time_min ?? 60) <= 25)
      .sort((a, b) => (a.cook_time_min ?? 60) - (b.cook_time_min ?? 60))
      .slice(0, 3);
    return {
      recipes: easy.map((f) => ({
        food: f,
        uses: ings,
        missing: ['cần thêm vài nguyên liệu phụ'],
        tip: `Món dễ làm khoảng ${f.cook_time_min ?? 30} phút`,
      })),
    };
  }

  // ─── helpers ────────────────────────────────────────────────────────

  private contextReason(f: any, hour: number): string {
    const t = (f.name_vi ?? '').toLowerCase();
    if (hour < 11)        return /phở|bún|xôi|bánh mì|cà phê/.test(t) ? `Sáng đói rồi, ${f.name_vi} bao no` : `Bữa sáng: ${f.name_vi}`;
    if (hour < 14)        return `Trưa nay làm ${f.name_vi} đi, ${Math.round(f.avg_price_vnd / 1000)}k thôi`;
    if (hour < 17)        return `Xế chiều, ${f.name_vi} dằn bụng`;
    if (hour < 22)        return /lẩu|nướng|bbq/.test(t) ? `Tối nay quẩy bạn bè với ${f.name_vi}` : `Bữa tối: ${f.name_vi}`;
    return `Khuya rồi, ${f.name_vi} nhẹ bụng thôi`;
  }

  private moodReason(f: any, mood: string, themeReason: string): string {
    const t = (f.name_vi ?? '').toLowerCase();
    if (mood === 'sad' && /cháo|phở|chè/.test(t)) return `${f.name_vi} — món an ủi quốc dân`;
    if (mood === 'stress' && /lẩu|mì cay|nướng/.test(t)) return `${f.name_vi} — xả hết áp lực`;
    if (mood === 'late_night' && /cháo|mì|bánh mì|xôi/.test(t)) return `${f.name_vi} — đêm khuya nhẹ bụng`;
    if (mood === 'chill' && /cà phê|trà sữa|chè/.test(t)) return `${f.name_vi} — chill chill thôi`;
    return themeReason + ` → ${f.name_vi}`;
  }
}

function shuffle<T>(arr: T[]): T[] {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}
