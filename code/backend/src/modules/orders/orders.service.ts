import { Injectable, NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../../common/prisma/prisma.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import { AnalyticsService } from '../../common/analytics/analytics.service';

type OrderStatus = 'intent' | 'placed' | 'cooking' | 'picking' | 'delivering' | 'done' | 'cancelled';

const ALLOWED_STATUSES: OrderStatus[] = ['intent', 'placed', 'cooking', 'picking', 'delivering', 'done', 'cancelled'];

@Injectable()
export class OrdersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly realtime: RealtimeGateway,
    private readonly analytics: AnalyticsService,
  ) {}

  async createIntent(userId: string, dto: { foodId: string; restaurantId?: string; preferredPartner?: string }) {
    const food = await this.prisma.foods.findUnique({ where: { id: dto.foodId } });
    if (!food) throw new NotFoundException();

    let restaurant: { id: string; delivery_links: any } | null = null;
    if (dto.restaurantId) {
      const r = await this.prisma.restaurants.findUnique({
        where: { id: dto.restaurantId },
        select: { id: true, delivery_links: true },
      });
      restaurant = r;
    }
    if (!restaurant) {
      const item = await this.prisma.menu_items.findFirst({
        where: { food_id: dto.foodId, available: true },
        include: { restaurants: { select: { id: true, delivery_links: true } } },
      });
      if (!item?.restaurants) throw new NotFoundException('Không có quán phục vụ món này');
      restaurant = item.restaurants;
    }

    const links = (restaurant.delivery_links as Record<string, string>) ?? {};
    const partner = dto.preferredPartner && links[dto.preferredPartner]
      ? dto.preferredPartner
      : Object.keys(links)[0];

    if (!partner) throw new BadRequestException('Quán chưa có link đặt giao');

    const order = await this.prisma.orders.create({
      data: {
        user_id: userId,
        partner: partner as any,
        restaurant_id: restaurant.id,
        items: [{ foodId: dto.foodId }] as any,
        status: 'intent',
      },
    });

    this.analytics.track({
      event: 'order:intent',
      userId,
      properties: {
        orderId: order.id,
        foodId: dto.foodId,
        restaurantId: restaurant.id,
        partner,
        partnersAvailable: Object.keys(links).length,
      },
    });

    return {
      orderId: order.id,
      partner,
      deeplink: links[partner],
      alternates: Object.entries(links).map(([p, url]) => ({ partner: p, deeplink: url })),
    };
  }

  history(userId: string, page: number) {
    return this.prisma.orders.findMany({
      where: { user_id: userId },
      orderBy: { placed_at: 'desc' },
      take: 20,
      skip: (page - 1) * 20,
    });
  }

  async getOrder(userId: string, orderId: string) {
    const order = await this.prisma.orders.findUnique({ where: { id: orderId } });
    if (!order) throw new NotFoundException('Order not found');
    if (order.user_id !== userId) throw new ForbiddenException();
    return order;
  }

  /**
   * Transition an order to a new status and broadcast `order:update` to the
   * owner's user room over WebSocket.
   *
   * Audit #4: the previous version let a JWT-authed user mark THEIR OWN
   * order `done`, defeating fulfilment reconciliation. Now only:
   *   - actorRole === 'admin' (gated by @Roles('admin','support','super_admin'))
   *   - actorRole === 'partner' (HMAC-verified webhook in PartnersModule)
   * can mutate status. Anything else throws.
   *
   * Side-effects: sets {confirmed,delivered,cancelled}_at timestamp when the
   * status crosses that boundary.
   */
  async updateStatus(
    orderId: string,
    next: OrderStatus,
    opts?: { eta?: string; actorUserId?: string; actorRole?: 'admin' | 'partner' },
  ) {
    if (!ALLOWED_STATUSES.includes(next)) throw new BadRequestException('Invalid status');
    if (opts?.actorRole !== 'admin' && opts?.actorRole !== 'partner') {
      throw new ForbiddenException('Order status mutation requires admin or partner role');
    }
    const order = await this.prisma.orders.findUnique({ where: { id: orderId } });
    if (!order) throw new NotFoundException('Order not found');

    const data: Record<string, unknown> = { status: next };
    const now = new Date();
    if (next === 'cooking' && !order.confirmed_at) data.confirmed_at = now;
    if (next === 'done' && !order.delivered_at) data.delivered_at = now;
    if (next === 'cancelled' && !order.cancelled_at) data.cancelled_at = now;

    const updated = await this.prisma.orders.update({ where: { id: orderId }, data });

    if (updated.user_id) {
      await this.realtime.broadcastUser(updated.user_id, 'order:update', {
        orderId: updated.id,
        status: updated.status,
        eta: opts?.eta,
        partner: updated.partner,
        restaurantId: updated.restaurant_id,
        updatedAt: now.toISOString(),
      });
    }
    return updated;
  }
}
