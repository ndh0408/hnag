import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../common/prisma/prisma.service';

/**
 * Audit #25: search used `name_vi ILIKE '%q%'` which is a sequential scan
 * once the catalogue grows past a few thousand foods. sql/08_hardening.sql
 * created a stored tsvector + GIN index (`idx_foods_search_tsv`) over
 * unaccented `name_vi + name_en + cuisine + description`. Wire it.
 */
@Injectable()
export class FoodsService {
  constructor(private readonly prisma: PrismaService) {}

  async list(opts: { cuisine?: string; category?: string; q?: string; maxPrice?: number; page?: number; limit?: number }) {
    const limit = Math.min(Math.max(opts.limit ?? 20, 1), 50);
    const skip = (Math.max(opts.page ?? 1, 1) - 1) * limit;

    // Free-text search via the prebuilt tsvector. We use websearch_to_tsquery
    // so users can write natural phrases ("phở bò gân"), and unaccent so
    // "pho" matches "phở". The dictionary 'simple' is used by the stored
    // generated column too.
    if (opts.q && opts.q.trim().length > 0) {
      // Tag-style filters still need explicit ANDs.
      const conditions: string[] = [];
      const params: any[] = [];
      const push = (clause: string, value: any) => {
        params.push(value);
        conditions.push(clause.replace('$$', `$${params.length}`));
      };
      push(`f.search_tsv @@ websearch_to_tsquery('simple', f_unaccent($$))`, opts.q.trim());
      if (opts.cuisine) push(`f.cuisine = $$`, opts.cuisine);
      if (opts.category) push(`f.category = $$`, opts.category);
      if (opts.maxPrice) push(`f.avg_price_vnd <= $$::int`, Math.max(0, Math.round(opts.maxPrice)));
      const where = `f.status = 'active' AND ${conditions.join(' AND ')}`;
      const sql = `
        SELECT f.*,
               ts_rank(f.search_tsv, websearch_to_tsquery('simple', f_unaccent($1))) AS _rank
        FROM foods f
        WHERE ${where}
        ORDER BY _rank DESC, f.trending_score DESC, f.popularity DESC
        LIMIT $${params.length + 1}::int OFFSET $${params.length + 2}::int
      `;
      return this.prisma.$queryRawUnsafe<any[]>(sql, ...params, limit, skip);
    }

    return this.prisma.foods.findMany({
      where: {
        status: 'active',
        ...(opts.cuisine ? { cuisine: opts.cuisine } : {}),
        ...(opts.category ? { category: opts.category as any } : {}),
        ...(opts.maxPrice ? { avg_price_vnd: { lte: Math.max(0, Math.round(opts.maxPrice)) } } : {}),
      },
      orderBy: [{ trending_score: 'desc' }, { popularity: 'desc' }],
      take: limit,
      skip,
    });
  }

  async detail(id: string) {
    const f = await this.prisma.foods.findUnique({ where: { id } });
    if (!f) throw new NotFoundException();
    return f;
  }

  async restaurantsServing(foodId: string) {
    const items = await this.prisma.menu_items.findMany({
      where: { food_id: foodId },
      select: { restaurant_id: true, price_vnd: true, is_signature: true },
    });
    if (items.length === 0) return [];
    const ids = items.map((i) => i.restaurant_id).filter(Boolean) as string[];
    const restaurants = await this.prisma.restaurants.findMany({
      where: { id: { in: ids }, status: 'active' },
    });
    const priceById = new Map(items.map((i) => [i.restaurant_id, i.price_vnd]));
    const sigById = new Map(items.map((i) => [i.restaurant_id, i.is_signature]));
    return restaurants.map((r) => ({
      ...r,
      _menu_price_vnd: priceById.get(r.id) ?? null,
      _is_signature: sigById.get(r.id) ?? false,
    }));
  }

  trending(_city?: string, _period: 'day' | 'week' | 'month' = 'week') {
    return this.prisma.foods.findMany({
      where: { status: 'active' },
      orderBy: { trending_score: 'desc' },
      take: 20,
    });
  }
}
