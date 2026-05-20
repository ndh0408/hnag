import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';

import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { OtpService } from './otp.service';
import { SmsService } from './sms.service';
import { EmailService } from './email.service';
import { JwtStrategy } from './strategies/jwt.strategy';

@Module({
  imports: [
    PassportModule.register({ defaultStrategy: 'jwt' }),
    JwtModule.register({
      secret: process.env.JWT_SECRET ?? 'dev-secret',
      signOptions: { expiresIn: '15m', issuer: 'tothanhthuy.cloud' },
    }),
  ],
  controllers: [AuthController],
  providers: [AuthService, OtpService, SmsService, EmailService, JwtStrategy],
  exports: [AuthService, OtpService, JwtModule],
})
export class AuthModule {}
