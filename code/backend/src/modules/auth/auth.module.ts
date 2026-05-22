import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';

import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { OtpService } from './otp.service';
import { EmailService } from './email.service';
import { JwtStrategy } from './strategies/jwt.strategy';
import { getJwtSecret } from '../../common/config/secrets';

@Module({
  imports: [
    PassportModule.register({ defaultStrategy: 'jwt' }),
    JwtModule.register({
      // Fail-fast on a missing/weak secret in production (see secrets.ts).
      secret: getJwtSecret(),
      signOptions: { expiresIn: '15m', issuer: 'tothanhthuy.cloud' },
    }),
  ],
  controllers: [AuthController],
  // Email-only auth: SmsService removed (phone OTP is no longer supported).
  providers: [AuthService, OtpService, EmailService, JwtStrategy],
  exports: [AuthService, OtpService, JwtModule],
})
export class AuthModule {}
