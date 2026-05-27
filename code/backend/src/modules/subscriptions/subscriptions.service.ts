import { Injectable, BadRequestException, ForbiddenException, NotFoundException, Logger, OnModuleInit } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { createHmac, timingSafeEqual, createHash } from 'crypto';
import { PrismaService } from '../../common/prisma/prisma.service';

export const PLANS = {
  monthly:        { name: 'HNAG+ Monthly',          priceVnd: 49_000,  periodMonths: 1 },
  yearly:         { name: 'HNAG+ Yearly',           priceVnd: 399_000, periodMonths: 12 },
  family_monthly: { name: 'HNAG Pro Family Monthly',priceVnd: 99_000,  periodMonths: 1, seats: 4 },
  family_yearly:  { name: 'HNAG Pro Family Yearly', priceVnd: 799_000, periodMonths: 12, seats: 4 },
  trial:          { name: 'HNAG+ Trial 7 ngày',     priceVnd: 0,       periodMonths: 0 },
} as const;

/** Plan id whitelist for Zod validation in the controller. */
export const PLAN_IDS = Object.keys(PLANS);

type PlanId = keyof typeof PLANS;

interface PromoEntry {
  code: string;
  plan: PlanId;
  months: number;
}

@Injectable()
export class SubscriptionsService implements OnModuleInit {
  private readonly logger = new Logger(SubscriptionsService.name);
  /** Parsed once at boot — audit #32 (was: parsed per call). */
  private promoCodes: Map<string, PromoEntry> = new Map();

  constructor(private readonly prisma: PrismaService) {}

  onModuleInit() {
    this.reloadPromoCodes();
  }

  /** Parse PROMO_CODES env. Public so admin reload endpoints can hot-swap. */
  reloadPromoCodes(): number {
    const raw = process.env.PROMO_CODES ?? '';
    const out = new Map<string, PromoEntry>();
    for (const entry of raw.split(',').map(s => s.trim()).filter(Boolean)) {
      const [code, plan, monthsStr] = entry.split(':');
      if (!code || !plan) continue;
      if (!(plan in PLANS)) {
        this.logger.warn(`PROMO_CODES: skipping ${code} — unknown plan ${plan}`);
        continue;
      }
      const months = parseInt(monthsStr ?? '1', 10);
      out.set(code.toUpperCase(), { code: code.toUpperCase(), plan: plan as PlanId, months: Number.isFinite(months) && months > 0 ? months : 1 });
    }
    this.promoCodes = out;
    this.logger.log(`PROMO_CODES loaded: ${out.size} codes`);
    return out.size;
  }

  listPlans() {
    return Object.entries(PLANS).map(([id, p]) => ({ id, ...p }));
  }

  async startCheckout(userId: string, plan: PlanId, provider: string, _redirectUrl?: string) {
    const def = PLANS[plan];
    if (!def) throw new BadRequestException('Gói không hợp lệ');

    if (plan === 'trial' || provider === 'trial') {
      const prior = await this.prisma.subscriptions.findFirst({
        where: { user_id: userId, provider: 'trial' },
        select: { id: true },
      });
      if (prior) throw new BadRequestException('Bạn đã sử dụng bản dùng thử rồi');
      return this.activate(userId, 'trial', 'trial', { trialDays: 7 });
    }

    const bankBin = process.env.VIETQR_BANK_BIN;
    const accountNo = process.env.VIETQR_ACCOUNT_NO;
    const accountName = process.env.VIETQR_ACCOUNT_NAME ?? 'HNAG';

    const pending = await this.prisma.subscriptions.create({
      data: {
        user_id: userId,
        plan,
        provider: 'vietqr',
        amount_vnd: def.priceVnd,
        status: 'trialing',
      },
      select: { id: true },
    });
    const subId = pending.id;
    const memo = `HNAG ${subId.replace(/-/g, '').slice(0, 16)}`.toUpperCase();

    if (!bankBin || !accountNo) {
      return {
        subscriptionId: subId,
        status: 'manual',
        message: 'Chưa cấu hình tài khoản nhận tiền. Dùng promo-code cho beta, hoặc liên hệ admin.',
        amountVnd: def.priceVnd,
        memo,
      };
    }

    const qrUrl = `https://img.vietqr.io/image/${bankBin}-${accountNo}-compact2.png`
      + `?amount=${def.priceVnd}&addInfo=${encodeURIComponent(memo)}&accountName=${encodeURIComponent(accountName)}`;

    return {
      subscriptionId: subId,
      status: 'awaiting_transfer',
      method: 'vietqr',
      qrUrl,
      bankBin, accountNo, accountName,
      amountVnd: def.priceVnd,
      memo,
      note: 'Chuyển khoản đúng số tiền + nội dung. Premium kích hoạt tự động khi nhận được tiền (hoặc trong vài phút).',
    };
  }

