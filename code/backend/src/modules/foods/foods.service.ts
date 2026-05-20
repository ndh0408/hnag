import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../common/prisma/prisma.service';

@Injectable()
export class FoodsService {
  constructor(private readonly prisma: PrismaService) {}

  list(opts: { cuisine?: string; category?: string; q?: string; maxPrice?: number; page?: number; limit?: number }) {
    const limit = Math.min(opts.limit ?? 20, 50);
    const skip = ((opts.page ?? 1) - 1) * limit;
    return this.prisma.foods.findMany({
      where: {
        status: 'active',
        ...(opts.cuisine ? { cuisine: opts.cuisine } : {}),
        ...(opts.category ? { category: opts.category as any } : {}),
        ...(opts.q ? {
          OR: [
            { name_vi: { contains: opts.q, mode: 'insensitive' } },
            { name_en: { contains: opts.q, mode: 'insensitive' } },
            { slug:    { contains: opts.q.toLowerCase().replace(/\s+/g, '-') } },
          ],
        } : {}),
        ...(opts.maxPrice ? { avg_price_vnd: { lte: opts.maxPrice } } : {}),
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

  trending(city?: string, period: 'day' | 'week' | 'month' = 'week') {
    // Simplified — sort by trending_score
    return this.prisma.foods.findMany({
      where: { status: 'active' },
      orderBy: { trending_score: 'desc' },
      take: 20,
    });
  }
}
