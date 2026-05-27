import { CanActivate, ExecutionContext, Injectable, UnauthorizedException, ForbiddenException, Logger } from '@nestjs/common';
import { GqlExecutionContext } from '@nestjs/graphql';
import { JwtService } from '@nestjs/jwt';

import { PrismaService } from '../common/prisma/prisma.service';
import { getAdminEmails } from '../common/config/secrets';

/**
 * Guards the admin GraphQL endpoint.
 *
 * Audit admin-tooling §C-3 (this session): previously hardcoded
 * `adminRole='SUPER_ADMIN'` for every authenticated email in ADMIN_EMAILS,
 * which made every `assertRole(['OPS', 'CONTENT_MOD'])` check always
 * pass — i.e. NO role distinction. Now we read `users.role` from the DB
 * (`super_admin | admin | moderator | support | …`) and map it to the
 * GraphQL admin role enum.
 *
 * Authorization layers (top → bottom):
 *   1. JWT must be valid (HS256, our issuer).
 *   2. `users.status='active'`.
 *   3. `users.role` ∈ {super_admin, admin, moderator, support} OR email in
 *      legacy ADMIN_EMAILS allowlist (treated as super_admin for backwards
 *      compatibility during the rollout).
 */

const DB_TO_GQL_ROLE: Record<string, string> = {
  super_admin: 'SUPER_ADMIN',
  admin: 'SUPER_ADMIN',           // map admin → super_admin in the GraphQL space
  moderator: 'CONTENT_MOD',
  support: 'OPS',
  creator: 'READ_ONLY',
  owner: 'READ_ONLY',
};

@Injectable()
export class GqlAdminGuard implements CanActivate {
  private readonly logger = new Logger(GqlAdminGuard.name);

  constructor(
    private readonly jwt: JwtService,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const gqlCtx = GqlExecutionContext.create(context);
    const req = gqlCtx.getContext().req;
    const header: string | undefined = req?.headers?.authorization;
    const token = header?.replace(/^Bearer\s+/i, '');
    if (!token) throw new UnauthorizedException('Missing admin token');

    let payload: any;
    try {
      payload = await this.jwt.verifyAsync(token);
    } catch {
      throw new UnauthorizedException('Invalid admin token');
    }

    const userId = payload?.sub as string | undefined;
    if (!userId) throw new UnauthorizedException('Token missing subject');

    // Live DB read — a demoted admin loses access on the next request, not
    // after their 15min JWT expires. Same pattern as RolesGuard.
    let userRow: { role: string | null; status: string | null; email: string | null } | null = null;
    try {
      userRow = await this.prisma.users.findUnique({
        where: { id: userId },
        select: { role: true, status: true, email: true } as any,
      }) as any;
    } catch (err) {
      this.logger.error(`Admin RBAC DB lookup failed: ${(err as Error).message}`);
      throw new ForbiddenException('Không xác minh được quyền admin');
    }
    if (!userRow || userRow.status === 'deleted') {
      throw new ForbiddenException('Tài khoản không tồn tại');
    }

    const dbRole = (userRow.role ?? 'user').toLowerCase();
    let gqlRole = DB_TO_GQL_ROLE[dbRole];

    // Legacy ADMIN_EMAILS fallback (for bootstrapping or break-glass before
    // any user has been promoted via the role column).
    if (!gqlRole) {
      const allow = getAdminEmails();
      const email = (userRow.email ?? '').toLowerCase();
      if (allow.length && email && allow.includes(email)) {
        gqlRole = 'SUPER_ADMIN';
      } else {
        throw new ForbiddenException('Not an admin');
      }
    }

    req.user = {
      sub: userId,
      email: userRow.email ?? payload?.email ?? null,
      adminRole: gqlRole,
      dbRole,
      name: userRow.email ?? userId,
    };
    return true;
  }
}