  /**
   * SePay bank-transfer webhook.
   *
   * Security layers (closes audit hnag-audit-2026-05 CRITICAL "forgeable webhook"
   * + audit #2 silent payment loss):
   *   1. Bearer token compared with `timingSafeEqual` (sha256-normalised so
   *      length-mismatch can't leak secret length).
   *   2. HMAC-SHA256 over the RAW body against `SEPAY_HMAC_SECRET`. When the
   *      secret is configured, the signature is MANDATORY.
   *   3. Idempotency via UNIQUE(provider, external_txn_id) — replays are no-ops.
   *   4. Match the subscription by EXACT SQL prefix on the dashless id text
   *      (audit #2: previously `findMany take:50 + JS startsWith` could miss
   *      legitimate transfers when >50 pendings existed).
   *   5. Amount + memo are matched server-side against the pending subscription
   *      record (not from the webhook); attackers cannot forge "premium for 1₫".
   */
  async handleSepayWebhook(
    payload: any,
    rawBody: string,
    authToken?: string,
    signature?: string,
    sourceIp?: string,
  ): Promise<{ ok: boolean; matched?: boolean; duplicate?: boolean }> {
    // ── 0. Source IP allowlist (audit AI-quality §M-8) ─────────────────
    // SePay publishes their egress IPs. Restrict here so a leaked
    // bearer token alone isn't sufficient — caller must also be on
    // SEPAY_ALLOWED_IPS (comma-separated CIDR list; empty = allow any).
    const allowedIps = (process.env.SEPAY_ALLOWED_IPS ?? '').split(',').map(s => s.trim()).filter(Boolean);
    if (allowedIps.length > 0) {
      const ip = (sourceIp ?? '').trim();
      if (!ip || !allowedIps.some((a) => ipMatches(ip, a))) {
        this.logger.warn(`SePay webhook from ${ip || 'unknown'} not in allowlist`);
        throw new ForbiddenException('Source IP not allowed');
      }
    }

    // ── 1. Bearer token ────────────────────────────────────────────────
    const expected = process.env.SEPAY_WEBHOOK_TOKEN;
    if (!expected) {
      this.logger.error('SePay webhook called but SEPAY_WEBHOOK_TOKEN is not configured — rejecting');
      throw new ForbiddenException('Webhook not configured');
    }
    if (!safeEqualStr(authToken ?? '', expected)) {
      throw new ForbiddenException('Invalid webhook token');
    }

    // ── 2. HMAC signature (when configured) ────────────────────────────
    const hmacSecret = process.env.SEPAY_HMAC_SECRET;
    if (hmacSecret) {
      if (!signature) throw new ForbiddenException('Missing signature');
      const computed = createHmac('sha256', hmacSecret).update(rawBody).digest('hex');
      const provided = signature.replace(/^sha256=/i, '');
      if (!safeEqualStr(provided, computed)) throw new ForbiddenException('Invalid signature');
    }

    // ── 3. Idempotency key from the bank transaction id ────────────────
    const externalTxnId = String(
      payload?.id ?? payload?.referenceCode ?? payload?.reference ?? payload?.transactionId ?? '',
    ).trim();
    if (!externalTxnId) throw new BadRequestException('Missing transaction id');

    const content: string = (payload?.content ?? payload?.description ?? '').toString().toUpperCase();
    const amount: number = Number(payload?.transferAmount ?? payload?.amount ?? 0);

    try {
      await this.prisma.payment_events.create({
        data: {
          provider: 'sepay',
          external_txn_id: externalTxnId,
          amount_vnd: Number.isFinite(amount) && amount >= 0 ? Math.floor(amount) : 0,
          raw_payload: payload as any,
          signature: signature ?? null,
          status: 'received',
        },
      });
    } catch (err: any) {
      if (err?.code === 'P2002' || /unique/i.test(String(err?.message))) {
        this.logger.log(`SePay webhook: duplicate txn ${externalTxnId} — ignored`);
        return { ok: true, matched: true, duplicate: true };
      }
      throw err;
    }

    // ── 4. Match the subscription by exact memo via SQL prefix ─────────
    const m = content.match(/HNAG\s+([A-F0-9]{16})/);
    if (!m) {
      this.logger.warn(`SePay webhook: no HNAG memo in "${content}"`);
      await this.markEvent(externalTxnId, 'unmatched', 'no_memo');
      return { ok: true, matched: false };
    }
    const subHexPrefix = m[1].toLowerCase();
    // Audit #2: prior code did `findMany take:50` + JS startsWith → silently
    // missed legitimate payments when >50 pendings existed. SQL prefix scan
    // is bounded by the (provider, status, created_at DESC) btree from
    // sql/10_indexes.sql.
    const matches: Array<{ id: string; user_id: string | null; plan: string; amount_vnd: number | null }> =
      await this.prisma.$queryRawUnsafe(
        `SELECT id::text, user_id::text, plan, amount_vnd
         FROM subscriptions
         WHERE provider = 'vietqr' AND status = 'trialing'
           AND replace(id::text, '-', '') LIKE $1
         ORDER BY created_at DESC
         LIMIT 2`,
        `${subHexPrefix}%`,
      );

    if (matches.length === 0) {
      this.logger.warn(`SePay webhook: no pending sub for ${subHexPrefix}`);
      await this.markEvent(externalTxnId, 'unmatched', 'no_pending_sub');
      return { ok: true, matched: false };
    }
    if (matches.length > 1) {
      // 16-hex-prefix collisions are astronomically unlikely (1 in 2^64) —
      // but if it ever happens, refuse silent activation and queue for
      // manual review rather than guessing wrong.
      this.logger.warn(`SePay webhook: ambiguous prefix ${subHexPrefix} matched ${matches.length} subs`);
      await this.markEvent(externalTxnId, 'unmatched', 'ambiguous_prefix');
      return { ok: true, matched: false };
    }
    const sub = matches[0];

    if (!Number.isFinite(amount) || amount < (sub.amount_vnd ?? 0)) {
      this.logger.warn(`SePay webhook: amount ${amount} < required ${sub.amount_vnd}`);
      await this.markEvent(externalTxnId, 'rejected', 'underpayment');
      return { ok: true, matched: false };
    }

    if (!sub.user_id) {
      this.logger.warn(`SePay webhook: sub ${sub.id} has no user_id; rejecting`);
      await this.markEvent(externalTxnId, 'rejected', 'sub_orphan');
      return { ok: true, matched: false };
    }

    const months = sub.plan === 'yearly' ? 12 : sub.plan === 'family_yearly' ? 12 : 1;
    await this.activate(sub.user_id, sub.plan as PlanId, 'vietqr', { months });
    await this.prisma.payment_events.updateMany({
      where: { provider: 'sepay', external_txn_id: externalTxnId },
      data: {
        subscription_id: sub.id,
        user_id: sub.user_id,
        status: 'processed',
        processed_at: new Date(),
      },
    });
    this.logger.log(`SePay: activated premium for user ${sub.user_id} (${sub.plan}) via txn ${externalTxnId}`);
    return { ok: true, matched: true };
  }

