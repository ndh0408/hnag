import { Resolver, Query, Context, Args } from '@nestjs/graphql';
import { Injectable, UseGuards } from '@nestjs/common';
import { AdminAuthService } from './admin-auth.service';
import { PrismaService } from '../common/prisma/prisma.service';
import { GqlAdminGuard } from './gql-admin.guard';

@Resolver()
@Injectable()
@UseGuards(GqlAdminGuard)
export class AdminResolver {
  constructor(
    private readonly auth: AdminAuthService,
    private readonly prisma: PrismaService,
  ) {}

  @Query('me')
  me(@Context() ctx: any) {
    return this.auth.currentAdmin(ctx);
  }

  @Query('health')
  async health() {
    const dbOk = await this.prisma.$queryRawUnsafe('SELECT 1').then(() => true).catch(() => false);
    return {
      api: true,
      database: dbOk,
      redis: true,    // wire up actual check
      kafka: true,
      ai: true,
      ts: new Date().toISOString(),
    };
  }

  @Query('users')
  async users(@Context() ctx: any, @Args('filter') filter?: any, @Args('page') page?: any) {
    this.auth.assertRole(ctx, ['SUPER_ADMIN', 'OPS']);
    const limit = page?.limit ?? 20;
    const nodes = await this.prisma.users.findMany({
      take: limit,
      orderBy: { created_at: 'desc' },
      where: {
        ...(filter?.q ? { OR: [
          { username: { contains: filter.q, mode: 'insensitive' } },
          { display_name: { contains: filter.q, mode: 'insensitive' } },
          { phone: { contains: filter.q } },
        ] } : {}),
        ...(filter?.status ? { status: filter.status.toLowerCase() } : {}),
        ...(filter?.premium != null ? { is_premium: filter.premium } : {}),
        ...(filter?.city ? { city: filter.city } : {}),
      },
    });
    const total = await this.prisma.users.count();
    return { nodes, pageInfo: { hasNextPage: nodes.length === limit, endCursor: null, total } };
  }

  @Query('user')
  async user(@Context() ctx: any, @Args('id') id: string) {
    this.auth.assertRole(ctx, ['SUPER_ADMIN', 'OPS']);
    return this.prisma.users.findUnique({ where: { id } });
  }

  @Query('restaurants')
  async restaurants(@Context() ctx: any, @Args('filter') filter?: any, @Args('page') page?: any) {
    this.auth.assertRole(ctx, ['SUPER_ADMIN', 'OPS', 'BD', 'CONTENT_MOD']);
    const limit = page?.limit ?? 20;
    const nodes = await this.prisma.restaurants.findMany({
      take: limit,
      orderBy: { created_at: 'desc' },
      where: {
        ...(filter?.q ? { name: { contains: filter.q, mode: 'insensitive' } } : {}),
        ...(filter?.city ? { city: filter.city } : {}),
        ...(filter?.isVerified != null ? { is_verified: filter.isVerified } : {}),
        ...(filter?.isClaimed != null ? { is_claimed: filter.isClaimed } : {}),
      },
    });
    return { nodes, pageInfo: { hasNextPage: nodes.length === limit, endCursor: null, total: nodes.length } };
  }
}
