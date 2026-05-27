import { Test, TestingModule } from '@nestjs/testing';
import { HttpService } from '@nestjs/axios';
import { UnauthorizedException } from '@nestjs/common';
import { generateKeyPairSync, createPrivateKey, KeyObject } from 'crypto';
import * as jwt from 'jsonwebtoken';
import { of, throwError } from 'rxjs';

import { AppleTokenVerifier } from './apple-token-verifier.service';
import { REDIS } from '../../common/redis/redis.module';

/**
 * Regression suite for the Apple Sign-in identityToken verifier.
 *
 * Strategy: spin up a local RSA keypair, hand the public half to the
 * verifier via a fake JWKS HTTP response, sign test tokens with the
 * private half, and assert the verifier accepts / rejects exactly the
 * tokens a real Apple flow would produce / a real attacker would forge.
 *
 * Specifically guards the audit hnag-audit-2026-05 CRITICAL finding:
 *   "anyone can forge an identityToken with any `sub` and impersonate
 *    any Apple-linked user" — by proving here that the verifier rejects:
 *      - unsigned (`alg: none`) tokens
 *      - tokens signed with the wrong key (different RSA keypair)
 *      - tokens with a wrong issuer or audience
 *      - expired tokens
 */
describe('AppleTokenVerifier', () => {
  let verifier: AppleTokenVerifier;
  let httpGet: jest.Mock;
  let redisGet: jest.Mock;
  let redisSetex: jest.Mock;
  let publicJwk: any;
  let privateKey: KeyObject;
  const AUD = 'vn.hnag.hnag';
  const ISS = 'https://appleid.apple.com';
  const KID = 'test-kid-001';

  beforeEach(async () => {
    const { publicKey, privateKey: priv } = generateKeyPairSync('rsa', { modulusLength: 2048 });
    privateKey = createPrivateKey(priv);
    publicJwk = { ...publicKey.export({ format: 'jwk' }), kid: KID, use: 'sig', alg: 'RS256' };

    httpGet = jest.fn().mockReturnValue(of({ data: { keys: [publicJwk] } }));
    redisGet = jest.fn().mockResolvedValue(null);
    redisSetex = jest.fn().mockResolvedValue('OK');

    const mod: TestingModule = await Test.createTestingModule({
      providers: [
        AppleTokenVerifier,
        { provide: HttpService, useValue: { get: httpGet } },
        { provide: REDIS, useValue: { get: redisGet, setex: redisSetex } },
      ],
    }).compile();

    verifier = mod.get(AppleTokenVerifier);
  });

  const sign = (
    payload: Record<string, unknown>,
    overrides: { kid?: string; alg?: jwt.Algorithm; key?: KeyObject } = {},
  ): string => {
    return jwt.sign(
      { iss: ISS, aud: AUD, sub: 'apple-user-1', iat: Math.floor(Date.now() / 1000), ...payload },
      overrides.key ?? privateKey,
      {
        algorithm: overrides.alg ?? 'RS256',
        expiresIn: '5m',
        keyid: overrides.kid ?? KID,
      } as jwt.SignOptions,
    );
  };

  it('accepts a well-formed token signed by the right key', async () => {
    const token = sign({ sub: 'apple-user-valid', email: 'foo@example.com' });
    const claims = await verifier.verify(token, AUD);
    expect(claims.sub).toBe('apple-user-valid');
    expect(claims.email).toBe('foo@example.com');
  });

  it('REJECTS an unsigned token (alg=none) — the forgery vector flagged in audit', async () => {
    // jsonwebtoken refuses to *issue* alg:none with a real key, so build the
    // token manually to simulate an attacker.
    const header = Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT', kid: KID })).toString('base64url');
    const body = Buffer.from(
      JSON.stringify({ iss: ISS, aud: AUD, sub: 'attacker-controlled', exp: Math.floor(Date.now() / 1000) + 60 }),
    ).toString('base64url');
    const malicious = `${header}.${body}.`;
    await expect(verifier.verify(malicious, AUD)).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('REJECTS a token signed by a different keypair', async () => {
    const { privateKey: otherPriv } = generateKeyPairSync('rsa', { modulusLength: 2048 });
    const token = sign({ sub: 'attacker' }, { key: createPrivateKey(otherPriv) });
    await expect(verifier.verify(token, AUD)).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('REJECTS a token with the wrong audience', async () => {
    const token = sign({ aud: 'com.evil.app' });
    await expect(verifier.verify(token, AUD)).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('REJECTS a token with the wrong issuer', async () => {
    const token = sign({ iss: 'https://evil.example.com' });
    await expect(verifier.verify(token, AUD)).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('REJECTS an expired token', async () => {
    const token = jwt.sign(
      { iss: ISS, aud: AUD, sub: 'apple-user-1', iat: Math.floor(Date.now() / 1000) - 7200 },
      privateKey,
      { algorithm: 'RS256', expiresIn: '-1h', keyid: KID } as jwt.SignOptions,
    );
    await expect(verifier.verify(token, AUD)).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('REJECTS a token whose kid does not match any published key', async () => {
    const token = sign({}, { kid: 'unknown-kid' });
    await expect(verifier.verify(token, AUD)).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('serves JWKS from Redis cache on the second call', async () => {
    const token1 = sign({});
    await verifier.verify(token1, AUD);
    expect(httpGet).toHaveBeenCalledTimes(1);

    // Second call: Redis returns the cached JWKS, so no HTTP fetch.
    redisGet.mockResolvedValueOnce(JSON.stringify({ keys: [publicJwk] }));
    const token2 = sign({});
    await verifier.verify(token2, AUD);
    expect(httpGet).toHaveBeenCalledTimes(1);
  });

  it('refetches JWKS on kid cache miss (Apple key rotation)', async () => {
    // Cached JWKS contains a different kid; force a refetch.
    redisGet.mockResolvedValueOnce(JSON.stringify({ keys: [{ ...publicJwk, kid: 'old-kid' }] }));
    const token = sign({}); // signed with current KID
    await verifier.verify(token, AUD);
    expect(httpGet).toHaveBeenCalledTimes(1);
  });

  it('fails gracefully when Apple JWKS endpoint is unreachable', async () => {
    httpGet.mockReturnValueOnce(throwError(() => new Error('ENETUNREACH')));
    const token = sign({});
    await expect(verifier.verify(token, AUD)).rejects.toThrow();
  });
});