  private async markEvent(externalTxnId: string, status: string, notes: string) {
    try {
      await this.prisma.payment_events.updateMany({
        where: { provider: 'sepay', external_txn_id: externalTxnId },
        data: { status, processed_at: new Date(), notes },
      });
    } catch (err) {
      this.logger.warn(`Failed to update payment_event ${externalTxnId}: ${(err as Error).message}`);
    }
  }

  /**
   * Redeem a promo code. Closes audit #1:
   *   - parsed once at boot (audit #32)
   *   - per-(user, code) advisory lock prevents the prior check-then-act race
   *     that allowed two parallel calls to both pass the existence check and
   *     both activate
   *   - `activate()` uses GREATEST(...) so concurrent activations EXTEND the
   *     premium window rather than overwriting it (audit #1)
   */
  async redeemPromo(userId: string, code: string) {
    const codeUpper = code.trim().toUpperCase();
    const entry = this.promoCodes.get(codeUpper);
    if (!entry) throw new BadRequestException('Mã không hợp lệ hoặc đã hết hạn');

    // Advisory lock per (userId, code) so concurrent redemptions serialize.
    const lockA = hash32(userId);
    const lockB = hash32(`promo:${entry.code}`);

    return this.prisma.$transaction(async (tx) => {
      await tx.$executeRawUnsafe(`SELECT pg_advisory_xact_lock($1::int, $2::int)`, lockA, lockB);
      const prior = await tx.subscriptions.findFirst({
        where: { user_id: userId, provider: 'promo', external_id: `promo:${entry.code}` },
        select: { id: true },
      });
      if (prior) throw new BadRequestException('Bạn đã dùng mã này rồi');
      this.logger.log(`Promo ${entry.code} redeemed by ${userId} → ${entry.plan} ${entry.months}m`);
      return this.activateInTx(tx, userId, entry.plan, 'promo', { months: entry.months, promoCode: entry.code });
    });
  }

