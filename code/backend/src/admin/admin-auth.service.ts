import { Injectable, ForbiddenException } from '@nestjs/common';

export type AdminRole = 'SUPER_ADMIN' | 'OPS' | 'CONTENT_MOD' | 'BD' | 'FINANCE' | 'READ_ONLY';

@Injectable()
export class AdminAuthService {
  /**
   * Verify a GraphQL context has at least one of the required roles.
   * In production: read from JWT claims (custom admin token), not user token.
   */
  assertRole(ctx: any, allowed: AdminRole[]): void {
    const role: AdminRole | undefined = ctx?.req?.user?.adminRole;
    if (!role || !allowed.includes(role)) {
      throw new ForbiddenException('Insufficient admin role');
    }
  }

  currentAdmin(ctx: any): { id: string; email: string; role: AdminRole; name: string } {
    const u = ctx?.req?.user;
    if (!u?.adminRole) throw new ForbiddenException('Not an admin');
    return { id: u.sub, email: u.email, role: u.adminRole, name: u.name ?? u.email };
  }
}
