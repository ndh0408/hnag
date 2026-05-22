import { Resolver, Query, Mutation, Args, Context } from '@nestjs/graphql';
import { Injectable, UseGuards } from '@nestjs/common';
import { AdminAuthService } from './admin-auth.service';
import { PrismaService } from '../common/prisma/prisma.service';
import { GqlAdminGuard } from './gql-admin.guard';

@Resolver('RestaurantClaim')
@Injectable()
@UseGuards(GqlAdminGuard)
export class ClaimsResolver {
  constructor(
    private readonly auth: AdminAuthService,
    private readonly prisma: PrismaService,
  ) {}

  @Query('claims')
  async claims(@Context() ctx: any, @Args('filter') filter?: any, @Args('page') page?: any) {
    this.auth.assertRole(ctx, ['SUPER_ADMIN', 'OPS']);
    const limit = page?.limit ?? 20;
    const where: any = {};
    if (filter?.status) where.status = filter.status.toLowerCase();
    if (filter?.scoreMin != null) where.total_score = { gte: filter.scoreMin };

    const nodes = await this.prisma.restaurant_claims.findMany({
      take: limit,
      orderBy: { created_at: 'desc' },
      where,
    });
    return { nodes, pageInfo: { hasNextPage: nodes.length === limit, endCursor: null, total: nodes.length } };
  }

  @Mutation('approveClaim')
  async approveClaim(@Context() ctx: any, @Args('id') id: string, @Args('note') note?: string) {
    const admin = this.auth.currentAdmin(ctx);
    this.auth.assertRole(ctx, ['SUPER_ADMIN', 'OPS']);

    const claim = await this.prisma.restaurant_claims.update({
      where: { id },
      data: {
        status: 'approved',
        reviewed_by: admin.id,
        reviewed_at: new Date(),
        resolved_at: new Date(),
        notes: note,
      },
    });
    if (claim.restaurant_id && claim.claimant_user_id) {
      await this.prisma.restaurant_owners.upsert({
        where: { restaurant_id_user_id: { restaurant_id: claim.restaurant_id, user_id: claim.claimant_user_id } },
        update: { role: 'owner' },
        create: {
          restaurant_id: claim.restaurant_id, user_id: claim.claimant_user_id, role: 'owner',
          permissions: ['menu','photos','boost','live','reply'],
        },
      });
      await this.prisma.restaurants.update({
        where: { id: claim.restaurant_id },
        data: { is_claimed: true, is_verified: true, owner_user_id: claim.claimant_user_id },
      });
    }
    return claim;
  }

  @Mutation('rejectClaim')
  async rejectClaim(@Context() ctx: any, @Args('id') id: string, @Args('reason') reason: string) {
    const admin = this.auth.currentAdmin(ctx);
    this.auth.assertRole(ctx, ['SUPER_ADMIN', 'OPS']);
    return this.prisma.restaurant_claims.update({
      where: { id },
      data: {
        status: 'rejected',
        reviewed_by: admin.id,
        reviewed_at: new Date(),
        resolved_at: new Date(),
        notes: reason,
      },
    });
  }
}
