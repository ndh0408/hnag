import { CanActivate, ExecutionContext, Injectable, UnauthorizedException, ForbiddenException } from '@nestjs/common';
import { GqlExecutionContext } from '@nestjs/graphql';
import { JwtService } from '@nestjs/jwt';
import { getAdminEmails } from '../common/config/secrets';

/**
 * Guards the admin GraphQL endpoint.
 *
 * The previous implementation never populated `req.user`, so the `@auth`
 * directives + `assertRole()` were entirely non-functional (and the endpoint was
 * publicly reachable). This guard verifies the bearer JWT, checks the caller's
 * email against the ADMIN_EMAILS allowlist, and attaches an `adminRole` so the
 * existing role checks work.
 */
@Injectable()
export class GqlAdminGuard implements CanActivate {
  constructor(private readonly jwt: JwtService) {}

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

    const allow = getAdminEmails();
    const email = (payload?.email ?? '').toLowerCase();
    if (!allow.length || !email || !allow.includes(email)) {
      throw new ForbiddenException('Not an admin');
    }

    // Populate the context the resolvers/AdminAuthService expect.
    req.user = { sub: payload.sub, email, adminRole: 'SUPER_ADMIN', name: email };
    return true;
  }
}
