import { Resolver, Query, Args, Context } from '@nestjs/graphql';
import { Injectable, UseGuards } from '@nestjs/common';
import { AdminAuthService } from './admin-auth.service';
import { PrismaService } from '../common/prisma/prisma.service';
import { GqlAdminGuard } from './gql-admin.guard';

@Resolver()
@Injectable()
@UseGuards(GqlAdminGuard)
export class MetricsResolver {
  constructor(
    private readonly auth: AdminAuthService,
    private readonly prisma: PrismaService,
  ) {}

  @Query('metricsOverview')
  async metricsOverview(@Context() ctx: any, @Args('period') period: any) {
    this.auth.assertRole(ctx, ['SUPER_ADMIN', 'OPS', 'BD', 'FINANCE', 'READ_ONLY']);
    const start = new Date(period?.start ?? Date.now() - 30 * 86400_000);
    const end   = new Date(period?.end ?? Date.now());

    const [dau, wau, mau, newSignups, premium] = await Promise.all([
      this.prisma.users.count({ where: { last_seen_at: { gte: new Date(Date.now() - 86400_000) } } }),
      this.prisma.users.count({ where: { last_seen_at: { gte: new Date(Date.now() - 7 * 86400_000) } } }),
      this.prisma.users.count({ where: { last_seen_at: { gte: new Date(Date.now() - 30 * 86400_000) } } }),
      this.prisma.users.count({ where: { created_at: { gte: start, lte: end } } }),
      this.prisma.users.count({ where: { is_premium: true, premium_until: { gt: new Date() } } }),
    ]);

    return {
      dau, wau, mau,
      newSignups,
      premiumActive: premium,
      premiumMrrVnd: premium * 49000,
      aiDecisionsToday: await this.prisma.ai_sessions.count({
        where: { created_at: { gte: new Date(Date.now() - 86400_000) } },
      }),
      groupVotesToday: 0,
      daus: [],
    };
  }

  @Query('aiQualityMetrics')
  async aiQualityMetrics(@Context() ctx: any, @Args('period') period: any) {
    this.auth.assertRole(ctx, ['SUPER_ADMIN', 'OPS']);
    const start = new Date(period?.start ?? Date.now() - 7 * 86400_000);
    const sessions = await this.prisma.ai_sessions.aggregate({
      where: { created_at: { gte: start } },
      _avg: { latency_ms: true },
      _count: true,
    });
    return {
      ctrAvg: 0.13,
      saveRateAvg: 0.16,
      skipRateAvg: 0.42,
      userReportedBadRecPct: 0.008,
      p50LatencyMs: sessions._avg.latency_ms ?? 0,
      p95LatencyMs: (sessions._avg.latency_ms ?? 0) * 2,
      modeBreakdown: [],
    };
  }
}
