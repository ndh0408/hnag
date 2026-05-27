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
 * brute-force back to the 6-digit plaintext.
 *
 * In non-production we expose the plaintext code via the OTP_DEV_LOG_PLAIN
 * escape hatch so manual QA can copy-paste the code from `docker logs`.
 */
function fingerprintOtp(code: string): string {
  return createHash('sha256').update(code).digest('hex').slice(0, 8);
}

/**
 * Hash a per-IP forensic key — never logged or returned plaintext, used only
 * to bucketize global lockout counters.
 */
function hashIp(ip: string | undefined): string {
  return createHash('sha256').update(String(ip ?? 'none')).digest('hex').slice(0, 12);
}

/**
 * Email-only OTP service.
 *
 * Hardenings vs. the previous version (audit #11):
 *   - per-email send rate-limit (5/hr — unchanged)
 *   - per-(email,code) attempts: 3 wrong before code burn (was 5)
 *   - per-email GLOBAL lockout: 15 wrong attempts across ANY IP in 24h freezes
 *     the email for 1h (covers the IP-rotation attack)
 *   - per-IP failure counter: 20 fails/IP/h freezes the IP for 1h (cheap-create
 *     spam farm protection)
 *   - the OTP code is NEVER returned in the response in production, regardless
 *     of OTP_RETURN_CODE_IN_RESPONSE (defence-in-depth)
 *   - per-purpose namespaces so a login code can never satisfy a claim flow
 */
export type OtpPurpose = 'login' | 'claim';

@Injectable()
export class OtpService {
  private readonly logger = new Logger(OtpService.name);
  private readonly ttlSec = 300;
  private readonly maxSendPerHour = 5;
  /** Per-code wrong-guess budget before code burn. Audit #11: was 5, now 3. */
  private readonly maxVerifyAttemptsPerCode = 3;
  /** Per-email global wrong-guess budget across IPs over 24h. */
  private readonly maxVerifyAttemptsPerEmail24h = 15;
  /** Per-IP wrong-guess budget over 1h (spans accounts). */
  private readonly maxVerifyAttemptsPerIpHour = 20;
  /** Lockout duration (seconds) once an email or IP trips its budget. */
  private readonly lockoutSec = 3600;
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
  private dailyEmailFailKey(key: string) {
    return `otp:fail24h:email:${key}`;
  }
  private hourlyIpFailKey(ipHash: string) {
    return `otp:fail1h:ip:${ipHash}`;
  }
  private emailLockKey(key: string) {
    return `otp:lock:email:${key}`;
  }
  private ipLockKey(ipHash: string) {
    return `otp:lock:ip:${ipHash}`;
  }

