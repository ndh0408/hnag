import { CanActivate, ExecutionContext, ForbiddenException, Injectable, Logger } from '@nestjs/common';
import { Reflector } from '@nestjs/core';

import { PrismaService } from '../prisma/prisma.service';
import { ROLES_KEY, UserRole } from '../decorators/roles.decorator';

/**
 * Role-Based Access Control guard.
 *
 * Audit prompt-pack §7 ("RBAC đầy đủ"): the previous admin gate was an
 * env-var email whitelist that only worked for the GraphQL admin
 * endpoint and didn't support intermediate roles (owner, support,
 * moderator). This guard reads the `users.role` column live on every
 * request and matches against the `@Roles(...)` metadata.
 *
 * Authorization hierarchy (subset relation):
 *   user < owner / creator / moderator / support < admin < super_admin
 *
 * Implementation choices:
 *   - The role is re-read from DB on every request, not trusted from the
 *     JWT. This means a demoted admin loses access immediately on the
 *     next request — no need to wait for their 15-minute access token
 *     to expire. The cost is one extra `users.role` SELECT per guarded
 *     call; this is OK because admin routes are rare per-second.
 *   - On any infra error (DB down, user row missing) the guard FAILS
 *     CLOSED — better a paying admin gets a 403 they can retry than a
 *     malicious user slips through during a DB blip.
 *   - `super_admin` always passes regardless of the `@Roles(...)` list.
 *     `admin` is automatically granted if `@Roles('moderator' | 'support')`
 *     is required (admin is a superset).
 */
@Injectable()
export class RolesGuard implements CanActivate {
  private readonly logger = new Logger(RolesGuard.name);

  constructor(
    private readonly reflector: Reflector,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const required = this.reflector.getAllAndOverride<UserRole[]>(ROLES_KEY, [
      ctx.getHandler(),
      ctx.getClass(),
    ]);
    if (!required || required.length === 0) return true;

    const req = ctx.switchToHttp().getRequest();
    const userId: string | undefined = req.user?.sub;
    if (!userId) throw new ForbiddenException('Cần đăng nhập');

    try {
      const u = await this.prisma.users.findUnique({
        where: { id: userId },
        select: { role: true, status: true } as any,
      });
      if (!u || (u as any).status === 'deleted') {
        throw new ForbiddenException('Tài khoản không tồn tại');
      }
      const role = ((u as any).role ?? 'user') as UserRole;

      // Stash the resolved role on the request for downstream use (audit
      // log, fine-grained per-record checks).
      (req as any).userRole = role;

      if (this.matches(role, required)) return true;
      this.logger.warn(`RBAC deny: user=${userId} role=${role} required=${required.join('|')}`);
      throw new ForbiddenException('Không đủ quyền');
    } catch (err) {
      if (err instanceof ForbiddenException) throw err;
      this.logger.error(`RBAC check failed for ${userId}: ${(err as Error).message}`);
      throw new ForbiddenException('Không xác minh được quyền');
    }
  }

  private matches(role: UserRole, required: UserRole[]): boolean {
    if (role === 'super_admin') return true;
    if (required.includes(role)) return true;
    // admin is a superset of moderator/support/owner/creator. If any of
    // those is required, admin satisfies it.
    if (role === 'admin') {
      return required.some((r) => ['admin', 'owner', 'creator', 'moderator', 'support'].includes(r));
    }
    return false;
  }
}
