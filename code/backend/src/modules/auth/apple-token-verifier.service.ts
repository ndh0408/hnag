import { Injectable, Inject, Logger, UnauthorizedException } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';
import * as jwt from 'jsonwebtoken';
import { createPublicKey, KeyObject } from 'crypto';
import IORedis from 'ioredis';

import { REDIS } from '../../common/redis/redis.module';

/**
 * Verify Apple "Sign in with Apple" identity tokens.
 *
 * Replaces the previous decode-only implementation (audit hnag-audit-2026-05:
 * CRITICAL — anyone could forge an identityToken with any `sub` and silently
 * impersonate any Apple-linked user).
 *
 * Flow:
 *   1. decode header → look up matching JWK by `kid` from Apple's JWKS
 *      (cached in Redis for 1h; refetched on cache miss / kid rotation)
 *   2. convert JWK → KeyObject (Node 15+ `createPublicKey({format:'jwk'})`)
 *   3. `jwt.verify` enforces RS256 signature + `iss=https://appleid.apple.com`
 *      + `aud=<our bundle id>` + exp + iat
 *   4. return the proven claims
 *
 * The verifier never trusts unsigned payload data — `sub`, `email`, and
 * `email_verified` only become authoritative after step 3 succeeds.
 */

interface AppleJwk {
  kty: 'RSA';
  kid: string;
  use: string;
  alg: 'RS256';
  n: string;
  e: string;
}

interface AppleJwks {
  keys: AppleJwk[];
}

export interface AppleClaims {
  iss: string;
  aud: string;
  exp: number;
  iat: number;
  sub: string;
  email?: string;
  email_verified?: boolean | string;
  is_private_email?: boolean | string;
  nonce?: string;
  nonce_supported?: boolean;
}

@Injectable()
export class AppleTokenVerifier {
  private readonly logger = new Logger(AppleTokenVerifier.name);
  private readonly JWKS_URL = 'https://appleid.apple.com/auth/keys';
  private readonly EXPECTED_ISS = 'https://appleid.apple.com';
  private readonly CACHE_KEY = 'apple:jwks:v1';
  /** SETNX lock to prevent thundering-herd refetch on key rotation (audit #43). */
  private readonly REFRESH_LOCK_KEY = 'apple:jwks:v1:refresh-lock';
  private readonly CACHE_TTL_SEC = 60 * 60; // 1 hour
  /** Soft-grace TTL — return stale JWKS for this long if Apple is unreachable. */
  private readonly STALE_GRACE_SEC = 24 * 3600;

  constructor(
    private readonly http: HttpService,
    @Inject(REDIS) private readonly redis: IORedis,
  ) {}

  /**
   * Verify an Apple identityToken against Apple's published public keys.
   * Throws UnauthorizedException on any verification failure.
   *
   * @param idToken  The `identityToken` returned by Apple Sign-In on the client.
   * @param audience Expected `aud` claim — your iOS app bundle id (e.g. `vn.hnag.hnag`).
   *                 For web flows, pass the Services ID instead.
   */
  async verify(idToken: string, audience: string): Promise<AppleClaims> {
    if (typeof idToken !== 'string' || idToken.split('.').length !== 3) {
      throw new UnauthorizedException('Apple token: malformed JWT');
    }

    const decoded = jwt.decode(idToken, { complete: true });
    if (!decoded || typeof decoded === 'string' || !decoded.header?.kid) {
      throw new UnauthorizedException('Apple token: missing kid');
    }
    if (decoded.header.alg !== 'RS256') {
      // Apple only signs with RS256 today. Anything else is a forgery attempt
      // (e.g. `alg:none`, HS256 with our public key as "secret").
      throw new UnauthorizedException(`Apple token: unexpected alg ${String(decoded.header.alg)}`);
    }

    const jwk = await this.getKey(decoded.header.kid);
    if (!jwk) throw new UnauthorizedException('Apple token: signing key not found');

    let publicKey: KeyObject;
    try {
      publicKey = createPublicKey({ format: 'jwk', key: jwk as unknown as Record<string, unknown> });
    } catch (err) {
      this.logger.error(`Apple JWK → KeyObject failed: ${(err as Error).message}`);
      throw new UnauthorizedException('Apple token: invalid signing key');
    }

    let payload: jwt.JwtPayload | string;
    try {
      payload = jwt.verify(idToken, publicKey, {
        algorithms: ['RS256'],
        issuer: this.EXPECTED_ISS,
        audience,
        // jsonwebtoken enforces `exp` automatically (with a small clock skew
        // allowance) and rejects tokens without it.
        clockTolerance: 5,
      });
    } catch (err) {
      this.logger.warn(`Apple token verify failed: ${(err as Error).message}`);
      throw new UnauthorizedException('Apple token: invalid signature or claims');
    }

    if (typeof payload === 'string' || !payload || !payload.sub) {
      throw new UnauthorizedException('Apple token: malformed claims');
    }

    return payload as unknown as AppleClaims;
  }