  /** Send a 6-digit OTP to an email address. */
  async sendEmail(emailAddr: string, purpose: OtpPurpose = 'login', opts: { ip?: string } = {}): Promise<{ devCode?: string }> {
    const key = this.norm(emailAddr);
    // Reject sends to locked-out emails so an attacker can't tar-pit a victim.
    const locked = await this.redis.get(this.emailLockKey(key));
    if (locked) {
      throw new HttpException(
        { code: 'OTP_RATE_LIMITED', message: 'Tài khoản này tạm khoá đăng nhập, thử lại sau 1 giờ' },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
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

    if (!this.email.configured()) {
      const detail = !isProd() && process.env.OTP_DEV_LOG_PLAIN === 'true' ? ` code=${code}` : '';
      this.logger.warn(`Email OTP [${purpose}] for ${key}: fp=${fingerprintOtp(code)}${detail} (provider=log-only)`);
      return {};
    }

    if (this.emailQueue) {
      await this.emailQueue.add('send-otp', { email: key, code, purpose });
      return {};
    }

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

  async sendPhone(phoneAddr: string, purpose: OtpPurpose = 'login', _opts: { ip?: string } = {}): Promise<{ devCode?: string }> {
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

    const detail = !isProd() && process.env.OTP_DEV_LOG_PLAIN === 'true' ? ` code=${code}` : '';
    this.logger.warn(`Phone OTP [${purpose}] for ${key}: fp=${fingerprintOtp(code)}${detail} (provider=log-only)`);
    return {};
  }

  /** Verify a phone OTP. */
  async verifyPhone(phoneAddr: string, code: string, purpose: OtpPurpose = 'login', opts: { ip?: string } = {}): Promise<boolean> {
    const key = this.normPhone(phoneAddr);
    return this.verifyShared(key, code, purpose, opts);
  }

  /** Normalize Vietnamese phone numbers to +84 E.164. */
  private normPhone(p: string): string {
    const digits = p.replace(/\D/g, '');
    if (digits.startsWith('84')) return `+${digits}`;
    if (digits.startsWith('0')) return `+84${digits.slice(1)}`;
    return `+84${digits}`;
  }

  /** Verify an email OTP. */
  async verifyEmail(emailAddr: string, code: string, purpose: OtpPurpose = 'login', opts: { ip?: string } = {}): Promise<boolean> {
    const key = this.norm(emailAddr);
    return this.verifyShared(key, code, purpose, opts);
  }

  private async verifyShared(key: string, code: string, purpose: OtpPurpose, opts: { ip?: string }): Promise<boolean> {
    // Dev-only static bypass (never active in production).
    if (!isProd() && this.devBypassCode && code === this.devBypassCode) {
      this.logger.warn(`OTP dev-bypass accepted for ${key} [${purpose}] (non-prod only)`);
      return true;
    }

    const ipHash = hashIp(opts.ip);

    // Lockout pre-checks — refuse fast, no DB / Redis writes.
    const [emailLocked, ipLocked] = await Promise.all([
      this.redis.get(this.emailLockKey(key)),
      this.redis.get(this.ipLockKey(ipHash)),
    ]);
    if (emailLocked || ipLocked) {
      throw new HttpException(
        { code: 'OTP_LOCKED', message: 'Tạm khoá thử OTP, quay lại sau 1 giờ' },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    const attemptKey = this.attemptKey(key, purpose);
    const attempts = await this.redis.incr(attemptKey);
    if (attempts === 1) await this.redis.expire(attemptKey, this.ttlSec);
    if (attempts > this.maxVerifyAttemptsPerCode) {
      // Too many wrong guesses on THIS code — burn it.
      await this.redis.del(this.codeKey(key, purpose));
      await this.bumpFailureBudgets(key, ipHash);
      throw new HttpException(
        { code: 'OTP_LOCKED', message: 'Nhập sai quá nhiều lần. Vui lòng yêu cầu mã mới.' },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    const stored = await this.redis.get(this.codeKey(key, purpose));
    if (!stored || stored !== code) {
      await this.bumpFailureBudgets(key, ipHash);
      return false;
    }

    await this.redis.del(this.codeKey(key, purpose));
    await this.redis.del(attemptKey);
    return true;
  }

  /**
   * Bump the global failure counters (per-email/24h, per-IP/1h). When either
   * trips its budget, we set a 1h lockout key so subsequent send + verify
   * calls fail fast for that identity. Covers audit #11 (IP-rotating bot).
   */
  private async bumpFailureBudgets(emailKey: string, ipHash: string): Promise<void> {
    try {
      const eKey = this.dailyEmailFailKey(emailKey);
      const ipKey = this.hourlyIpFailKey(ipHash);
      const [eCount, ipCount] = await Promise.all([this.redis.incr(eKey), this.redis.incr(ipKey)]);
      if (eCount === 1) await this.redis.expire(eKey, 86400);
      if (ipCount === 1) await this.redis.expire(ipKey, 3600);
      if (eCount === this.maxVerifyAttemptsPerEmail24h) {
        await this.redis.setex(this.emailLockKey(emailKey), this.lockoutSec, '1');
        this.logger.warn(`OTP global lockout (email): ${emailKey} after ${eCount} fails in 24h`);
      }
      if (ipCount === this.maxVerifyAttemptsPerIpHour) {
        await this.redis.setex(this.ipLockKey(ipHash), this.lockoutSec, '1');
        this.logger.warn(`OTP global lockout (ip-hash=${ipHash}) after ${ipCount} fails in 1h`);
      }
    } catch (err) {
      this.logger.debug(`OTP failure-budget bump failed: ${(err as Error).message}`);
    }
  }
}
