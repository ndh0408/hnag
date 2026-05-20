import { Injectable, Inject, Logger, HttpException, HttpStatus } from '@nestjs/common';
import IORedis from 'ioredis';
import { randomInt } from 'crypto';

import { REDIS } from '../../common/redis/redis.module';
import { SmsService } from './sms.service';
import { EmailService } from './email.service';

@Injectable()
export class OtpService {
  private readonly logger = new Logger(OtpService.name);
  private readonly ttlSec = 300;
  private readonly maxSendPerHour = 5;
  private readonly devBypassCode = process.env.OTP_DEV_BYPASS_CODE || '';

  constructor(
    @Inject(REDIS) private readonly redis: IORedis,
    private readonly sms: SmsService,
    private readonly email: EmailService,
  ) {}

  async sendEmail(emailAddr: string): Promise<{ devCode?: string }> {
    const key = emailAddr.toLowerCase().trim();
    const counterKey = `otp:count:${key}`;
    const count = await this.redis.incr(counterKey);
    if (count === 1) await this.redis.expire(counterKey, 3600);
    if (count > this.maxSendPerHour) {
      throw new HttpException(
        { code: 'OTP_RATE_LIMITED', message: 'Quá nhiều lần gửi mã, thử lại sau 1 giờ' },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
    const code = String(randomInt(0, 1_000_000)).padStart(6, '0');
    await this.redis.setex(`otp:email:${key}`, this.ttlSec, code);

    if (!this.email.configured()) {
      this.logger.warn(`Email OTP for ${key}: ${code} (provider=log-only)`);
      return process.env.OTP_RETURN_CODE_IN_RESPONSE === '1' ? { devCode: code } : {};
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

  async verifyEmail(emailAddr: string, code: string): Promise<boolean> {
    const key = emailAddr.toLowerCase().trim();
    if (this.devBypassCode && code === this.devBypassCode) return true;
    const stored = await this.redis.get(`otp:email:${key}`);
    if (!stored || stored !== code) return false;
    await this.redis.del(`otp:email:${key}`);
    return true;
  }

  async send(phone: string): Promise<{ devCode?: string }> {
    const counterKey = `otp:count:${phone}`;
    const count = await this.redis.incr(counterKey);
    if (count === 1) await this.redis.expire(counterKey, 3600);
    if (count > this.maxSendPerHour) {
      throw new HttpException(
        { code: 'OTP_RATE_LIMITED', message: 'Quá nhiều lần gửi mã, thử lại sau 1 giờ' },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    const code = String(randomInt(0, 1_000_000)).padStart(6, '0');
    await this.redis.setex(`otp:${phone}`, this.ttlSec, code);

    const body = `Ma HNAG: ${code}. Hieu luc 5 phut. Khong chia se voi nguoi khac.`;
    const providerIsLog = this.sms.providerName() === 'log-only';

    if (providerIsLog) {
      this.logger.warn(`OTP for ${phone}: ${code} (provider=log-only, no real SMS sent)`);
      return process.env.OTP_RETURN_CODE_IN_RESPONSE === '1' ? { devCode: code } : {};
    }

    try {
      await this.sms.send(phone, body);
    } catch (err) {
      this.logger.error(`SMS dispatch failed for ${phone}: ${(err as Error).message}`);
      throw new HttpException(
        { code: 'SMS_FAILED', message: 'Không gửi được SMS. Vui lòng thử lại.' },
        HttpStatus.BAD_GATEWAY,
      );
    }
    return {};
  }

  async verify(phone: string, code: string): Promise<boolean> {
    if (this.devBypassCode && code === this.devBypassCode) {
      this.logger.warn(`OTP dev-bypass accepted for ${phone}`);
      return true;
    }
    const stored = await this.redis.get(`otp:${phone}`);
    if (!stored || stored !== code) return false;
    await this.redis.del(`otp:${phone}`);
    return true;
  }
}
