import { Injectable, BadRequestException, ForbiddenException, Logger } from '@nestjs/common';
import { createHmac, timingSafeEqual } from 'crypto';
import { PrismaService } from '../../common/prisma/prisma.service';

export const PLANS = {
  monthly: { name: 'HNAG+ Monthly', priceVnd: 49_000, periodMonths: 1 },
  yearly:  { name: 'HNAG+ Yearly',  priceVnd: 399_000, periodMonths: 12 },
  family_monthly: { name: 'HNAG Pro Family Monthly', priceVnd: 99_000, periodMonths: 1, seats: 4 },
  family_yearly:  { name: 'HNAG Pro Family Yearly',  priceVnd: 799_000, periodMonths: 12, seats: 4 },
  trial: { name: 'HNAG+ Trial 7 ngày', priceVnd: 0, periodMonths: 0 },
};

@Injectable()
export class SubscriptionsService {
  private readonly logger = new Logger(SubscriptionsService.name);
  constructor(private readonly prisma: PrismaService) {}

  listPlans() {
    return Object.entries(PLANS).map(([id, p]) => ({ id, ...p }));
  }

  /**
   * Start checkout. For Vietnam-without-business we use VietQR bank transfer.
   * - 'trial': activates a 7-day trial immediately (no payment).
   * - 'vietqr' (default): returns a VietQR image URL + unique transfer memo.
   *   When SePay (or manual admin) confirms the transfer, premium is activated.
   */
  async startCheckout(userId: string, plan: keyof typeof PLANS, provider: string, redirectUrl?: string) {
    const def = PLANS[plan];
    if (!def) throw new BadRequestException('Gói không hợp lệ');

    if (plan === 'trial' || provider === 'trial') {
      // Idempotency: one trial per user — block chained free trials.
      const prior = await this.prisma.subscriptions.findFirst({
        where: { user_id: userId, provider: 'trial' },
        select: { id: true },
      });
      if (prior) throw new BadRequestException('Bạn đã sử dụng bản dùng thử rồi');
      return this.activate(userId, 'trial', 'trial', { trialDays: 7 });
    }

    // VietQR — works with a personal bank account, no business needed.
    const bankBin = process.env.VIETQR_BANK_BIN;        // e.g. 970436 (Vietcombank)
    const accountNo = process.env.VIETQR_ACCOUNT_NO;    // personal account number
    const accountName = process.env.VIETQR_ACCOUNT_NAME ?? 'HNAG';

    // Insert the pending subscription first so the memo can carry the unique
    // subscription id (not a user-id prefix — that was forgeable/collision-prone).
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
    // Memo embeds a 16-hex slice of the subscription id → effectively unique,
    // and tied to one subscription (one user + one amount).
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

    // VietQR free image API — any VN banking app can scan this.
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
   * Security layers (closes audit hnag-audit-2026-05 CRITICAL "forgeable webhook"):
   *   1. Bearer token compared with `timingSafeEqual` — no character-by-character
   *      timing leak.
   *   2. Optional but recommended HMAC-SHA256 of the raw body against
   *      `SEPAY_HMAC_SECRET`. When the secret is configured, the signature is
   *      MANDATORY and verified timing-safe.
   *   3. Idempotency: every verified webhook is recorded in `payment_events`
   *      with a UNIQUE (provider, external_txn_id). A replayed POST hits the
   *      unique constraint and is a no-op — no double activation possible.
   *   4. Amount + memo are matched server-side against the pending subscription
   *      record (not from the webhook); attackers cannot forge a "premium for 1₫"
   *      activation.
   */
  async handleSepayWebhook(
    payload: any,
    rawBody: string,
    authToken?: string,
    signature?: string,
  ): Promise<{ ok: boolean; matched?: boolean; duplicate?: boolean }> {
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
      if (!signature) {
        this.logger.warn('SePay webhook missing signature header while HMAC secret is set');
        throw new ForbiddenException('Missing signature');
      }
      const computed = createHmac('sha256', hmacSecret).update(rawBody).digest('hex');
      // Strip an optional `sha256=` prefix to accommodate either format.
      const provided = signature.replace(/^sha256=/i, '');
      if (!safeEqualStr(provided, computed)) {
        this.logger.warn('SePay webhook HMAC mismatch');
        throw new ForbiddenException('Invalid signature');
      }
    }

    // ── 3. Idempotency key from the bank transaction id ────────────────
    const externalTxnId = String(
      payload?.id ?? payload?.referenceCode ?? payload?.reference ?? payload?.transactionId ?? '',
    ).trim();
    if (!externalTxnId) {
      this.logger.warn('SePay webhook: missing transaction id — cannot dedupe');
      throw new BadRequestException('Missing transaction id');
    }

    const content: string = (payload?.content ?? payload?.description ?? '').toString().toUpperCase();
    const amount: number = Number(payload?.transferAmount ?? payload?.amount ?? 0);

    // Reserve the idempotency row up front. If we have already seen this
    // transaction, the unique constraint will throw — we treat that as success
    // (the original processing wins) and report `duplicate: true` to the caller.
    try {
      await this.prisma.payment_events.create({
        data: {
          provider: 'sepay',
          external_txn_id: externalTxnId,
          amount_vnd: Number.isFinite(amount) ? amount : 0,
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

    // ── 4. Match the subscription by exact memo ────────────────────────
    const m = content.match(/HNAG\s+([A-F0-9]{16})/);
    if (!m) {
      this.logger.warn(`SePay webhook: no HNAG memo in "${content}"`);
      await this.markEvent(externalTxnId, 'unmatched', 'no_memo');
      return { ok: true, matched: false };
    }
    const subHexPrefix = m[1].toLowerCase();
    const subs = await this.prisma.subscriptions.findMany({
      where: {
        provider: 'vietqr',
        status: 'trialing',
        // `replace(id::text, '-', '')` is what the memo encodes; we look up
        // by startsWith on the dashless hex form. The 16-hex prefix is
        // entropic enough that collisions are negligible at our scale.
      },
      orderBy: { created_at: 'desc' },
      take: 50,
    });
    const sub = subs.find((s) => s.id.replace(/-/g, '').toLowerCase().startsWith(subHexPrefix));
    if (!sub) {
      this.logger.warn(`SePay webhook: no pending sub for ${subHexPrefix}`);
      await this.markEvent(externalTxnId, 'unmatched', 'no_pending_sub');
      return { ok: true, matched: false };
    }

    if (!Number.isFinite(amount) || amount < (sub.amount_vnd ?? 0)) {
      this.logger.warn(`SePay webhook: amount ${amount} < required ${sub.amount_vnd}`);
      await this.markEvent(externalTxnId, 'rejected', 'underpayment');
      return { ok: true, matched: false };
    }

    const months = sub.plan === 'yearly' ? 12 : sub.plan === 'family_yearly' ? 12 : 1;
    await this.activate(sub.user_id!, sub.plan as keyof typeof PLANS, 'vietqr', { months });
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
   * Redeem a promo code → grant Premium. Codes live in env PROMO_CODES as
   * "CODE:plan:months" comma-separated, e.g. "BETA2026:yearly:12,VIP:monthly:1".
   */
  async redeemPromo(userId: string, code: string) {
    // No hardcoded fallback — promo codes must be explicitly configured in env.
    const raw = process.env.PROMO_CODES ?? '';
    const entries = raw.split(',').map(s => s.trim()).filter(Boolean);
    const match = entries.find(e => e.split(':')[0].toUpperCase() === code.trim().toUpperCase());
    if (!match) throw new BadRequestException('Mã không hợp lệ hoặc đã hết hạn');
    const [codePart, plan, monthsStr] = match.split(':');
    const months = parseInt(monthsStr) || 1;
    // One redemption per user per code (best-effort guard without a dedicated table):
    const prior = await this.prisma.subscriptions.findFirst({
      where: { user_id: userId, provider: 'promo', external_id: `promo:${codePart.toUpperCase()}` },
      select: { id: true },
    });
    if (prior) throw new BadRequestException('Bạn đã dùng mã này rồi');
    this.logger.log(`Promo ${codePart} redeemed by ${userId} → ${plan} ${months}m`);
    return this.activate(userId, (plan as keyof typeof PLANS) ?? 'monthly', 'promo', { months, promoCode: codePart.toUpperCase() });
  }

  async myStatus(userId: string) {
    // Audit hnag-audit-2026-05 §11: this used to be two sequential queries.
    // Parallelize so cold p95 is bounded by max(query) rather than sum(query).
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

  private async activate(userId: string, plan: keyof typeof PLANS, provider: string, opts: { months?: number; trialDays?: number; promoCode?: string }) {
    const now = Date.now();
    const until = opts.trialDays
      ? new Date(now + opts.trialDays * 24 * 3600 * 1000)
      : new Date(now + (opts.months ?? 1) * 30 * 24 * 3600 * 1000);
    const status = opts.trialDays ? 'trialing' : 'active';
    const amount = PLANS[plan]?.priceVnd ?? 0;
    const externalId = opts.promoCode ? `promo:${opts.promoCode}` : null;

    // Raw SQL to avoid Prisma enum mapping mismatch on partial schema.
    const rows: any[] = await this.prisma.$queryRawUnsafe(
      `INSERT INTO subscriptions (user_id, plan, provider, amount_vnd, status, trial_ends_at, current_period_end, external_id)
       VALUES ($1::uuid, $2, $3, $4, $5::subscription_status, $6, $7, $8)
       RETURNING id`,
      userId, plan, provider, amount, status,
      opts.trialDays ? until : null, until, externalId,
    );
    await this.prisma.$executeRawUnsafe(
      `UPDATE users SET is_premium = true, premium_until = $2 WHERE id = $1::uuid`,
      userId, until,
    );
    return { status, isPremium: true, premiumUntil: until, subscriptionId: rows[0]?.id };
  }
}

/**
 * Constant-time string equality. `timingSafeEqual` requires same-length
 * buffers; we normalize via SHA-256 fingerprints so an attacker cannot use
 * the length-mismatch fast-path to leak the secret's length either.
 */
function safeEqualStr(a: string, b: string): boolean {
  const ha = require('crypto').createHash('sha256').update(String(a)).digest();
  const hb = require('crypto').createHash('sha256').update(String(b)).digest();
  return timingSafeEqual(ha, hb);
}