  /**
   * Cancel auto-renewal. Audit AI-quality §C-6: was no endpoint. Premium
   * remains active until `current_period_end`, then expires naturally via
   * the cron below. No proration — VietQR / promo plans are pre-paid.
   */
  async cancel(userId: string, reason?: string) {
    const sub = await this.prisma.subscriptions.findFirst({
      where: { user_id: userId, status: 'active' },
      orderBy: { created_at: 'desc' },
    });
    if (!sub) {
      throw new NotFoundException('Không có gói đang hoạt động để huỷ');
    }
    if (sub.cancelled_at) {
      return { ok: true, alreadyCancelled: true, expiresAt: sub.current_period_end };
    }
    await this.prisma.subscriptions.update({
      where: { id: sub.id },
      data: {
        cancelled_at: new Date(),
        cancel_reason: (reason ?? '').slice(0, 200) || null,
        auto_renew: false,
      },
    });
    this.logger.log(`Sub ${sub.id} (user ${userId}) cancelled — expires ${sub.current_period_end}`);
    return { ok: true, expiresAt: sub.current_period_end };
  }

  /**
   * Hourly sweep: any user whose `premium_until` has passed AND who is
   * still flagged `is_premium=true` gets demoted. Audit AI-quality §C-7:
   * previously the flag stayed true forever; `PremiumGuard` denied in
   * real time but `users.is_premium` lied — affected analytics, JWT
   * claims on next refresh, and any other reader of the column.
   */
  @Cron(CronExpression.EVERY_HOUR)
  async expirePremiumCron(): Promise<void> {
    try {
      const now = new Date();
      const affected = await this.prisma.$executeRawUnsafe(
        `UPDATE users
            SET is_premium = false
          WHERE is_premium = true
            AND premium_until IS NOT NULL
            AND premium_until < $1::timestamptz`,
        now,
      );
      if (affected && Number(affected) > 0) {
        this.logger.log(`Premium expiration sweep: demoted ${affected} users`);
      }
    } catch (err) {
      this.logger.warn(`expirePremiumCron failed: ${(err as Error).message}`);
    }
  }

  async myStatus(userId: string) {
    const [user, sub] = await Promise.all([
      this.prisma.users.findUnique({
        where: { id: userId },
        select: { is_premium: true, premium_until: true },
      }),
      this.prisma.subscriptions.findFirst({
        where: { user_id: userId },
        orderBy: { created_at: 'desc' },
        select: {
          id: true,
          plan: true,
          provider: true,
          amount_vnd: true,
          status: true,
          trial_ends_at: true,
          current_period_end: true,
          created_at: true,
        },
      }),
    ]);
    return {
      isPremium: user?.is_premium ?? false,
      premiumUntil: user?.premium_until ?? null,
      subscription: sub,
    };
  }

