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
