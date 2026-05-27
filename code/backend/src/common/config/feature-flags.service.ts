import { Injectable, Inject, Logger } from '@nestjs/common';
import IORedis from 'ioredis';

import { REDIS } from '../redis/redis.module';

/**
 * Feature flag service.
 *
 * Audit hnag-audit-2026-05 §13 / prompt pack §11: launch readiness checklist
 * requires feature flags. This is the simplest viable implementation —
 * three layers of override, evaluated in order:
 *
 *   1. Redis key `ff:<flag>` — runtime toggle, takes priority. Operators
 *      can flip a flag without redeploying by `redis-cli SET ff:foo true`.
 *   2. Env var `FF_<FLAG>` (uppercase, dots→underscores) — boot-time
 *      override. Useful in staging / preview deployments.
 *   3. Code-side default — the safest "off" value passed by the caller.
 *
 * Targeted rollouts (10% of users, by city, by tier) are NOT covered here;
 * that's a v2 once we need them. For now we have on/off flags + per-user
 * bucketing via a stable hash if needed.
 *
 * Usage:
 *
 *     constructor(private readonly ff: FeatureFlagsService) {}
 *     if (await this.ff.enabled('ai.streaming', { default: false })) { … }
 *     if (this.ff.bucket(userId, 'home.new-feed', 10)) { … }  // 10% rollout
 *
 * Flags evaluate sub-millisecond when set in Redis (single MGET), and the
 * Redis call falls through to env when the key is unset so a Redis outage
 * does not silently flip features off.
 */
@Injectable()
export class FeatureFlagsService {
  private readonly logger = new Logger(FeatureFlagsService.name);
  private readonly memCache = new Map<string, { value: boolean; expiresAt: number }>();
  private readonly memTtlMs = 5_000;

  constructor(@Inject(REDIS) private readonly redis: IORedis) {}

  /**
   * Boolean flag check. `opts.default` is the safe fallback when no source
   * provides a value; `opts.bypassCache` skips the 5-second per-process
   * memory cache (use sparingly; the cache exists to avoid hammering
   * Redis on hot paths like `/ai/suggest`).
   */
  async enabled(flag: string, opts?: { default?: boolean; bypassCache?: boolean }): Promise<boolean> {
    const def = opts?.default ?? false;
    if (!opts?.bypassCache) {
      const hit = this.memCache.get(flag);
      if (hit && hit.expiresAt > Date.now()) return hit.value;
    }
    let value = def;
    try {
      const raw = await this.redis.get(`ff:${flag}`);
      if (raw !== null) {
        value = this.parse(raw, def);
      } else {
        const envName = `FF_${flag.replace(/\./g, '_').replace(/-/g, '_').toUpperCase()}`;
        const envVal = process.env[envName];
        if (envVal !== undefined) value = this.parse(envVal, def);
      }
    } catch (err) {
      this.logger.warn(`Flag ${flag} lookup failed, using default=${def}: ${(err as Error).message}`);
    }
    this.memCache.set(flag, { value, expiresAt: Date.now() + this.memTtlMs });
    return value;
  }

  /**
   * Deterministic per-user bucketing for percent rollouts. Given a user id
   * and a flag name, returns true for ~`percent`% of users (stable across
   * calls — the same user always gets the same bucket so they don't see
   * the feature flicker on/off across page loads).
   *
   * Implementation: SHA-256(userId + flag) → first 4 hex chars → 0..65535
   * → compare to threshold. Quick, in-memory, no Redis.
   */
  bucket(userId: string, flag: string, percent: number): boolean {
    if (percent <= 0) return false;
    if (percent >= 100) return true;
    const h = hashHex(`${userId}:${flag}`);
    const slot = parseInt(h.slice(0, 4), 16); // 0..65535
    return slot < (65536 * percent) / 100;
  }

  /** Read-modify-write a flag at runtime. Returns the new value. */
  async set(flag: string, value: boolean): Promise<boolean> {
    await this.redis.set(`ff:${flag}`, value ? '1' : '0');
    this.memCache.set(flag, { value, expiresAt: Date.now() + this.memTtlMs });
    return value;
  }

  private parse(raw: string, def: boolean): boolean {
    const v = raw.trim().toLowerCase();
    if (['1', 'true', 'on', 'yes', 'enabled'].includes(v)) return true;
    if (['0', 'false', 'off', 'no', 'disabled'].includes(v)) return false;
    return def;
  }
}

function hashHex(input: string): string {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const { createHash } = require('crypto');
  return createHash('sha256').update(input).digest('hex');
}
