import { Injectable, ForbiddenException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../common/prisma/prisma.service';

export const BOOST_PRODUCTS = {
  featured_pin:        { name: 'Featured Pin (map)',     price_vnd_per_week: 200_000 },
  trending_boost:      { name: 'Trending Boost',          price_vnd_per_week: 500_000 },
  ai_suggestion_boost: { name: 'AI Suggestion Boost',     price_vnd_per_week: 800_000 },
  sponsored_card:      { name: 'Sponsored Card (CPM)',    price_vnd_per_1k_impr: 80_000 },
  story_ad:            { name: 'Story Ad',                price_vnd_per_1k_views: 1_200_000 },
  verified_plus:       { name: 'Verified Plus (monthly)', price_vnd_per_month: 199_000 },
} as const;

export type BoostProductId = keyof typeof BOOST_PRODUCTS;

@Injectable()
export class BoostService {
  constructor(private readonly prisma: PrismaService) {}

  listProducts() {
    return Object.entries(BOOST_PRODUCTS).map(([id, p]) => ({ id, ...p }));
  }

  async createCampaign(userId: string, restaurantId: string, product: BoostProductId, durationDays: number, paymentRef?: string) {
    await this.assertOwner(userId, restaurantId);
    const def = BOOST_PRODUCTS[product];
    if (!def) throw new NotFoundException('Unknown boost product');

    const until = new Date(Date.now() + durationDays * 86_400_000);

    // Persist as raw boost campaign — for skeleton uses ai_sessions-like generic table.
    // Production: dedicated boost_campaigns table. Here we update restaurants.is_sponsored.
    if (product === 'featured_pin' || product === 'trending_boost' || product === 'ai_suggestion_boost' || product === 'verified_plus') {
      await this.prisma.restaurants.update({
        where: { id: restaurantId },
        data: { is_sponsored: true, sponsor_until: until },
      });
    }

    const priceVnd = this.estimatePrice(product, durationDays);
    return {
      restaurant_id: restaurantId,
      product,
      duration_days: durationDays,
      until,
      price_vnd: priceVnd,
      payment_ref: paymentRef,
      status: 'active',
    };
  }

  async myCampaigns(userId: string) {
    const owned = await this.prisma.restaurant_owners.findMany({
      where: { user_id: userId },
      include: { restaurants: true },
    });
    return owned
      .filter((o) => o.restaurants && o.restaurants.is_sponsored && o.restaurants.sponsor_until && o.restaurants.sponsor_until > new Date())
      .map((o) => ({
        restaurant_id: o.restaurant_id,
        restaurant_name: o.restaurants!.name,
        active_until: o.restaurants!.sponsor_until,
      }));
  }

  async cancel(userId: string, restaurantId: string) {
    await this.assertOwner(userId, restaurantId);
    return this.prisma.restaurants.update({
      where: { id: restaurantId },
      data: { is_sponsored: false, sponsor_until: null },
    });
  }

  // ─── helpers ─────────────────────────────────────────────────────

  private async assertOwner(userId: string, restaurantId: string) {
    const owner = await this.prisma.restaurant_owners.findUnique({
      where: { restaurant_id_user_id: { restaurant_id: restaurantId, user_id: userId } },
    });
    if (!owner) throw new ForbiddenException('Bạn không phải owner quán này');
  }

  private estimatePrice(product: BoostProductId, durationDays: number): number {
    const p = BOOST_PRODUCTS[product] as any;
    if (p.price_vnd_per_week)  return Math.ceil(durationDays / 7) * p.price_vnd_per_week;
    if (p.price_vnd_per_month) return Math.ceil(durationDays / 30) * p.price_vnd_per_month;
    return 0; // CPM/views billed separately
  }
}