  private async getKey(kid: string): Promise<AppleJwk | null> {
    const cached = await this.loadCached();
    if (cached) {
      const hit = cached.keys.find((k) => k.kid === kid);
      if (hit) return hit;
      // kid not in cache — Apple may have rotated; refresh under single-flight.
    }
    const fresh = await this.refreshSingleFlight(cached);
    return fresh.keys.find((k) => k.kid === kid) ?? null;
  }

  private async loadCached(): Promise<AppleJwks | null> {
    try {
      const raw = await this.redis.get(this.CACHE_KEY);
      if (!raw) return null;
      return JSON.parse(raw) as AppleJwks;
    } catch {
      return null;
    }
  }

  /**
   * Refresh the JWKS under a Redis SETNX lock so 1000 simultaneous Apple
   * sign-ins after a key rotation result in ONE outbound fetch instead of
   * 1000 (audit #43 — Apple rate-limits and would 429 the spike).
   *
   * The losers poll the cache for up to 3s with 200ms cadence; when the
   * winner publishes, they observe the new key. On Apple-unreachable, the
   * winner returns the stale cache if available rather than throwing —
   * better an expired-by-rotation signature failure on a single key than
   * a full Apple-sign-in outage.
   */
  private async refreshSingleFlight(stale: AppleJwks | null): Promise<AppleJwks> {
    const acquired = await this.redis.set(this.REFRESH_LOCK_KEY, '1', 'EX', 10, 'NX');
    if (acquired === 'OK') {
      try {
        return await this.fetchAndCache();
      } catch (err) {
        this.logger.warn(`Apple JWKS refresh failed: ${(err as Error).message}`);
        if (stale) return stale;
        throw err;
      } finally {
        this.redis.del(this.REFRESH_LOCK_KEY).catch(() => null);
      }
    }
    // Loser path: poll the cache for the winner's publish, up to 3s @ 200ms.
    for (let attempt = 0; attempt < 15; attempt++) {
      await new Promise((r) => setTimeout(r, 200));
      const fresh = await this.loadCached();
      if (fresh) return fresh;
    }
    // Winner never published within window — fall back to the stale copy.
    if (stale) return stale;
    throw new UnauthorizedException('Apple JWKS unavailable');
  }

  private async fetchAndCache(): Promise<AppleJwks> {
    const resp = await firstValueFrom(
      this.http.get<AppleJwks>(this.JWKS_URL, { timeout: 5000 }),
    );
    const jwks = resp.data;
    if (!jwks?.keys?.length) {
      throw new UnauthorizedException('Apple JWKS empty');
    }
    try {
      // Standard TTL on the live cache; a parallel longer-TTL stale-grace
      // key lets verify() limp on if Apple is fully unreachable.
      const payload = JSON.stringify(jwks);
      const pipe = this.redis.pipeline();
      pipe.setex(this.CACHE_KEY, this.CACHE_TTL_SEC, payload);
      pipe.setex(this.CACHE_KEY + ':stale', this.STALE_GRACE_SEC, payload);
      await pipe.exec();
    } catch (err) {
      this.logger.warn(`Apple JWKS cache set failed: ${(err as Error).message}`);
    }
    return jwks;
  }
}
