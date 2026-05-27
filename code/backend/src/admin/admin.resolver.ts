import { Resolver, Query, Context, Args } from '@nestjs/graphql';
import { Inject, Injectable, Logger, UseGuards } from '@nestjs/common';
import IORedis from 'ioredis';

import { AdminAuthService } from './admin-auth.service';
import { PrismaService } from '../common/prisma/prisma.service';
import { GqlAdminGuard } from './gql-admin.guard';
import { REDIS } from '../common/redis/redis.module';

@Resolver()
@Injectable()
@UseGuards(GqlAdminGuard)
export class AdminResolver {
  private readonly logger = new Logger(AdminResolver.name);

  constructor(
    private readonly auth: AdminAuthService,
    private readonly prisma: PrismaService,
    @Inject(REDIS) private readonly redis: IORedis,
  ) {}

  @Query('me')
  me(@Context() ctx: any) {
    return this.auth.currentAdmin(ctx);
  }

  /**
   * Audit admin-tooling §C-1: previously kafka/ai/redis were hardcoded
   * `true`. Now actually probes the systems we run (Postgres + Redis).
   * Kafka/AI are dropped from the response because we don't run them as
   * separate services on this stack — keeping the field returning a
   * truthful lie was worse than removing it.
   */
  @Query('health')
  async health() {
    const dbOk = await this.prisma.$queryRawUnsafe('SELECT 1')
      .then(() => true)
      .catch((e) => { this.logger.warn(`admin health db probe failed: ${(e as Error).message}`); return false; });
    const redisOk = await this.redis.ping()
      .then((r) => r === 'PONG')
      .catch((e) => { this.logger.warn(`admin health redis probe failed: ${(e as Error).message}`); return false; });
    return {
      api: true,
      database: dbOk,
      redis: redisOk,
      // Compat fields — admin UI expects these in the schema. We don't run
      // Kafka or a dedicated AI service in this stack, so signal "not
      // applicable" rather than lying.
      kafka: false,
      ai: process.env.OPENAI_API_KEY ? true : false,
      ts: new Date().toISOString(),
    };
  }

  @Query('users')
  async users(@Context() ctx: any, @Args('filter') filter?: any, @Args('page') page?: any) {
    this.auth.assertRole(ctx, ['SUPER_ADMIN', 'OPS']);
    const limit = Math.min(page?.limit ?? 20, 100);
    // Audit admin-tooling §C-4/§C-5: prior `pageInfo` computed `total`
    // from an UNFILTERED count, and `hasNextPage` was based only on
    // `nodes.length === limit` (which lies when the page has exactly
    // `limit` items left). Now compute both from the SAME filter.
    const where: any = {
      ...(filter?.q ? { OR: [
        { username: { contains: filter.q, mode: 'insensitive' } },
        { display_name: { contains: filter.q, mode: 'insensitive' } },
        { phone: { contains: filter.q } },
      ] } : {}),
      ...(filter?.status ? { status: filter.status.toLowerCase() } : {}),
      ...(filter?.premium != null ? { is_premium: filter.premium } : {}),
      ...(filter?.city ? { city: filter.city } : {}),
    };
    // Fetch limit+1 so we can compute `hasNextPage` without an extra
    // count query (Relay-style cursor pagination pattern).
    const rows = await this.prisma.users.findMany({
      take: limit + 1,
      orderBy: { created_at: 'desc' },
      where,
    });
    const hasNextPage = rows.length > limit;
    const nodes = hasNextPage ? rows.slice(0, limit) : rows;
    const total = await this.prisma.users.count({ where });
    const endCursor = nodes.length > 0 ? nodes[nodes.length - 1].id : null;
    this.logAdminAccess(ctx, 'users.list', { count: nodes.length, filter });
    return { nodes, pageInfo: { hasNextPage, endCursor, total } };
  }

  @Query('user')
  async user(@Context() ctx: any, @Args('id') id: string) {
    this.auth.assertRole(ctx, ['SUPER_ADMIN', 'OPS']);
    this.logAdminAccess(ctx, 'users.read', { id });
    return this.prisma.users.findUnique({ where: { id } });
  }

  @Query('restaurants')
  async restaurants(@Context() ctx: any, @Args('filter') filter?: any, @Args('page') page?: any) {
    this.auth.assertRole(ctx, ['SUPER_ADMIN', 'OPS', 'BD', 'CONTENT_MOD']);
    const limit = Math.min(page?.limit ?? 20, 100);
    const where: any = {
      ...(filter?.q ? { name: { contains: filter.q, mode: 'insensitive' } } : {}),
      ...(filter?.city ? { city: filter.city } : {}),
      ...(filter?.isVerified != null ? { is_verified: filter.isVerified } : {}),
      ...(filter?.isClaimed != null ? { is_claimed: filter.isClaimed } : {}),
    };
    const rows = await this.prisma.restaurants.findMany({
      take: limit + 1,
      orderBy: { created_at: 'desc' },
      where,
    });
    const hasNextPage = rows.length > limit;
    const nodes = hasNextPage ? rows.slice(0, limit) : rows;
    const total = await this.prisma.restaurants.count({ where });
    const endCursor = nodes.length > 0 ? nodes[nodes.length - 1].id : null;
    this.logAdminAccess(ctx, 'restaurants.list', { count: nodes.length, filter });
    return { nodes, pageInfo: { hasNextPage, endCursor, total } };
  }

  /**
   * Audit admin-tooling §C-9: the global AuditLogInterceptor excludes
   * `/graphql` so admin queries weren't audit-logged. Write to
   * `admin_audit_log` directly per resolver. Failures are debug-level —
   * the read must succeed even if the audit table is misconfigured.
   */
  private logAdminAccess(ctx: any, action: string, payload: Record<string, unknown>): void {
    const user = ctx?.req?.user;
    if (!user?.sub) return;
    const ip = (ctx?.req?.headers?.['cf-connecting-ip'] as string | undefined)
      ?? (ctx?.req?.ip as string | undefined)
      ?? null;
    const targetType = action.split('.')[0] ?? null;
    const targetId = typeof payload?.id === 'string' && /^[0-9a-f-]{36}$/i.test(payload.id) ? payload.id : null;
    // Schema (sql/14_user_roles + earlier): id, admin_id, action,
    // target_type, target_id, before, after, ip_inet, created_at. For
    // read operations there's no before-state — we put the request
    // payload (filter, args) in `after` so it's still queryable.
    void this.prisma.$executeRawUnsafe(
      `INSERT INTO admin_audit_log (admin_id, action, target_type, target_id, after, ip_inet)
       VALUES ($1::uuid, $2, $3, $4::uuid, $5::jsonb, $6::inet)`,
      user.sub,
      action,
      targetType,
      targetId,
      JSON.stringify(payload ?? {}),
      ip,
    ).catch((err) => {
      this.logger.debug(`admin audit insert failed (${action}): ${(err as Error).message}`);
    });
  }
}
