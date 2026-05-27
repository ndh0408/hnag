import { CanActivate, ExecutionContext, ForbiddenException, Injectable, Logger, SetMetadata, applyDecorators, UseGuards } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AuthGuard } from '@nestjs/passport';

import { PrismaService } from '../prisma/prisma.service';

/**
 * Server-side Premium gate.
 *
 * Audit hnag-audit-2026-05 §B-Premium / §8 (HIGH): the JWT `isPremium` claim
 * is up to 15 minutes stale (access-token lifetime). Routes that gate
 * paid features MUST re-check the source of truth — `users.is_premium`
 * AND `users.premium_until > now()` — at the moment of the call. Otherwise:
 *
 *   - a user whose subscription expired 14 minutes ago still has a valid
 *     access token claiming premium for the next ~1 minute
 *   - a user we *just* activated needs to refresh their token to see the
 *     entitlement
 *
 * Both are easy to write the wrong way in code review, so we centralize
 * the policy here. Annotate any controller method with `@Premium()`:
 *
 *     @Premium()
 *     @Post('ai/decide/voice')
 *     voice(@CurrentUser() u: JwtPayload) { ... }
 *
 * `@Premium()` is composed: it pulls in `AuthGuard('jwt')`, sets the metadata
 * the guard reads, and applies the guard — one decorator, the whole chain.
 *
 * The guard tolerates network/db blips with a *fail-closed* policy: if the
 * lookup throws, the request is denied (better a paying customer sees an
 * intermittent 403 than a free user gets premium features for free).
 */

const PREMIUM_META = 'requiresPremium';

@Injectable()
export class PremiumGuard implements CanActivate {
  private readonly logger = new Logger(PremiumGuard.name);

  constructor(
    private readonly reflector: Reflector,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const requires = this.reflector.getAllAndOverride<boolean>(PREMIUM_META, [
      ctx.getHandler(),
      ctx.getClass(),
    ]);
    if (!requires) return true;

    const req = ctx.switchToHttp().getRequest();
    const userId: string | undefined = req.user?.sub;
    if (!userId) throw new ForbiddenException('Cần đăng nhập');

    try {
      const u = await this.prisma.users.findUnique({
        where: { id: userId },
        select: { is_premium: true, premium_until: true, status: true },
      });
      if (!u || u.status === 'deleted') throw new ForbiddenException('Tài khoản không tồn tại');
      if (!u.is_premium) throw new ForbiddenException('Cần HNAG+ để dùng tính năng này');
      if (u.premium_until && u.premium_until.getTime() < Date.now()) {
        // Soft-expire: the schedule cron should flip is_premium → false but
        // until it does, we deny in real time so users can't squat on lapsed
        // subscriptions.
        throw new ForbiddenException('Gói HNAG+ của bạn đã hết hạn');
      }
      return true;
    } catch (err) {
      if (err instanceof ForbiddenException) throw err;
      this.logger.error(`Premium check failed for ${userId}: ${(err as Error).message}`);
      // Fail closed (audit §10 — never grant access on infra blip).
      throw new ForbiddenException('Không xác minh được quyền HNAG+ ngay lúc này');
    }
  }
}

/**
 * Composite decorator: ensures the request is JWT-authenticated AND the
 * resolved user currently has an active Premium subscription. Use on
 * controller methods that gate paid features.
 */
export function Premium(): MethodDecorator & ClassDecorator {
  return applyDecorators(
    SetMetadata(PREMIUM_META, true),
    UseGuards(AuthGuard('jwt'), PremiumGuard),
  );
}
