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
  private readonly CACHE_TTL_SEC = 60 * 60; // 1 hour

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
      // kid not in cache — Apple may have rotated; force refresh once.
    }
    const fresh = await this.fetchAndCache();
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

  private async fetchAndCache(): Promise<AppleJwks> {
    const resp = await firstValueFrom(
      this.http.get<AppleJwks>(this.JWKS_URL, { timeout: 5000 }),
    );
    const jwks = resp.data;
    if (!jwks?.keys?.length) {
      throw new UnauthorizedException('Apple JWKS empty');
    }
    try {
      await this.redis.setex(this.CACHE_KEY, this.CACHE_TTL_SEC, JSON.stringify(jwks));
    } catch (err) {
      // Cache best-effort — verification still works on the freshly fetched value.
      this.logger.warn(`Apple JWKS cache set failed: ${(err as Error).message}`);
    }
    return jwks;
  }
}
