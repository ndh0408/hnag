import { Injectable, BadRequestException, ForbiddenException, Logger } from '@nestjs/common';
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
      return this.activate(userId, 'trial', 'trial', { trialDays: 7 });
    }

    // VietQR — works with a personal bank account, no business needed.
    const bankBin = process.env.VIETQR_BANK_BIN;        // e.g. 970436 (Vietcombank)
    const accountNo = process.env.VIETQR_ACCOUNT_NO;    // personal account number
    const accountName = process.env.VIETQR_ACCOUNT_NAME ?? 'HNAG';

    // Unique short memo so an incoming transfer can be matched to this user+plan.
    const memo = `HNAG ${plan.toUpperCase().slice(0, 3)} ${userId.replace(/-/g, '').slice(0, 8)}`.toUpperCase();

    const rows: any[] = await this.prisma.$queryRawUnsafe(
      `INSERT INTO subscriptions (user_id, plan, provider, amount_vnd, status)
       VALUES ($1::uuid, $2, $3, $4, 'trialing'::subscription_status) RETURNING id`,
      userId, plan, 'vietqr', def.priceVnd,
    );
    const subId = rows[0]?.id;

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
   * SePay webhook — called when money arrives in the personal bank account.
   * Matches the transfer memo to a pending subscription and activates premium.
   * Secured by SEPAY_WEBHOOK_TOKEN.
   */
  async handleSepayWebhook(payload: any, authToken?: string): Promise<{ ok: boolean; matched?: boolean }> {
    const expected = process.env.SEPAY_WEBHOOK_TOKEN;
    if (expected && authToken !== expected) throw new ForbiddenException('Invalid webhook token');

    const content: string = (payload?.content ?? payload?.description ?? '').toString().toUpperCase();
    const amount: number = Number(payload?.transferAmount ?? payload?.amount ?? 0);
    // Memo format: "HNAG <PLAN3> <USER8>"
    const m = content.match(/HNAG\s+([A-Z]{3})\s+([A-Z0-9]{8})/);
    if (!m) {
      this.logger.warn(`SePay webhook: no HNAG memo in "${content}"`);
      return { ok: true, matched: false };
    }
    const userPrefix = m[2].toLowerCase();
    // Find the user whose id (dashless) starts with prefix and has a pending vietqr sub
    const subs: any[] = await this.prisma.$queryRawUnsafe(
      `SELECT s.id, s.user_id, s.plan::text AS plan, s.amount_vnd
       FROM subscriptions s
       WHERE s.provider = 'vietqr' AND s.status = 'trialing'
         AND replace(s.user_id::text, '-', '') LIKE $1
       ORDER BY s.created_at DESC LIMIT 1`,
      `${userPrefix}%`,
    );
    if (subs.length === 0) {
      this.logger.warn(`SePay webhook: no pending sub for prefix ${userPrefix}`);
      return { ok: true, matched: false };
    }
    const sub = subs[0];
    if (amount > 0 && amount < sub.amount_vnd) {
      this.logger.warn(`SePay webhook: amount ${amount} < required ${sub.amount_vnd}`);
      return { ok: true, matched: false };
    }
    const months = sub.plan === 'yearly' ? 12 : sub.plan === 'family_yearly' ? 12 : 1;
    await this.activate(sub.user_id, sub.plan, 'vietqr', { months });
    this.logger.log(`SePay: activated premium for user ${sub.user_id} (${sub.plan})`);
    return { ok: true, matched: true };
  }

  /**
   * Redeem a promo code → grant Premium. Codes live in env PROMO_CODES as
   * "CODE:plan:months" comma-separated, e.g. "BETA2026:yearly:12,VIP:monthly:1".
   */
  async redeemPromo(userId: string, code: string) {
    const raw = process.env.PROMO_CODES ?? 'BETA2026:yearly:12,HNAGVIP:monthly:1';
    const entries = raw.split(',').map(s => s.trim()).filter(Boolean);
    const match = entries.find(e => e.split(':')[0].toUpperCase() === code.trim().toUpperCase());
    if (!match) throw new BadRequestException('Mã không hợp lệ hoặc đã hết hạn');
    const [, plan, monthsStr] = match.split(':');
    const months = parseInt(monthsStr) || 1;
    this.logger.log(`Promo ${code} redeemed by ${userId} → ${plan} ${months}m`);
    return this.activate(userId, (plan as keyof typeof PLANS) ?? 'monthly', 'promo', { months });
  }

  async myStatus(userId: string) {
    const user = await this.prisma.users.findUnique({
      where: { id: userId },
      select: { is_premium: true, premium_until: true },
    });
    const subs: any[] = await this.prisma.$queryRawUnsafe(
      `SELECT id, plan::text AS plan, provider, amount_vnd, status::text AS status,
              trial_ends_at, current_period_end, created_at
       FROM subscriptions WHERE user_id = $1::uuid ORDER BY created_at DESC LIMIT 1`,
      userId,
    );
    return {
      isPremium: user?.is_premium ?? false,
      premiumUntil: user?.premium_until ?? null,
      subscription: subs[0] ?? null,
    };
  }

  private async activate(userId: string, plan: keyof typeof PLANS, provider: string, opts: { months?: number; trialDays?: number }) {
    const now = Date.now();
    const until = opts.trialDays
      ? new Date(now + opts.trialDays * 24 * 3600 * 1000)
      : new Date(now + (opts.months ?? 1) * 30 * 24 * 3600 * 1000);
    const status = opts.trialDays ? 'trialing' : 'active';
    const amount = PLANS[plan]?.priceVnd ?? 0;

    // Raw SQL to avoid Prisma enum mapping mismatch on partial schema.
    const rows: any[] = await this.prisma.$queryRawUnsafe(
      `INSERT INTO subscriptions (user_id, plan, provider, amount_vnd, status, trial_ends_at, current_period_end)
       VALUES ($1::uuid, $2, $3, $4, $5::subscription_status, $6, $7)
       RETURNING id`,
      userId, plan, provider, amount, status,
      opts.trialDays ? until : null, until,
    );
    await this.prisma.$executeRawUnsafe(
      `UPDATE users SET is_premium = true, premium_until = $2 WHERE id = $1::uuid`,
      userId, until,
    );
    return { status, isPremium: true, premiumUntil: until, subscriptionId: rows[0]?.id };
  }
}
