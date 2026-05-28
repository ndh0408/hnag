import { Test } from '@nestjs/testing';
import { ForbiddenException, BadRequestException } from '@nestjs/common';
import { createHmac } from 'crypto';

import { SubscriptionsService } from './subscriptions.service';
import { PrismaService } from '../../common/prisma/prisma.service';

/**
 * SePay webhook security tests.
 *
 * The audit (hnag-audit-2026-05 §forgeable-payment-webhook) flagged this
 * endpoint as the single most exploitable surface in the app: an attacker
 * who can hit it without proper auth could mint themselves premium for free.
 *
 * Each layer below must work INDEPENDENTLY — the test names map 1:1 to the
 * defenses in subscriptions.service.ts §handleSepayWebhook.
 *
 *   1. SEPAY_ALLOWED_IPS  → 403 if source IP not on allowlist
 *   2. SEPAY_WEBHOOK_TOKEN → 403 on missing / wrong / partially-correct token
 *   3. SEPAY_HMAC_SECRET   → 403 on missing / wrong / tampered-body signature
 *   4. payment_events UNIQUE → second call with same external_txn_id is a no-op
 *
 * No real DB — the prisma mock records what would have been written and
 * simulates the UNIQUE constraint violation for idempotency.
 */

const VALID_TOKEN = 'valid-webhook-token-1234';
const VALID_HMAC_SECRET = 'valid-hmac-secret-abcdef';

function makePayload(overrides: Record<string, unknown> = {}) {
  return {
    id: 'sepay-txn-100001',
    transferAmount: 49_000,
    content: 'HNAG aaaaaaaaaaaaaaaa',
    ...overrides,
  };
}

function signBody(body: any, secret = VALID_HMAC_SECRET): string {
  const raw = JSON.stringify(body);
  return 'sha256=' + createHmac('sha256', secret).update(raw).digest('hex');
}

class FakePrisma {
  // Records of "what we would have written" so the test can assert
  payment_events_created: any[] = [];
  payment_events: any = {
    create: jest.fn().mockImplementation(async ({ data }: any) => {
      const dup = this.payment_events_created.find(
        (e) => e.provider === data.provider && e.external_txn_id === data.external_txn_id,
      );
      if (dup) {
        // Simulate Prisma P2002 unique constraint violation
        const err: any = new Error('Unique constraint failed');
        err.code = 'P2002';
        throw err;
      }
      this.payment_events_created.push(data);
      return { id: 'pe-fake' };
    }),
    updateMany: jest.fn().mockResolvedValue({ count: 1 }),
  };
  subscriptions: any = { findUnique: jest.fn() };
  users: any = { update: jest.fn().mockResolvedValue({}) };
  $queryRawUnsafe = jest.fn().mockResolvedValue([]);
  $executeRawUnsafe = jest.fn().mockResolvedValue(1);
  $transaction = jest.fn().mockImplementation(async (cb: any) => cb(this));
}