  private async activate(userId: string, plan: PlanId, provider: string, opts: { months?: number; trialDays?: number; promoCode?: string }) {
    return this.prisma.$transaction((tx) => this.activateInTx(tx, userId, plan, provider, opts));
  }

  /**
   * Activate a subscription INSIDE a transaction. Closes audit #1:
   *   - `premium_until = GREATEST(current_value, new_until)` so concurrent
   *     activations EXTEND rather than overwrite (was: replaced — meaning
   *     a parallel yearly + monthly redemption left the user with whichever
   *     ran last, often the smaller one).
   *   - uses Prisma typed inserts; raw SQL only used for the GREATEST update.
   */
  private async activateInTx(
    tx: any,
    userId: string,
    plan: PlanId,
    provider: string,
    opts: { months?: number; trialDays?: number; promoCode?: string },
  ) {
    const now = Date.now();
    const until = opts.trialDays
      ? new Date(now + opts.trialDays * 24 * 3600 * 1000)
      : new Date(now + (opts.months ?? 1) * 30 * 24 * 3600 * 1000);
    const status = opts.trialDays ? 'trialing' : 'active';
    const amount = PLANS[plan]?.priceVnd ?? 0;
    const externalId = opts.promoCode ? `promo:${opts.promoCode}` : null;

    const sub = await tx.subscriptions.create({
      data: {
        user_id: userId,
        plan,
        provider,
        amount_vnd: amount,
        status,
        trial_ends_at: opts.trialDays ? until : null,
        current_period_end: until,
        external_id: externalId,
      },
      select: { id: true },
    });
    // GREATEST so concurrent activations extend rather than overwrite.
    await tx.$executeRawUnsafe(
      `UPDATE users
          SET is_premium = true,
              premium_until = GREATEST(COALESCE(premium_until, NOW()), $2::timestamptz)
        WHERE id = $1::uuid`,
      userId, until,
    );
    return { status, isPremium: true, premiumUntil: until, subscriptionId: sub.id };
  }
}

/**
 * Constant-time string equality. `timingSafeEqual` requires same-length
 * buffers; we normalize via SHA-256 fingerprints so an attacker cannot use
 * the length-mismatch fast-path to leak the secret's length.
 */
function safeEqualStr(a: string, b: string): boolean {
  const ha = createHash('sha256').update(String(a)).digest();
  const hb = createHash('sha256').update(String(b)).digest();
  return timingSafeEqual(ha, hb);
}

/** Stable 32-bit hash of a string for use as pg_advisory_xact_lock keys. */
function hash32(s: string): number {
  const buf = createHash('sha256').update(s).digest();
  const u = buf.readUInt32BE(0);
  return u > 0x7fffffff ? u - 0x100000000 : u;
}

/** Match an IP against an allowlist entry — plain IP equality or CIDR. */
function ipMatches(ip: string, pattern: string): boolean {
  if (!ip || !pattern) return false;
  // Drop IPv6 mapping prefix Cloudflare sometimes adds.
  const clean = ip.startsWith('::ffff:') ? ip.slice(7) : ip;
  if (!pattern.includes('/')) return clean === pattern;
  // Naive IPv4 CIDR check — enough for whitelisting a payment provider's
  // /24 published ranges. IPv6 + complex CIDR can use `ip-address` lib.
  const [base, bitsStr] = pattern.split('/');
  const bits = Number(bitsStr);
  if (!Number.isFinite(bits) || bits < 0 || bits > 32) return false;
  const toInt = (v: string): number | null => {
    const parts = v.split('.').map((n) => Number(n));
    if (parts.length !== 4 || parts.some((n) => !Number.isFinite(n) || n < 0 || n > 255)) return null;
    return ((parts[0] << 24) | (parts[1] << 16) | (parts[2] << 8) | parts[3]) >>> 0;
  };
  const ipInt = toInt(clean);
  const baseInt = toInt(base);
  if (ipInt === null || baseInt === null) return false;
  const mask = bits === 0 ? 0 : (~0 << (32 - bits)) >>> 0;
  return (ipInt & mask) === (baseInt & mask);
}
