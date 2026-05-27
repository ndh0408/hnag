import { Body, Controller, Headers, HttpCode, Ip, Post, HttpException, HttpStatus } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { ApiTags } from '@nestjs/swagger';
import { z } from 'zod';
import { AuthService } from './auth.service';
import { OtpService } from './otp.service';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import { AnalyticsService } from '../../common/analytics/analytics.service';
import { createHash } from 'crypto';

// Email + phone OTP. Apple SSO via identity-token validation.
const SendEmailOtpDto = z.object({
  email: z.string().email(),
});

const VerifyEmailOtpDto = z.object({
  email: z.string().email(),
  code: z.string().length(6),
  device: z.object({
    deviceId: z.string(),
    platform: z.enum(['ios', 'android', 'web']),
    appVersion: z.string().optional(),
    osVersion: z.string().optional(),
    pushToken: z.string().optional(),
    locale: z.string().optional(),
  }).optional(),
});

const SendPhoneOtpDto = z.object({
  phone: z.string().min(9).max(13),
});

const VerifyPhoneOtpDto = z.object({
  phone: z.string().min(9).max(13),
  code: z.string().length(6),
  device: z.object({
    deviceId: z.string(),
    platform: z.enum(['ios', 'android', 'web']),
    appVersion: z.string().optional(),
    osVersion: z.string().optional(),
    pushToken: z.string().optional(),
    locale: z.string().optional(),
  }).optional(),
});

const AppleSignInDto = z.object({
  identityToken: z.string().min(20),
  authorizationCode: z.string().optional(),
  fullName: z.string().optional(),
  email: z.string().email().optional(),
  device: z.object({
    deviceId: z.string(),
    platform: z.enum(['ios', 'android', 'web']),
    appVersion: z.string().optional(),
    osVersion: z.string().optional(),
    pushToken: z.string().optional(),
    locale: z.string().optional(),
  }).optional(),
});

const RefreshDto = z.object({
  refreshToken: z.string(),
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
    await this.otp.sendEmail(body.email, 'login');
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
  async verifyEmailOtp(@Body(new ZodValidationPipe(VerifyEmailOtpDto)) body: z.infer<typeof VerifyEmailOtpDto>) {
    const verified = await this.otp.verifyEmail(body.email, body.code, 'login');
    if (!verified) {
      this.analytics.track({
        event: 'auth:otp_verify',
        properties: { method: 'email', success: false, reason: 'invalid' },
      });
      throw new InvalidOtpException();
    }
    const session = await this.auth.signInWithEmail(body.email, body.device);
    this.analytics.track({
      event: 'auth:otp_verify',
      userId: session.user.id,
      properties: { method: 'email', success: true },
    });
    return session;
  }

  @Post('refresh')
  @HttpCode(200)
  async refresh(@Body(new ZodValidationPipe(RefreshDto)) body: z.infer<typeof RefreshDto>) {
    return this.auth.refresh(body.refreshToken);
  }

  // ─── Phone OTP ─────────────────────────────────────────────────────
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Post('phone-otp/send')
  @HttpCode(200)
  async sendPhoneOtp(@Body(new ZodValidationPipe(SendPhoneOtpDto)) body: z.infer<typeof SendPhoneOtpDto>) {
    await this.otp.sendPhone(body.phone, 'login');
    return { sent: true };
  }

  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('phone-otp/verify')
  @HttpCode(200)
  async verifyPhoneOtp(@Body(new ZodValidationPipe(VerifyPhoneOtpDto)) body: z.infer<typeof VerifyPhoneOtpDto>) {
    const verified = await this.otp.verifyPhone(body.phone, body.code, 'login');
    if (!verified) throw new InvalidOtpException();
    return this.auth.signInWithPhone(body.phone, body.device);
  }

  // ─── Apple SSO ─────────────────────────────────────────────────────
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Post('apple')
  @HttpCode(200)
  async appleSignIn(@Body(new ZodValidationPipe(AppleSignInDto)) body: z.infer<typeof AppleSignInDto>) {
    return this.auth.signInWithApple(body);
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
