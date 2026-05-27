import { Injectable, Inject, UnauthorizedException, Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { randomBytes, createHash } from 'crypto';
import IORedis from 'ioredis';

import { PrismaService } from '../../common/prisma/prisma.service';
import { REDIS } from '../../common/redis/redis.module';
import { AppleTokenVerifier } from './apple-token-verifier.service';

interface DeviceInfo {
  deviceId: string;
  platform: 'ios' | 'android' | 'web';
  appVersion?: string;
  osVersion?: string;
  pushToken?: string;
  locale?: string;
}

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);
  // iOS bundle id used as the expected `aud` claim on Apple identityTokens.
  // Falls back to the real bundle (memory hnag-static-file-hosting: vn.hnag.hnag).
  // Override per environment via APPLE_BUNDLE_ID if you ship multiple variants.
  private readonly appleAudience = process.env.APPLE_BUNDLE_ID || 'vn.hnag.hnag';

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    @Inject(REDIS) private readonly redis: IORedis,
    private readonly appleVerifier: AppleTokenVerifier,
  ) {}

  async signInWithEmail(email: string, device?: DeviceInfo) {
    const key = email.toLowerCase().trim();
    const user = await this.prisma.users.upsert({
      where: { email: key },
      update: { last_seen_at: new Date() },
      create: {
        email: key,
        username: await this.generateUsername(),
        display_name: key.split('@')[0],
        language: 'vi',
      },
    });
    if (device) {
      await this.prisma.user_devices.upsert({
        where: { device_id: device.deviceId },
        update: {
          user_id: user.id, platform: device.platform, app_version: device.appVersion,
          os_version: device.osVersion, push_token: device.pushToken, locale: device.locale,
          last_active_at: new Date(),
        },
        create: {
          user_id: user.id, device_id: device.deviceId, platform: device.platform,
          app_version: device.appVersion, os_version: device.osVersion,
          push_token: device.pushToken, locale: device.locale,
        },
      });
    }
    return this.issueTokens(user);
  }

  async signInWithPhone(phone: string, device?: DeviceInfo) {
    const e164 = this.normPhone(phone);
    const user = await this.prisma.users.upsert({
      where: { phone: e164 },
      update: { last_seen_at: new Date() },
      create: {
        phone: e164,
        username: await this.generateUsername(),
        display_name: 'Foodie',
        language: 'vi',
      },
    });
    if (device) await this.upsertDevice(user.id, device);
    return this.issueTokens(user);
  }

  /**
   * Apple SSO. Cryptographically verifies the identityToken signature against
   * Apple's published JWKS before trusting any claim, then upserts the user
   * and returns session tokens.
   *
   * Audit hnag-audit-2026-05 / 2026-05-27: prior implementation only decoded
   * the payload and trusted `sub` over HTTPS — an attacker could forge a
   * token with any `sub` and silently impersonate any Apple-linked user.
   */
  async signInWithApple(payload: { identityToken: string; authorizationCode?: string; fullName?: string; email?: string; device?: DeviceInfo }) {
    const claims = await this.appleVerifier.verify(payload.identityToken, this.appleAudience);

    const sub = claims.sub;
    // Prefer the email proven by Apple inside the verified token over whatever
    // the client claims in the request body — clients can lie, JWT claims can't
    // (now that the signature is checked).
    const verifiedEmail = typeof claims.email === 'string' ? claims.email.toLowerCase() : undefined;
    const clientClaimedEmail = payload.email?.toLowerCase();
    const email = verifiedEmail ?? clientClaimedEmail;

    // Apple's `sub` is the stable subject. Schema doesn't yet have an
    // apple_sub column, so we map Apple users to a synthetic email of
    // shape `apple+{sub}@hnag.internal` when no real email is shared. If
    // Apple did share a real email, use that. (Migration to a dedicated
    // apple_sub column is tracked separately.)
    const keyEmail = email ?? `apple+${sub}@hnag.internal`;
    const user = await this.prisma.users.upsert({
      where: { email: keyEmail },
      update: { last_seen_at: new Date() },
      create: {
        email: keyEmail,
        username: await this.generateUsername(),
        display_name: payload.fullName?.trim() || (email ? email.split('@')[0] : 'Apple Foodie'),
        language: 'vi',
      },
    });
    if (payload.device) await this.upsertDevice(user.id, payload.device);
    return this.issueTokens(user);
  }

  private async upsertDevice(userId: string, device: DeviceInfo) {
    await this.prisma.user_devices.upsert({
      where: { device_id: device.deviceId },
      update: {
        user_id: userId, platform: device.platform, app_version: device.appVersion,
        os_version: device.osVersion, push_token: device.pushToken, locale: device.locale,
        last_active_at: new Date(),
      },
      create: {
        user_id: userId, device_id: device.deviceId, platform: device.platform,
        app_version: device.appVersion, os_version: device.osVersion,
        push_token: device.pushToken, locale: device.locale,
      },
    });
  }

  private normPhone(p: string): string {
    const digits = p.replace(/\D/g, '');
    if (digits.startsWith('84')) return `+${digits}`;
    if (digits.startsWith('0')) return `+84${digits.slice(1)}`;
    return `+84${digits}`;
  }

  async refresh(refreshToken: string) {
    const tokenHash = sha256(refreshToken);
    const session = await this.prisma.auth_sessions.findUnique({
      where: { refresh_token_hash: tokenHash },
      include: { users: true },
    });
    if (!session || !session.users) {
      throw new UnauthorizedException('Invalid refresh token');
    }
    // Reuse of an already-rotated (revoked) token => likely theft. Revoke the
    // whole chain for this user as a safety measure.
    if (session.revoked_at) {
      await this.prisma.auth_sessions.updateMany({
        where: { user_id: session.user_id, revoked_at: null },
        data: { revoked_at: new Date() },
      });
      throw new UnauthorizedException('Refresh token reuse detected — please sign in again');
    }
    if (session.expires_at && session.expires_at < new Date()) {
      throw new UnauthorizedException('Refresh token expired');
    }
    // Rotate: revoke the consumed session and issue a fresh one.
    await this.prisma.auth_sessions.update({
      where: { id: session.id },
      data: { revoked_at: new Date() },
    });
    return this.issueTokens(session.users);
  }

  // -------- helpers --------

  private async issueTokens(user: { id: string; username: string | null; email?: string | null; display_name: string | null; is_premium: boolean }) {
    const accessToken = await this.jwt.signAsync(
      { sub: user.id, username: user.username, email: user.email ?? undefined, isPremium: user.is_premium },
      { expiresIn: '15m' },
    );
    const refreshTokenPlain = randomBytes(48).toString('base64url');
    const refreshTokenHash = sha256(refreshTokenPlain);

    await this.prisma.auth_sessions.create({
      data: {
        user_id: user.id,
        refresh_token_hash: refreshTokenHash,
        expires_at: new Date(Date.now() + 30 * 24 * 3600 * 1000),
      },
    });

    return {
      accessToken,
      refreshToken: refreshTokenPlain,
      expiresIn: 15 * 60,
      user: {
        id: user.id,
        username: user.username,
        displayName: user.display_name,
        isPremium: user.is_premium,
      },
    };
  }

  private async generateUsername(): Promise<string> {
    // Random username — collision retry
    for (let i = 0; i < 5; i++) {
      const candidate = 'foodie_' + randomBytes(4).toString('hex');
      const exists = await this.prisma.users.findUnique({ where: { username: candidate } });
      if (!exists) return candidate;
    }
    return 'foodie_' + Date.now().toString(36);
  }
}

function sha256(s: string): string {
  return createHash('sha256').update(s).digest('hex');
}
function maskPhone(s: string): string {
  return s.replace(/^(\+\d{2,3}\d{2})\d+(\d{3})$/, '$1***$2');
}
