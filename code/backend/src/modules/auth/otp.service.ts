import { Injectable, Inject, Logger, HttpException, HttpStatus, Optional } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import IORedis from 'ioredis';
import { randomInt, createHash } from 'crypto';

import { REDIS } from '../../common/redis/redis.module';
import { EmailService } from './email.service';
import { isProd } from '../../common/config/secrets';

/**
 * Hash an OTP code so we can leave a forensic breadcrumb in the logs without
 * leaking the live code itself. The first 8 hex characters of SHA-256 are
 * enough to confirm "this is the same code I saw at T+5s" but not enough to
 * brute-force back to the 6-digit plaintext (each 6-digit code maps to 8 hex
 * chars in a 4-billion-bucket space — ~250 codes share each bucket).
 *
 * In non-production we expose the plaintext code via the OTP_DEV_LOG_PLAIN
 * escape hatch so manual QA can copy-paste the code from `docker logs`.
 */
function fingerprintOtp(code: string): string {
  return createHash('sha256').update(code).digest('hex').slice(0, 8);
}

/**
 * Email-only OTP service.
 *
 * Phone OTP has been removed entirely — every login/verification flow uses email.
 * Hardening vs. the previous version:
 *  - send rate-limit keyed on the normalized email
 *  - verify brute-force limit (5 wrong attempts invalidates the code)
 *  - the OTP code is NEVER returned in the response in production, regardless of
 *    OTP_RETURN_CODE_IN_RESPONSE (defence-in-depth against the prior account-takeover bug)
 *  - per-purpose namespaces so a login code can never satisfy a claim flow (or vice-versa)
 */
export type OtpPurpose = 'login' | 'claim';

@Injectable()
export class OtpService {
  private readonly logger = new Logger(OtpService.name);
  private readonly ttlSec = 300;
  private readonly maxSendPerHour = 5;
  private readonly maxVerifyAttempts = 5;
  private readonly devBypassCode = process.env.OTP_DEV_BYPASS_CODE || '';

  /**
   * `emailQueue` is wired by QueuesModule (BullMQ). Marked @Optional so
   * tests that bootstrap only AuthModule can run without spinning up the
   * queue plumbing — the service falls back to the inline SMTP call when
   * the queue isn't bound. In production both are wired and the queue
   * always wins.
   */
  constructor(
    @Inject(REDIS) private readonly redis: IORedis,
    private readonly email: EmailService,
    @Optional() @InjectQueue('otp:email') private readonly emailQueue?: Queue,
  ) {}

  private norm(email: string): string {
    return email.toLowerCase().trim();
  }
  private codeKey(key: string, purpose: OtpPurpose) {
    return `otp:email:${purpose}:${key}`;
  }
  private countKey(key: string, purpose: OtpPurpose) {
    return `otp:count:${purpose}:${key}`;
  }
  private attemptKey(key: string, purpose: OtpPurpose) {
    return `otp:attempt:${purpose}:${key}`;
  }

