import { Body, Controller, HttpCode, Post } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { ApiTags } from '@nestjs/swagger';
import { z } from 'zod';
import { AuthService } from './auth.service';
import { OtpService } from './otp.service';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';

const SendOtpDto = z.object({
  phone: z.string().regex(/^\+?[0-9]{9,15}$/),
});

const VerifyOtpDto = z.object({
  phone: z.string(),
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

@ApiTags('Auth')
@Controller('auth')
export class AuthController {
  constructor(
    private readonly auth: AuthService,
    private readonly otp: OtpService,
  ) {}

  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Post('otp/send')
  @HttpCode(200)
  async sendOtp(@Body(new ZodValidationPipe(SendOtpDto)) body: z.infer<typeof SendOtpDto>) {
    const out = await this.otp.send(body.phone);
    return { sent: true, ...(out.devCode ? { devCode: out.devCode } : {}) };
  }

  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('otp/verify')
  @HttpCode(200)
  async verifyOtp(@Body(new ZodValidationPipe(VerifyOtpDto)) body: z.infer<typeof VerifyOtpDto>) {
    const verified = await this.otp.verify(body.phone, body.code);
    if (!verified) throw new InvalidOtpException();
    return this.auth.signInWithPhone(body.phone, body.device);
  }

  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Post('email-otp/send')
  @HttpCode(200)
  async sendEmailOtp(@Body(new ZodValidationPipe(SendEmailOtpDto)) body: z.infer<typeof SendEmailOtpDto>) {
    const out = await this.otp.sendEmail(body.email);
    return { sent: true, ...(out.devCode ? { devCode: out.devCode } : {}) };
  }

  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('email-otp/verify')
  @HttpCode(200)
  async verifyEmailOtp(@Body(new ZodValidationPipe(VerifyEmailOtpDto)) body: z.infer<typeof VerifyEmailOtpDto>) {
    const verified = await this.otp.verifyEmail(body.email, body.code);
    if (!verified) throw new InvalidOtpException();
    return this.auth.signInWithEmail(body.email, body.device);
  }

  @Post('refresh')
  @HttpCode(200)
  async refresh(@Body(new ZodValidationPipe(RefreshDto)) body: z.infer<typeof RefreshDto>) {
    return this.auth.refresh(body.refreshToken);
  }
}

import { HttpException, HttpStatus } from '@nestjs/common';
class InvalidOtpException extends HttpException {
  constructor() {
    super(
      { code: 'INVALID_OTP', message: 'Mã OTP không đúng hoặc hết hạn' },
      HttpStatus.UNAUTHORIZED,
    );
  }
}
