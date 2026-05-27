import {
  CanActivate,
  ExecutionContext,
  HttpException,
  HttpStatus,
  Inject,
  Injectable,
  Logger,
  SetMetadata,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import IORedis from 'ioredis';

import { REDIS } from '../redis/redis.module';

const COOLDOWN_KEY = 'aiCooldownMs';

/**
 * Class-method decorator that gates a route behind a short per-user
 * cooldown.
 *
 * Why this exists (audit production-killer §9 "AI cost protection /
 * cooldown"): the rate-limiter at the route level lets users hammer
 * `/v1/ai/suggest` up to 30/minute. That's fine for legitimate use, but
 * a misbehaving client (mash refresh, double-tap, stuck loop) can:
 *   - burn through the per-user daily LLM budget in 30 seconds
 *   - cause unbounded Redis writes (suggest cache key per context-hash)
 *   - generate analytics noise that pollutes retention dashboards
 *
 * Solution: a tight 2-second debounce keyed on `cooldown:ai:<userId>`.
 * The first call within the window wins; subsequent calls get 429 with
 * a `Retry-After` header so the client knows when to retry.
 *
 * Used as `@AiCooldown(2000)` — argument is the window in ms.
 */
export const AiCooldown = (cooldownMs: number) => SetMetadata(COOLDOWN_KEY, cooldownMs);

@Injectable()
export class AiCooldownGuard implements CanActivate {
  private readonly logger = new Logger(AiCooldownGuard.name);

  constructor(
    private readonly reflector: Reflector,
    @Inject(REDIS) private readonly redis: IORedis,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const cooldownMs = this.reflector.getAllAndOverride<number>(COOLDOWN_KEY, [
      ctx.getHandler(),
      ctx.getClass(),
    ]);
    if (!cooldownMs) return true;

    const req = ctx.switchToHttp().getRequest();
    const userId: string | undefined = req.user?.sub;
    if (!userId) return true; // unauthenticated routes don't get cooldown — auth guards block first

    const cooldownSec = Math.max(1, Math.ceil(cooldownMs / 1000));
    const key = `cooldown:ai:${userId}`;
    // SET NX EX = atomic "claim slot if free". The `set` resolves to 'OK'
    // when the slot is acquired and `null` when another call is in the
    // window — we treat that as the cooldown hit.
    const acquired = await this.redis.set(key, '1', 'EX', cooldownSec, 'NX');
    if (acquired === 'OK') return true;

    // Cooldown hit. Surface the precise remaining TTL so the client can
    // back off intelligently instead of polling.
    let remaining = 0;
    try {
      remaining = Math.max(0, await this.redis.pttl(key));
    } catch {/* best-effort */}

    const retryAfterSec = Math.max(1, Math.ceil(remaining / 1000));
    const res = ctx.switchToHttp().getResponse();
    if (res?.setHeader) res.setHeader('Retry-After', String(retryAfterSec));

    throw new HttpException(
      {
        code: 'AI_COOLDOWN',
        message: 'Hà cần thở chút — vui lòng thử lại sau vài giây.',
        retryAfterMs: remaining,
      },
      HttpStatus.TOO_MANY_REQUESTS,
    );
  }
}
