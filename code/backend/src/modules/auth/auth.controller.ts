import { Body, Controller, HttpCode, Post, HttpException, HttpStatus } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { ApiTags } from '@nestjs/swagger';
import { z } from 'zod';
import { AuthService } from './auth.service';
import { OtpService } from './otp.service';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';

// Email-only auth. Phone OTP has been removed.
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

const RefreshDto = z.object({
  refreshToken: z.string(),
});

@ApiTags('Auth')
@Controller('auth')
export class AuthController {
  constructor(
    private readonly auth: AuthService,
    private readonly otp: OtpService,
  ) {}

  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Post('email-otp/send')
  @HttpCode(200)
  async sendEmailOtp(@Body(new ZodValidationPipe(SendEmailOtpDto)) body: z.infer<typeof SendEmailOtpDto>) {
    const out = await this.otp.sendEmail(body.email, 'login');
    return { sent: true, ...(out.devCode ? { devCode: out.devCode } : {}) };
  }

  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('email-otp/verify')
  @HttpCode(200)
  async verifyEmailOtp(@Body(new ZodValidationPipe(VerifyEmailOtpDto)) body: z.infer<typeof VerifyEmailOtpDto>) {
    const verified = await this.otp.verifyEmail(body.email, body.code, 'login');
    if (!verified) throw new InvalidOtpException();
    return this.auth.signInWithEmail(body.email, body.device);
  }

  @Post('refresh')
  @HttpCode(200)
  async refresh(@Body(new ZodValidationPipe(RefreshDto)) body: z.infer<typeof RefreshDto>) {
    return this.auth.refresh(body.refreshToken);
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
