import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { HttpModule } from '@nestjs/axios';

import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { OtpService } from './otp.service';
import { EmailService } from './email.service';
import { AppleTokenVerifier } from './apple-token-verifier.service';
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
    HttpModule.register({ timeout: 5000, maxRedirects: 2 }),
  ],
  controllers: [AuthController],
  providers: [AuthService, OtpService, EmailService, AppleTokenVerifier, JwtStrategy],
  // EmailService is consumed by the BullMQ otp:email processor (QueuesModule)
  // which imports AuthModule; export it so the DI container can wire it up.
  exports: [AuthService, OtpService, EmailService, AppleTokenVerifier, JwtModule],
})
export class AuthModule {}
