import { Body, Controller, Headers, HttpCode, Ip, Post, HttpException, HttpStatus } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { ApiTags } from '@nestjs/swagger';
import { z } from 'zod';
import { AuthService } from './auth.service';
import { OtpService } from './otp.service';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import { AnalyticsService } from '../../common/analytics/analytics.service';
import { createHash } from 'crypto';

// Audit #33: device DTO had no max() on optional strings. Centralise + bound.
const DeviceInfoDto = z.object({
  deviceId: z.string().min(8).max(128),
  platform: z.enum(['ios', 'android', 'web']),
  appVersion: z.string().max(32).optional(),
  osVersion: z.string().max(64).optional(),
  pushToken: z.string().max(512).optional(),
  locale: z.string().max(16).optional(),
});

// Email + phone OTP. Apple SSO via identity-token validation.
const SendEmailOtpDto = z.object({
  email: z.string().email().max(254),
});

const VerifyEmailOtpDto = z.object({
  email: z.string().email().max(254),
  code: z.string().length(6).regex(/^\d{6}$/),
  device: DeviceInfoDto.optional(),
});

const SendPhoneOtpDto = z.object({
  phone: z.string().min(9).max(13),
});

const VerifyPhoneOtpDto = z.object({
  phone: z.string().min(9).max(13),
  code: z.string().length(6).regex(/^\d{6}$/),
  device: DeviceInfoDto.optional(),
});

const AppleSignInDto = z.object({
  identityToken: z.string().min(20).max(4096),
  authorizationCode: z.string().max(2048).optional(),
  fullName: z.string().max(120).optional(),
  email: z.string().email().max(254).optional(),
  device: DeviceInfoDto.optional(),
});

const RefreshDto = z.object({
  refreshToken: z.string().min(20).max(256),
});

@ApiTags('Auth')
@Controller('auth')
export class AuthController {
  constructor(
    private readonly auth: AuthService,
    private readonly otp: OtpService,
    private readonly analytics: AnalyticsService,
  ) {}

  private hashEmail(email: string): string {
    return createHash('sha256').update(email.toLowerCase().trim()).digest('hex').slice(0, 16);
  }

  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Post('email-otp/send')
  @HttpCode(200)
  async sendEmailOtp(
    @Body(new ZodValidationPipe(SendEmailOtpDto)) body: z.infer<typeof SendEmailOtpDto>,
    @Ip() ip: string,
  ) {
    // SECURITY (audit hnag-audit-2026-05): never spread `out` into the
    // response — `devCode` MUST NOT appear in the body under any environment.
    await this.otp.sendEmail(body.email, 'login', { ip });
    // Analytics: email hashed so log retention satisfies PDPL.
    this.analytics.track({
      event: 'auth:otp_send',
      properties: { method: 'email', emailHash: this.hashEmail(body.email), ipHash: this.hashEmail(ip ?? '') },
    });
    return { sent: true };
  }

  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('email-otp/verify')
  @HttpCode(200)
  async verifyEmailOtp(
    @Body(new ZodValidationPipe(VerifyEmailOtpDto)) body: z.infer<typeof VerifyEmailOtpDto>,
    @Ip() ip: string,
    @Headers('user-agent') userAgent?: string,
  ) {
    const verified = await this.otp.verifyEmail(body.email, body.code, 'login', { ip });
    if (!verified) {
      this.analytics.track({
        event: 'auth:otp_verify',
        properties: { method: 'email', success: false, reason: 'invalid' },
      });
      throw new InvalidOtpException();
    }
    const session = await this.auth.signInWithEmail(body.email, body.device, { ip, userAgent });
    this.analytics.track({
      event: 'auth:otp_verify',
      userId: session.user.id,
      properties: { method: 'email', success: true },
    });
    return session;
  }

  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @Post('refresh')
  @HttpCode(200)
  async refresh(
    @Body(new ZodValidationPipe(RefreshDto)) body: z.infer<typeof RefreshDto>,
    @Ip() ip: string,
    @Headers('user-agent') userAgent?: string,
  ) {
    return this.auth.refresh(body.refreshToken, { ip, userAgent });
  }

  // ─── Phone OTP ─────────────────────────────────────────────────────
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Post('phone-otp/send')
  @HttpCode(200)
  async sendPhoneOtp(
    @Body(new ZodValidationPipe(SendPhoneOtpDto)) body: z.infer<typeof SendPhoneOtpDto>,
    @Ip() ip: string,
  ) {
    await this.otp.sendPhone(body.phone, 'login', { ip });
    return { sent: true };
  }

  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('phone-otp/verify')
  @HttpCode(200)
  async verifyPhoneOtp(
    @Body(new ZodValidationPipe(VerifyPhoneOtpDto)) body: z.infer<typeof VerifyPhoneOtpDto>,
    @Ip() ip: string,
    @Headers('user-agent') userAgent?: string,
  ) {
    const verified = await this.otp.verifyPhone(body.phone, body.code, 'login', { ip });
    if (!verified) throw new InvalidOtpException();
    return this.auth.signInWithPhone(body.phone, body.device, { ip, userAgent });
  }

  // ─── Apple SSO ─────────────────────────────────────────────────────
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Post('apple')
  @HttpCode(200)
  async appleSignIn(
    @Body(new ZodValidationPipe(AppleSignInDto)) body: z.infer<typeof AppleSignInDto>,
    @Ip() ip: string,
    @Headers('user-agent') userAgent?: string,
  ) {
    return this.auth.signInWithApple({ ...body, audit: { ip, userAgent } });
  }
}

class InvalidOtpException extends HttpException {
  constructor() {
    super(
      { code: 'INVALID_OTP', message: 'Mã OTP không đúng hoặc hết hạn' },
      HttpStatus.UNAUTHORIZED,
    );
  }
}
