import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../common/prisma/prisma.service';

@Injectable()
export class OrdersService {
  constructor(private readonly prisma: PrismaService) {}

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
      // Find a nearby restaurant serving this food (skeleton picks first menu match)
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
}
