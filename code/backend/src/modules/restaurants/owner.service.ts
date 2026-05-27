import {
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../common/prisma/prisma.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import {
  UpdateRestaurantDto,
  UpdateRestaurantLiveDto,
  UpsertMenuItemDto,
} from './dto/owner.dto';

/**
 * Owner-side restaurant management — closes audit hnag-audit-2026-05 §5 / §27.
 *
 * The "approved claim" contract is the authorization anchor: a restaurant
 * owner gains write access via the existing /v1/restaurants/:id/claim flow
 * (see claim.service.ts), which lands them in `restaurant_claims` with
 * `status='approved'`. Every owner-side method calls `assertOwner` first.
 *
 * The pattern is intentionally not "is_premium" or "JWT role" — those drift
 * out of sync with reality. The single source of truth is the row in
 * `restaurant_claims`.
 */
@Injectable()
export class OwnerService {
  private readonly logger = new Logger(OwnerService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly realtime: RealtimeGateway,
  ) {}

  // ─── Ownership check ────────────────────────────────────────────────────
  private async assertOwner(userId: string, restaurantId: string): Promise<void> {
    const claim = await this.prisma.restaurant_claims.findFirst({
      where: {
        restaurant_id: restaurantId,
        claimant_user_id: userId,
        status: 'approved',
      },
      select: { id: true },
    });
    if (!claim) {
      throw new ForbiddenException('Bạn không phải chủ quán này');
    }
  }

  async myRestaurants(userId: string) {
    const claims = await this.prisma.restaurant_claims.findMany({
      where: { claimant_user_id: userId, status: 'approved' },
      select: { restaurant_id: true },
    });
    const ids = claims.map((c) => c.restaurant_id).filter((id): id is string => !!id);
    if (!ids.length) return [];
    return this.prisma.restaurants.findMany({
      where: { id: { in: ids } },
      select: {
        id: true,
        name: true,
        address: true,
        cover_image: true,
        city: true,
        district: true,
        is_claimed: true,
        rating_avg: true,
        rating_count: true,
        status: true,
      },
    });
  }

  // ─── Detail ─────────────────────────────────────────────────────────────
  async detail(userId: string, restaurantId: string) {
    await this.assertOwner(userId, restaurantId);
    const [r, menuCount, live] = await Promise.all([
      this.prisma.restaurants.findUnique({ where: { id: restaurantId } }),
      this.prisma.menu_items.count({ where: { restaurant_id: restaurantId } }),
      this.prisma.restaurant_live.findUnique({ where: { restaurant_id: restaurantId } }).catch(() => null),
    ]);
    if (!r) throw new NotFoundException();
    return { restaurant: r, menuCount, live };
  }

  async updateRestaurant(userId: string, restaurantId: string, dto: UpdateRestaurantDto) {
    await this.assertOwner(userId, restaurantId);
    // Cast is safe — the DTO is the explicit allowlist and Prisma drops keys
    // not in the schema.
    const data: Record<string, unknown> = {};
    if (dto.name !== undefined) data.name = dto.name;
    if (dto.description !== undefined) data.description = dto.description;
    if (dto.address !== undefined) data.address = dto.address;
    if (dto.phone !== undefined) data.phone = dto.phone;
    if (dto.cover_image !== undefined) data.cover_image = dto.cover_image;
    if (dto.opening_hours !== undefined) data.opening_hours = dto.opening_hours as any;
    return this.prisma.restaurants.update({ where: { id: restaurantId }, data });
  }

  // ─── Live status ────────────────────────────────────────────────────────
  async setLive(userId: string, restaurantId: string, dto: UpdateRestaurantLiveDto) {
    await this.assertOwner(userId, restaurantId);
    const updated = await this.prisma.restaurant_live.upsert({
      where: { restaurant_id: restaurantId },
      update: {
        crowdedness: dto.crowdedness,
        wait_minutes: dto.wait_minutes ?? null,
        is_open: dto.is_open ?? undefined,
        updated_at: new Date(),
      },
      create: {
        restaurant_id: restaurantId,
        crowdedness: dto.crowdedness,
        wait_minutes: dto.wait_minutes ?? null,
        is_open: dto.is_open ?? true,
      },
    });
    // Push to anyone subscribed to this restaurant's room
    await this.realtime.broadcastRestaurant(restaurantId, 'restaurant:live', {
      crowdedness: updated.crowdedness,
      waitMinutes: updated.wait_minutes,
      isOpen: updated.is_open,
      at: new Date().toISOString(),
    });
    return updated;
  }

  // ─── Orders / Reviews ───────────────────────────────────────────────────
  async ordersLive(userId: string, restaurantId: string) {
    await this.assertOwner(userId, restaurantId);
    return this.prisma.orders.findMany({
      where: {
        restaurant_id: restaurantId,
        status: { notIn: ['done', 'cancelled'] },
      },
      orderBy: { placed_at: 'desc' },
      take: 50,
      select: {
        id: true,
        partner: true,
        items: true,
        status: true,
        placed_at: true,
        user_id: true,
      },
    });
  }

  async reviews(userId: string, restaurantId: string, page: number) {
    await this.assertOwner(userId, restaurantId);
    const limit = 20;
    return this.prisma.reviews.findMany({
      where: { restaurant_id: restaurantId },
      orderBy: { created_at: 'desc' },
      take: limit,
      skip: (page - 1) * limit,
    });
  }

  // ─── Menu CRUD ──────────────────────────────────────────────────────────
  async menu(userId: string, restaurantId: string) {
    await this.assertOwner(userId, restaurantId);
    return this.prisma.menu_items.findMany({
      where: { restaurant_id: restaurantId },
      orderBy: [{ position: 'asc' }, { created_at: 'asc' }],
    });
  }

  async upsertMenuItem(
    userId: string,
    restaurantId: string,
    itemId: string | null,
    dto: UpsertMenuItemDto,
  ) {
    await this.assertOwner(userId, restaurantId);
    if (itemId) {
      // Update: enforce that the item belongs to this restaurant.
      const existing = await this.prisma.menu_items.findUnique({ where: { id: itemId } });
      if (!existing || existing.restaurant_id !== restaurantId) {
        throw new NotFoundException('Menu item not found');
      }
      return this.prisma.menu_items.update({
        where: { id: itemId },
        data: {
          name: dto.name,
          description: dto.description ?? null,
          price_vnd: dto.price_vnd,
          image_url: dto.image_url ?? null,
          available: dto.available ?? true,
          position: dto.position ?? 0,
          food_id: dto.food_id ?? null,
        },
      });
    }
    return this.prisma.menu_items.create({
      data: {
        restaurant_id: restaurantId,
        name: dto.name,
        description: dto.description ?? null,
        price_vnd: dto.price_vnd,
        image_url: dto.image_url ?? null,
        available: dto.available ?? true,
        position: dto.position ?? 0,
        food_id: dto.food_id ?? null,
      },
    });
  }

  async deleteMenuItem(userId: string, restaurantId: string, itemId: string) {
    await this.assertOwner(userId, restaurantId);
    const existing = await this.prisma.menu_items.findUnique({ where: { id: itemId } });
    if (!existing || existing.restaurant_id !== restaurantId) {
      throw new NotFoundException('Menu item not found');
    }
    await this.prisma.menu_items.delete({ where: { id: itemId } });
    return { deleted: true };
  }
}