describe('SubscriptionsService.handleSepayWebhook — security stack', () => {
  let service: SubscriptionsService;
  let prisma: FakePrisma;
  let savedEnv: Record<string, string | undefined>;

  beforeEach(async () => {
    savedEnv = {
      SEPAY_ALLOWED_IPS: process.env.SEPAY_ALLOWED_IPS,
      SEPAY_WEBHOOK_TOKEN: process.env.SEPAY_WEBHOOK_TOKEN,
      SEPAY_HMAC_SECRET: process.env.SEPAY_HMAC_SECRET,
    };
    process.env.SEPAY_WEBHOOK_TOKEN = VALID_TOKEN;
    process.env.SEPAY_HMAC_SECRET = VALID_HMAC_SECRET;
    delete process.env.SEPAY_ALLOWED_IPS;

    prisma = new FakePrisma();
    const mod = await Test.createTestingModule({
      providers: [
        SubscriptionsService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();
    service = mod.get(SubscriptionsService);
  });

  afterEach(() => {
    process.env.SEPAY_ALLOWED_IPS = savedEnv.SEPAY_ALLOWED_IPS;
    process.env.SEPAY_WEBHOOK_TOKEN = savedEnv.SEPAY_WEBHOOK_TOKEN;
    process.env.SEPAY_HMAC_SECRET = savedEnv.SEPAY_HMAC_SECRET;
  });

  // ── Layer 1: IP allowlist ───────────────────────────────────────────
  describe('IP allowlist', () => {
    it('rejects when source IP is not in SEPAY_ALLOWED_IPS', async () => {
      process.env.SEPAY_ALLOWED_IPS = '10.0.0.1,10.0.0.2';
      const body = makePayload();
      const sig = signBody(body);
      await expect(
        service.handleSepayWebhook(body, JSON.stringify(body), VALID_TOKEN, sig, '203.0.113.99'),
      ).rejects.toThrow(ForbiddenException);
    });

    it('accepts when source IP is on the allowlist (still needs valid token + sig)', async () => {
      process.env.SEPAY_ALLOWED_IPS = '10.0.0.1';
      const body = makePayload();
      const sig = signBody(body);
      const res = await service.handleSepayWebhook(body, JSON.stringify(body), VALID_TOKEN, sig, '10.0.0.1');
      expect(res.ok).toBe(true);
    });

    it('allows any IP when SEPAY_ALLOWED_IPS is unset (single-server deploys)', async () => {
      delete process.env.SEPAY_ALLOWED_IPS;
      const body = makePayload();
      const sig = signBody(body);
      const res = await service.handleSepayWebhook(body, JSON.stringify(body), VALID_TOKEN, sig, '203.0.113.99');
      expect(res.ok).toBe(true);
    });
  });

  // ── Layer 2: Bearer token ───────────────────────────────────────────
  describe('bearer token', () => {
    it('rejects when token is missing', async () => {
      const body = makePayload();
      const sig = signBody(body);
      await expect(
        service.handleSepayWebhook(body, JSON.stringify(body), undefined, sig, '127.0.0.1'),
      ).rejects.toThrow(ForbiddenException);
    });

    it('rejects on wrong token', async () => {
      const body = makePayload();
      const sig = signBody(body);
      await expect(
        service.handleSepayWebhook(body, JSON.stringify(body), 'wrong', sig, '127.0.0.1'),
      ).rejects.toThrow(ForbiddenException);
    });

    it('rejects on token that shares a prefix (timing-safe comparison)', async () => {
      const body = makePayload();
      const sig = signBody(body);
      const almost = VALID_TOKEN.slice(0, -1) + 'X';
      await expect(
        service.handleSepayWebhook(body, JSON.stringify(body), almost, sig, '127.0.0.1'),
      ).rejects.toThrow(ForbiddenException);
    });

    it('refuses to operate when SEPAY_WEBHOOK_TOKEN is unset (fail-closed)', async () => {
      delete process.env.SEPAY_WEBHOOK_TOKEN;
      const body = makePayload();
      const sig = signBody(body);
      await expect(
        service.handleSepayWebhook(body, JSON.stringify(body), VALID_TOKEN, sig, '127.0.0.1'),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  // ── Layer 3: HMAC signature ─────────────────────────────────────────
  describe('HMAC signature', () => {
    it('rejects when signature header is missing and HMAC secret is configured', async () => {
      const body = makePayload();
      await expect(
        service.handleSepayWebhook(body, JSON.stringify(body), VALID_TOKEN, undefined, '127.0.0.1'),
      ).rejects.toThrow(/signature/i);
    });

    it('rejects when signature is computed with the wrong secret', async () => {
      const body = makePayload();
      const wrongSig = signBody(body, 'attacker-guessed-secret');
      await expect(
        service.handleSepayWebhook(body, JSON.stringify(body), VALID_TOKEN, wrongSig, '127.0.0.1'),
      ).rejects.toThrow(/signature/i);
    });

    it('rejects when the body is tampered after signing (raw-body verification)', async () => {
      const body = makePayload();
      const sig = signBody(body); // sign original
      const tampered = JSON.stringify({ ...body, transferAmount: 9_999_999 }); // attacker bumps amount
      await expect(
        service.handleSepayWebhook(JSON.parse(tampered), tampered, VALID_TOKEN, sig, '127.0.0.1'),
      ).rejects.toThrow(/signature/i);
    });

    it('accepts a "sha256=" prefixed signature', async () => {
      const body = makePayload();
      const sig = signBody(body); // includes "sha256=" prefix
      const res = await service.handleSepayWebhook(body, JSON.stringify(body), VALID_TOKEN, sig, '127.0.0.1');
      expect(res.ok).toBe(true);
    });

    it('accepts a bare hex signature (no "sha256=" prefix)', async () => {
      const body = makePayload();
      const raw = JSON.stringify(body);
      const sig = createHmac('sha256', VALID_HMAC_SECRET).update(raw).digest('hex');
      const res = await service.handleSepayWebhook(body, raw, VALID_TOKEN, sig, '127.0.0.1');
      expect(res.ok).toBe(true);
    });
  });

  // ── Layer 4: Idempotency on external_txn_id ─────────────────────────
  describe('idempotency', () => {
    it('marks duplicate=true on second call with same external_txn_id', async () => {
      const body = makePayload({ id: 'sepay-txn-dedupe-1' });
      const raw = JSON.stringify(body);
      const sig = signBody(body);

      const first = await service.handleSepayWebhook(body, raw, VALID_TOKEN, sig, '127.0.0.1');
      expect(first.duplicate).toBeFalsy();

      const second = await service.handleSepayWebhook(body, raw, VALID_TOKEN, sig, '127.0.0.1');
      expect(second.ok).toBe(true);
      expect(second.duplicate).toBe(true);
    });

    it('rejects payload with no transaction id at all (cannot dedupe)', async () => {
      const body = { transferAmount: 49_000, content: 'HNAG aaaaaaaaaaaaaaaa' }; // no id/reference
      const raw = JSON.stringify(body);
      const sig = signBody(body);
      await expect(
        service.handleSepayWebhook(body, raw, VALID_TOKEN, sig, '127.0.0.1'),
      ).rejects.toThrow(BadRequestException);
    });
  });

  // ── Defence-in-depth: amount tampering ──────────────────────────────
  describe('amount and memo handling', () => {
    it('rejects underpayment (amount < subscription price)', async () => {
      prisma.$queryRawUnsafe.mockResolvedValueOnce([
        { id: 'sub-1', user_id: 'user-1', plan: 'monthly', amount_vnd: 49_000 },
      ]);
      const body = makePayload({ id: 'underpay-1', transferAmount: 1_000 }); // 1 VND attack
      const raw = JSON.stringify(body);
      const sig = signBody(body);
      const res = await service.handleSepayWebhook(body, raw, VALID_TOKEN, sig, '127.0.0.1');
      expect(res.matched).toBe(false); // not activated
    });

    it('returns matched=false when memo has no HNAG token', async () => {
      const body = makePayload({ id: 'no-memo-1', content: 'random transfer' });
      const raw = JSON.stringify(body);
      const sig = signBody(body);
      const res = await service.handleSepayWebhook(body, raw, VALID_TOKEN, sig, '127.0.0.1');
      expect(res.matched).toBe(false);
    });
  });
});