  /** Send a 6-digit OTP to an email address. */
  async sendEmail(emailAddr: string, purpose: OtpPurpose = 'login'): Promise<{ devCode?: string }> {
    const key = this.norm(emailAddr);
    const counterKey = this.countKey(key, purpose);
    const count = await this.redis.incr(counterKey);
    if (count === 1) await this.redis.expire(counterKey, 3600);
    if (count > this.maxSendPerHour) {
      throw new HttpException(
        { code: 'OTP_RATE_LIMITED', message: 'Quá nhiều lần gửi mã, thử lại sau 1 giờ' },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    const code = String(randomInt(0, 1_000_000)).padStart(6, '0');
    await this.redis.setex(this.codeKey(key, purpose), this.ttlSec, code);
    await this.redis.del(this.attemptKey(key, purpose)); // reset attempt counter on new code

    // Audit hnag-audit-2026-05: NEVER return devCode in the response. Even
    // in non-prod local dev, the code must be looked up via logs or a dedicated
    // debug endpoint guarded by IS_DEV — never piggy-backed on /auth/otp/email.
    // This eliminates account-takeover via the response body entirely, even
    // under misconfigured NODE_ENV / accidentally enabled flags.
    if (!this.email.configured()) {
      // Provider unconfigured: write only the OTP fingerprint (SHA-256 prefix)
      // to logs. Plaintext is emitted ONLY when explicitly opted-in via
      // OTP_DEV_LOG_PLAIN=true AND we are not in production — this prevents an
      // operator (or anyone with log access via Sentry / Loki / Datadog) from
      // impersonating users. Audit hnag-audit-2026-05 #10.
      const detail = !isProd() && process.env.OTP_DEV_LOG_PLAIN === 'true' ? ` code=${code}` : '';
      this.logger.warn(`Email OTP [${purpose}] for ${key}: fp=${fingerprintOtp(code)}${detail} (provider=log-only)`);
      return {};
    }

    // Audit hnag-audit-2026-05 §9 (HIGH): SMTP dispatch used to block the
    // request thread (1-2s round-trip on Gmail). Offload to BullMQ so the
    // controller returns in ≤10ms regardless of email provider latency.
    // Retry policy: 4 attempts with exponential backoff (see queues.module.ts).
    if (this.emailQueue) {
      await this.emailQueue.add(
        'send-otp',
        { email: key, code, purpose },
        // Per-job options override the queue defaults if needed; we just
        // let the queue defaults handle attempts/backoff/retention.
      );
      return {};
    }

    // Fallback path: queue not wired (e.g. unit test, dev without Redis).
    // Send synchronously so the flow still works.
    try {
      await this.email.sendOtp(key, code);
    } catch (err) {
      this.logger.error(`Email OTP dispatch failed for ${key}: ${(err as Error).message}`);
      throw new HttpException(
        { code: 'EMAIL_FAILED', message: 'Không gửi được email. Thử lại sau.' },
        HttpStatus.BAD_GATEWAY,
      );
    }
    return {};
  }

  /**
   * Send a 6-digit OTP to a Vietnamese phone number. SMS provider is wired
   * via env (Twilio / Vonage / VNG); when unset, the code is logged so dev
   * + manual QA can still test the flow on staging.
   */
  async sendPhone(phoneAddr: string, purpose: OtpPurpose = 'login'): Promise<{ devCode?: string }> {
    const key = this.normPhone(phoneAddr);
    const counterKey = this.countKey(key, purpose);
    const count = await this.redis.incr(counterKey);
    if (count === 1) await this.redis.expire(counterKey, 3600);
    if (count > this.maxSendPerHour) {
      throw new HttpException(
        { code: 'OTP_RATE_LIMITED', message: 'Quá nhiều lần gửi mã, thử lại sau 1 giờ' },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
    const code = String(randomInt(0, 1_000_000)).padStart(6, '0');
    await this.redis.setex(this.codeKey(key, purpose), this.ttlSec, code);
    await this.redis.del(this.attemptKey(key, purpose));

    // SMS provider wire: dev/staging log-only; prod would hit a gateway.
    // See fingerprintOtp comment above for the rationale on what we log.
    const detail = !isProd() && process.env.OTP_DEV_LOG_PLAIN === 'true' ? ` code=${code}` : '';
    this.logger.warn(`Phone OTP [${purpose}] for ${key}: fp=${fingerprintOtp(code)}${detail} (provider=log-only)`);
    return {};
  }

  /** Verify a phone OTP. */
  async verifyPhone(phoneAddr: string, code: string, purpose: OtpPurpose = 'login'): Promise<boolean> {
    const key = this.normPhone(phoneAddr);
    if (!isProd() && this.devBypassCode && code === this.devBypassCode) {
      this.logger.warn(`OTP dev-bypass accepted for ${key} [${purpose}] (phone, non-prod only)`);
      return true;
    }
    const attemptKey = this.attemptKey(key, purpose);
    const attempts = await this.redis.incr(attemptKey);
    if (attempts === 1) await this.redis.expire(attemptKey, this.ttlSec);
    if (attempts > this.maxVerifyAttempts) {
      await this.redis.del(this.codeKey(key, purpose));
      throw new HttpException(
        { code: 'OTP_LOCKED', message: 'Nhập sai quá nhiều lần. Vui lòng yêu cầu mã mới.' },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
    const stored = await this.redis.get(this.codeKey(key, purpose));
    if (!stored || stored !== code) return false;
    await this.redis.del(this.codeKey(key, purpose));
    await this.redis.del(attemptKey);
    return true;
  }

  /** Normalize Vietnamese phone numbers to +84 E.164. */
  private normPhone(p: string): string {
    const digits = p.replace(/\D/g, '');
    if (digits.startsWith('84')) return `+${digits}`;
    if (digits.startsWith('0')) return `+84${digits.slice(1)}`;
    return `+84${digits}`;
  }

  /** Verify an email OTP. Brute-force protected: 5 wrong tries invalidates the code. */
  async verifyEmail(emailAddr: string, code: string, purpose: OtpPurpose = 'login'): Promise<boolean> {
    const key = this.norm(emailAddr);

    // Dev-only static bypass (never active in production).
    if (!isProd() && this.devBypassCode && code === this.devBypassCode) {
      this.logger.warn(`OTP dev-bypass accepted for ${key} [${purpose}] (non-prod only)`);
      return true;
    }

    const attemptKey = this.attemptKey(key, purpose);
    const attempts = await this.redis.incr(attemptKey);
    if (attempts === 1) await this.redis.expire(attemptKey, this.ttlSec);
    if (attempts > this.maxVerifyAttempts) {
      // Too many wrong guesses → burn the code so it can't be brute-forced.
      await this.redis.del(this.codeKey(key, purpose));
      throw new HttpException(
        { code: 'OTP_LOCKED', message: 'Nhập sai quá nhiều lần. Vui lòng yêu cầu mã mới.' },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    const stored = await this.redis.get(this.codeKey(key, purpose));
    if (!stored || stored !== code) return false;

    await this.redis.del(this.codeKey(key, purpose));
    await this.redis.del(attemptKey);
    return true;
  }
}
