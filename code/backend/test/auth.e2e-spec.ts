import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import * as request from 'supertest';

import { AuthModule } from '../src/modules/auth/auth.module';
import { PrismaService } from '../src/common/prisma/prisma.service';
import { REDIS } from '../src/common/redis/redis.module';

/**
 * End-to-end smoke test for the email-OTP login flow.
 *
 * Audit hnag-audit-2026-05 §31 (test coverage <5%): the auth flow is the
 * single most security-critical surface and had zero E2E coverage. This
 * file proves the happy path end-to-end:
 *
 *   POST /v1/auth/email-otp/send  → 200 { sent: true }
 *   POST /v1/auth/email-otp/verify (wrong code) → 401 INVALID_OTP
 *   POST /v1/auth/email-otp/verify (right code) → 200 { accessToken, refreshToken, user }
 *
 * Strategy: in-memory fakes for Prisma + Redis. We do NOT spin a real
 * Postgres or Redis here — `backend-ci.yml` already does that for the
 * unit-test job. This file is fast (sub-second), green on every PR, and
 * regression-proofs the wiring (controller → service → DTO → Zod).
 *
 * To run only this file locally:
 *   npx jest test/auth.e2e-spec.ts --config test/jest-e2e.json
 */
describe('Auth — email OTP (e2e)', () => {
  let app: INestApplication;
  const otpStore = new Map<string, string>();
  const userStore = new Map<string, any>();
  const sessionStore: any[] = [];

  beforeAll(async () => {
    process.env.JWT_SECRET = 'a'.repeat(48);
    process.env.NODE_ENV = 'test';

    const fakePrisma = {
      users: {
        upsert: jest.fn(async ({ where, create, update }: any) => {
          const key = where.email ?? where.phone;
          let u = userStore.get(key);
          if (u) {
            u = { ...u, ...update };
          } else {
            u = {
              id: 'user-' + key,
              email: create.email ?? null,
              phone: create.phone ?? null,
              username: create.username,
              display_name: create.display_name,
              is_premium: false,
              language: 'vi',
            };
          }
          userStore.set(key, u);
          return u;
        }),
        findUnique: jest.fn(async ({ where }: any) => {
          if (where.email) return userStore.get(where.email) ?? null;
          if (where.username) return null; // no collisions in tests
          return null;
        }),
      },
      user_devices: { upsert: jest.fn(async () => null) },
      auth_sessions: {
        create: jest.fn(async ({ data }: any) => {
          sessionStore.push(data);
          return { id: 'sess-' + sessionStore.length, ...data };
        }),
        findUnique: jest.fn(),
        update: jest.fn(),
        updateMany: jest.fn(),
      },
    };

    const fakeRedis = {
      _store: new Map<string, string>(),
      _ttl: new Map<string, number>(),
      incr: jest.fn(async function (this: any, key: string) {
        const v = Number(this._store.get(key) ?? 0) + 1;
        this._store.set(key, String(v));
        return v;
      }),
      expire: jest.fn(async () => 1),
      set: jest.fn(async () => 'OK'),
      setex: jest.fn(async function (this: any, key: string, _ttl: number, v: string) {
        this._store.set(key, v);
        otpStore.set(key, v);
        return 'OK';
      }),
      get: jest.fn(async function (this: any, key: string) {
        return this._store.get(key) ?? null;
      }),
      del: jest.fn(async function (this: any, key: string) {
        this._store.delete(key);
        otpStore.delete(key);
        return 1;
      }),
      ping: jest.fn(async () => 'PONG'),
    };

    const mod: TestingModule = await Test.createTestingModule({
      imports: [AuthModule],
    })
      .overrideProvider(PrismaService).useValue(fakePrisma)
      .overrideProvider(REDIS).useValue(fakeRedis)
      .compile();

    app = mod.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true, forbidNonWhitelisted: true }));
    await app.init();
  });

  afterAll(async () => await app.close());

  const EMAIL = 'huy04082000@gmail.com';

  it('sends an OTP and refuses a malformed email', async () => {
    await request(app.getHttpServer())
      .post('/auth/email-otp/send')
      .send({ email: EMAIL })
      .expect(200)
      .expect((res) => {
        // SECURITY (audit #10): `devCode` must never appear in the response.
        expect(res.body).not.toHaveProperty('devCode');
        expect(res.body).toMatchObject({ sent: true });
      });

    await request(app.getHttpServer())
      .post('/auth/email-otp/send')
      .send({ email: 'not-an-email' })
      .expect(400);
  });

  it('rejects a wrong code with 401 and accepts the right code', async () => {
    // Find the stored OTP — we look it up via the fake redis side channel.
    const otpKey = [...otpStore.keys()].find((k) => k.startsWith('otp:email:login:'));
    expect(otpKey).toBeDefined();
    const code = otpStore.get(otpKey!)!;
    expect(code).toMatch(/^\d{6}$/);

    await request(app.getHttpServer())
      .post('/auth/email-otp/verify')
      .send({ email: EMAIL, code: '000000' })
      .expect(401);

    const res = await request(app.getHttpServer())
      .post('/auth/email-otp/verify')
      .send({ email: EMAIL, code })
      .expect(200);

    expect(res.body).toMatchObject({
      accessToken: expect.any(String),
      refreshToken: expect.any(String),
      user: expect.objectContaining({ id: expect.any(String) }),
    });
  });

  it('refresh: a malformed token is rejected without leaking session info', async () => {
    await request(app.getHttpServer())
      .post('/auth/refresh')
      .send({ refreshToken: 'totally-not-a-real-token' })
      .expect(401);
  });
});
