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
    limit?: number;
  }) {
    // Audit #16: input validation — radius and limit are unbounded user input.
    if (!Number.isFinite(opts.lat) || !Number.isFinite(opts.lng)) {
      throw new Error('Invalid coordinates');
    }
    const radius = Math.min(Math.max(Math.round(opts.radius) || 1500, 100), 20000);
    const limit = Math.min(Math.max(Math.round(opts.limit ?? 50) || 50, 1), 100);
    const priceLevel = opts.priceLevel != null ? Math.round(opts.priceLevel) : undefined;
    // Audit #16: rewritten to use the GIST KNN <-> operator from sql/08
    // (`idx_restaurants_loc_active`). The partial index covers `status='active'`
    // — match the WHERE clause exactly so the planner uses it. ST_DWithin
    // still bounds the candidate set; <-> orders index-assisted nearest-first.
    return this.prisma.$queryRawUnsafe<any[]>(`
      WITH origin AS (
        SELECT ST_SetSRID(ST_MakePoint($1::float8, $2::float8), 4326)::geography AS g
      )
      SELECT
        r.id, r.name, r.slug, r.cover_image, r.address, r.city, r.district,
        r.price_level, r.rating_avg, r.rating_count, r.cuisine_tags, r.vibe_tags,
        ST_Y(r.location::geometry) AS lat, ST_X(r.location::geometry) AS lng,
        ROUND(ST_Distance(r.location, o.g)::numeric, 0)::int AS distance_m,
        rl.is_open, rl.crowdedness, rl.wait_minutes
      FROM restaurants r
      CROSS JOIN origin o
      LEFT JOIN restaurant_live rl ON rl.restaurant_id = r.id
      WHERE r.status = 'active'
        AND r.location IS NOT NULL
        AND ST_DWithin(r.location, o.g, $3::int)
        ${priceLevel ? 'AND r.price_level = $5::int' : ''}
      ORDER BY r.location <-> o.g
      LIMIT $4::int;
    `,
      opts.lng, opts.lat, radius, limit,
      ...(priceLevel ? [priceLevel] : []),
    );
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

    // Audit #35: prior code did `findFirst + create/update + aggregate +
    // update restaurants` non-atomically; two concurrent reviewers could
    // both read the same baseline and overwrite each other's aggregate.
    // Wrap in $transaction with explicit row lock on the restaurants row.
    return this.prisma.$transaction(async (tx) => {
      // Lock the restaurant row so the aggregate-then-write window is
      // serialised against any other reviewer touching the same restaurant.
      await tx.$executeRawUnsafe(
        `SELECT 1 FROM restaurants WHERE id = $1::uuid FOR UPDATE`,
        restaurantId,
      );
      const prev = await tx.reviews.findFirst({
        where: { user_id: userId, restaurant_id: restaurantId },
        select: { id: true },
      });
      const review = prev
        ? await tx.reviews.update({ where: { id: prev.id }, data })
        : await tx.reviews.create({ data: { ...data, user_id: userId, restaurant_id: restaurantId } });

      const agg = await tx.reviews.aggregate({
        where: { restaurant_id: restaurantId },
        _avg: { rating: true },
        _count: { _all: true },
      });
      const avg = agg._avg.rating ?? 0;
      const ratingAvg = Number((Number(avg).toFixed(2)));
      await tx.restaurants.update({
        where: { id: restaurantId },
        data: { rating_avg: ratingAvg, rating_count: agg._count._all },
      });

      return { ok: true, review, rating_avg: ratingAvg, rating_count: agg._count._all, updated: !!prev };
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
