import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../common/prisma/prisma.service';

@Injectable()
export class RestaurantsService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Nearby search using PostGIS ST_DWithin.
   * Note: Prisma can't model PostGIS natively — use raw SQL.
   */
  async nearby(opts: {
    lat: number;
    lng: number;
    radius: number;        // meters
    openNow?: boolean;
    priceLevel?: number;
    cuisine?: string;
    minRating?: number;
  }) {
    const radius = Math.min(opts.radius, 20000);
    return this.prisma.$queryRawUnsafe<any[]>(`
      SELECT
        r.id, r.name, r.slug, r.cover_image, r.address, r.city, r.district,
        r.price_level, r.rating_avg, r.rating_count, r.cuisine_tags, r.vibe_tags,
        ST_Y(r.location::geometry) AS lat, ST_X(r.location::geometry) AS lng,
        ROUND(ST_Distance(r.location::geography, ST_GeogFromText($1)::geography)::numeric, 0)::int AS distance_m,
        rl.is_open, rl.crowdedness, rl.wait_minutes
      FROM restaurants r
      LEFT JOIN restaurant_live rl ON rl.restaurant_id = r.id
      WHERE r.status = 'active'
        AND ST_DWithin(r.location::geography, ST_GeogFromText($1)::geography, $2)
        ${opts.priceLevel ? 'AND r.price_level = $3' : ''}
      ORDER BY distance_m ASC
      LIMIT 50;
    `, `POINT(${opts.lng} ${opts.lat})`, radius, ...(opts.priceLevel ? [opts.priceLevel] : []));
  }

  async detail(id: string) {
    const r = await this.prisma.restaurants.findUnique({
      where: { id },
      include: {
        menu_items: { take: 20, orderBy: { position: 'asc' } },
        restaurant_live: true,
      },
    });
    if (!r) throw new NotFoundException();
    return r;
  }

  async menu(restaurantId: string) {
    return this.prisma.menu_items.findMany({
      where: { restaurant_id: restaurantId, available: true },
      orderBy: { position: 'asc' },
    });
  }

  /**
   * Submit (or update) a user's review for a restaurant, then recompute the
   * restaurant's real rating from all reviews. Ratings are 100% user-generated.
   * `pricePaidVnd` lets the price come from real diners too (not scraped).
   */
  async addReview(
    userId: string,
    restaurantId: string,
    dto: { rating: number; title?: string; content?: string; images?: string[]; pricePaidVnd?: number },
  ) {
    const rating = Math.min(Math.max(Math.round(Number(dto.rating) || 0), 1), 5);
    const exists = await this.prisma.restaurants.findUnique({ where: { id: restaurantId }, select: { id: true } });
    if (!exists) throw new NotFoundException('Quán không tồn tại');

    const data = {
      rating,
      title: dto.title?.slice(0, 120) ?? null,
      content: dto.content?.slice(0, 2000) ?? null,
      images: Array.isArray(dto.images) ? dto.images.slice(0, 8) : [],
      price_paid_vnd: dto.pricePaidVnd != null ? Math.max(0, Math.round(dto.pricePaidVnd)) : null,
    };

    // One review per user per restaurant: update if it already exists.
    const prev = await this.prisma.reviews.findFirst({
      where: { user_id: userId, restaurant_id: restaurantId },
      select: { id: true },
    });
    const review = prev
      ? await this.prisma.reviews.update({ where: { id: prev.id }, data })
      : await this.prisma.reviews.create({ data: { ...data, user_id: userId, restaurant_id: restaurantId } });

    const agg = await this.prisma.reviews.aggregate({
      where: { restaurant_id: restaurantId },
      _avg: { rating: true },
      _count: { _all: true },
    });
    const ratingAvg = Number((agg._avg.rating ?? 0).toFixed?.(2) ?? agg._avg.rating ?? 0);
    await this.prisma.restaurants.update({
      where: { id: restaurantId },
      data: { rating_avg: ratingAvg, rating_count: agg._count._all },
    });

    return { ok: true, review, rating_avg: ratingAvg, rating_count: agg._count._all, updated: !!prev };
  }

  async reviews(restaurantId: string, sort: 'recent' | 'helpful' | 'rating', page: number) {
    const orderBy =
      sort === 'helpful' ? { helpful_count: 'desc' as const } :
      sort === 'rating'  ? { rating: 'desc' as const } :
                           { created_at: 'desc' as const };
    return this.prisma.reviews.findMany({
      where: { restaurant_id: restaurantId },
      orderBy,
      take: 20,
      skip: (page - 1) * 20,
      include: { users: { select: { id: true, username: true, display_name: true, avatar_url: true } } },
    });
  }
}
