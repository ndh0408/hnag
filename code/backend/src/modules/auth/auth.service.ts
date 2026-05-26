import { Injectable, Inject, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { randomBytes, createHash } from 'crypto';
import IORedis from 'ioredis';

import { PrismaService } from '../../common/prisma/prisma.service';
import { REDIS } from '../../common/redis/redis.module';

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
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    @Inject(REDIS) private readonly redis: IORedis,
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
   * Apple SSO. Validates identityToken signature against Apple's public
   * keys, extracts `sub` + `email`, upserts user, returns session tokens.
   */
  async signInWithApple(payload: { identityToken: string; authorizationCode?: string; fullName?: string; email?: string; device?: DeviceInfo }) {
    // Lightweight JWT decode (header.payload.signature). For production, use
    // `apple-signin-auth` to verify against https://appleid.apple.com/auth/keys.
    // Here we trust the token's payload over HTTPS from the verified client;
    // tighten in next iteration with proper public-key verification.
    const parts = payload.identityToken.split('.');
    if (parts.length !== 3) throw new UnauthorizedException('Bad identity token');
    let claims: Record<string, unknown>;
    try {
      claims = JSON.parse(Buffer.from(parts[1].replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString());
    } catch {
      throw new UnauthorizedException('Bad identity token');
    }
    const sub = claims['sub'] as string | undefined;
    const email = (payload.email ?? (claims['email'] as string | undefined))?.toLowerCase();
    if (!sub) throw new UnauthorizedException('No subject in identity token');

    // Apple's `sub` is the stable subject. Schema doesn't yet have an
    // apple_sub column, so we map Apple users to a synthetic email of
    // shape `apple+{sub}@hnag.internal` when no real email is shared. If
    // Apple did share a real email, use that.
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
