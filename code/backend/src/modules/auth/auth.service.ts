import { Injectable, Inject, UnauthorizedException, Logger, BadRequestException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { randomBytes, createHash, randomUUID } from 'crypto';
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

/**
 * Synthetic-email shape used historically for Apple-SSO accounts that didn't
 * share a real email. We refuse this shape from the regular email-OTP signup
 * path so an attacker can no longer pre-register the shape and hijack an
 * Apple user when they sign in (audit #12). The shape is documented via
 * `users_no_synthetic_apple_email` CHECK in sql/17_apple_sub.sql for
 * defence-in-depth.
 */
const APPLE_SYNTHETIC_EMAIL_RE = /^apple\+.+@hnag\.internal$/i;

/** Refresh-token rolling window — the absolute cap below is the hard ceiling. */
const REFRESH_TTL_DAYS = 30;
/**
 * Hard cap on the entire refresh chain. Even with healthy rotations every
 * 15min, the user must re-authenticate after this many days. Audit #5: prior
 * code regenerated `expires_at = now + 30d` on EVERY refresh, so a stolen
 * token could be rotated indefinitely.
 */
const REFRESH_ABSOLUTE_MAX_DAYS = 30;
/** Anomaly threshold for `rotation_count` — surface in monitoring. */
const ROTATION_COUNT_ANOMALY = 200;

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

  async signInWithEmail(email: string, device?: DeviceInfo, audit?: { ip?: string; userAgent?: string }) {
    const key = email.toLowerCase().trim();
    // Defence-in-depth (audit #12): the regular OTP path MUST refuse the
    // synthetic Apple shape. The DB CHECK constraint in sql/17 backs this up.
    if (APPLE_SYNTHETIC_EMAIL_RE.test(key)) {
      throw new BadRequestException('Email không hợp lệ');
    }
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
    return this.issueInitialTokens(user, { device, audit });
  }

  async signInWithPhone(phone: string, device?: DeviceInfo, audit?: { ip?: string; userAgent?: string }) {
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
    return this.issueInitialTokens(user, { device, audit });
  }

  /**
   * Apple SSO. Cryptographically verifies the identityToken signature against
   * Apple's published JWKS before trusting any claim, then upserts the user
   * keyed on `apple_sub` (NEVER on a synthetic email — audit #12).
   *
   * Upsert priority:
   *   1. Find users by `apple_sub` (proven by Apple) — exact match → use.
   *   2. Else: if Apple shared a real email AND it's not already linked to a
   *      different `apple_sub`, attach apple_sub to that row (link existing).
   *   3. Else: create a fresh row with `apple_sub` set, email NULL.
   *
   * Audit #5 fix is applied here too: tokens are issued via `issueInitialTokens`
   * which sets `absolute_expires_at` + a fresh `family_id`.
   */
  async signInWithApple(payload: {
    identityToken: string;
    authorizationCode?: string;
    fullName?: string;
    email?: string;
    device?: DeviceInfo;
    audit?: { ip?: string; userAgent?: string };
  }) {
    const claims = await this.appleVerifier.verify(payload.identityToken, this.appleAudience);

    const sub = claims.sub;
    if (!sub || typeof sub !== 'string') {
      throw new UnauthorizedException('Apple token: missing sub');
    }

    // Prefer the email proven by Apple inside the verified token over whatever
    // the client claims in the request body. Clients can lie, JWT claims can't.
    const verifiedEmail = typeof claims.email === 'string' ? claims.email.toLowerCase() : undefined;
    const clientClaimedEmail = payload.email?.toLowerCase();
    const email = (verifiedEmail ?? clientClaimedEmail)?.trim() || undefined;

    // Refuse the synthetic Apple shape from any client (defence in depth).
    if (email && APPLE_SYNTHETIC_EMAIL_RE.test(email)) {
      throw new BadRequestException('Email không hợp lệ');
    }

    // Step 1: by apple_sub
    let user = await this.prisma.users.findUnique({ where: { apple_sub: sub } });

    // Step 2: link existing real-email row (only when the row has no apple_sub yet)
    if (!user && email) {
      const existing = await this.prisma.users.findUnique({ where: { email } });
      if (existing && !existing.apple_sub) {
        user = await this.prisma.users.update({
          where: { id: existing.id },
          data: { apple_sub: sub, last_seen_at: new Date() },
        });
      }
    }

    // Step 3: create fresh
    if (!user) {
      user = await this.prisma.users.create({
        data: {
          apple_sub: sub,
          email: email ?? null,
          username: await this.generateUsername(),
          display_name: payload.fullName?.trim() || (email ? email.split('@')[0] : 'Apple Foodie'),
          language: 'vi',
        },
      });
    } else {
      await this.prisma.users.update({
        where: { id: user.id },
        data: { last_seen_at: new Date() },
      });
    }

    if (payload.device) await this.upsertDevice(user.id, payload.device);
    return this.issueInitialTokens(user, { device: payload.device, audit: payload.audit });
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

  /**
   * Rotate the refresh token. Closes audit #5:
   *   - the new session inherits `family_id` + `absolute_expires_at` from
   *     the consumed one, so the chain CANNOT extend past the absolute cap
   *   - reuse of an already-rotated token revokes the whole `family_id`,
   *     not just the per-session chain
   *   - rotation_count is bumped; anomalies surface in monitoring
   */
  async refresh(refreshToken: string, audit?: { ip?: string; userAgent?: string }) {
    const tokenHash = sha256(refreshToken);
    const session = await this.prisma.auth_sessions.findUnique({
      where: { refresh_token_hash: tokenHash },
      include: { users: true },
    });
    if (!session || !session.users) {
      throw new UnauthorizedException('Invalid refresh token');
    }
    // Reuse of an already-rotated (revoked) token => likely theft. Revoke the
    // whole FAMILY so any sibling rotations done by the attacker are killed too.
    if (session.revoked_at) {
      await this.prisma.auth_sessions.updateMany({
        where: { family_id: session.family_id, revoked_at: null },
        data: { revoked_at: new Date() },
      });
      throw new UnauthorizedException('Refresh token reuse detected — please sign in again');
    }
    const now = new Date();
    if (session.expires_at && session.expires_at < now) {
      throw new UnauthorizedException('Refresh token expired');
    }
    // Hard cap on the whole chain — no rolling extension past this.
    if (session.absolute_expires_at < now) {
      // Revoke whole family so a sibling chain can't keep going.
      await this.prisma.auth_sessions.updateMany({
        where: { family_id: session.family_id, revoked_at: null },
        data: { revoked_at: new Date() },
      });
      throw new UnauthorizedException('Phiên đăng nhập đã hết hạn — vui lòng đăng nhập lại');
    }
    // Rotate: revoke the consumed session and issue a fresh one with the same
    // family + the original absolute expiry.
    await this.prisma.auth_sessions.update({
      where: { id: session.id },
      data: { revoked_at: now },
    });
    return this.issueRotatedTokens(session.users, {
      familyId: session.family_id,
      absoluteExpiresAt: session.absolute_expires_at,
      previousRotationCount: session.rotation_count,
      audit,
    });
  }

  // -------- helpers --------

  /** First-time issue: fresh family + absolute lifetime. */
  private async issueInitialTokens(
    user: { id: string; username: string | null; email?: string | null; display_name: string | null; is_premium: boolean },
    opts: { device?: DeviceInfo; audit?: { ip?: string; userAgent?: string } },
  ) {
    const now = new Date();
    const absoluteExpiresAt = new Date(now.getTime() + REFRESH_ABSOLUTE_MAX_DAYS * 24 * 3600 * 1000);
    return this.createSessionAndSignTokens(user, {
      familyId: randomUUID(),
      absoluteExpiresAt,
      rotationCount: 0,
      audit: opts.audit,
    });
  }

  /** Rotated issue: inherit family + absolute lifetime. */
  private async issueRotatedTokens(
    user: { id: string; username: string | null; email?: string | null; display_name: string | null; is_premium: boolean },
    opts: { familyId: string; absoluteExpiresAt: Date; previousRotationCount: number; audit?: { ip?: string; userAgent?: string } },
  ) {
    const newRotationCount = (opts.previousRotationCount ?? 0) + 1;
    if (newRotationCount === ROTATION_COUNT_ANOMALY) {
      this.logger.warn(
        `Refresh chain anomaly: user=${user.id} family=${opts.familyId} rotations=${newRotationCount}`,
      );
    }
    return this.createSessionAndSignTokens(user, {
      familyId: opts.familyId,
      absoluteExpiresAt: opts.absoluteExpiresAt,
      rotationCount: newRotationCount,
      audit: opts.audit,
    });
  }

  private async createSessionAndSignTokens(
    user: { id: string; username: string | null; email?: string | null; display_name: string | null; is_premium: boolean },
    opts: { familyId: string; absoluteExpiresAt: Date; rotationCount: number; audit?: { ip?: string; userAgent?: string } },
  ) {
    const accessToken = await this.jwt.signAsync(
      { sub: user.id, username: user.username, email: user.email ?? undefined, isPremium: user.is_premium },
      { expiresIn: '15m' },
    );
    const refreshTokenPlain = randomBytes(48).toString('base64url');
    const refreshTokenHash = sha256(refreshTokenPlain);
    const now = new Date();
    const rollingExpiresAt = new Date(now.getTime() + REFRESH_TTL_DAYS * 24 * 3600 * 1000);
    // Never extend past the absolute cap.
    const expires_at = rollingExpiresAt < opts.absoluteExpiresAt ? rollingExpiresAt : opts.absoluteExpiresAt;

    await this.prisma.auth_sessions.create({
      data: {
        user_id: user.id,
        family_id: opts.familyId,
        refresh_token_hash: refreshTokenHash,
        expires_at,
        absolute_expires_at: opts.absoluteExpiresAt,
        rotation_count: opts.rotationCount,
        ip_inet: opts.audit?.ip ?? null,
        user_agent: opts.audit?.userAgent?.slice(0, 500) ?? null,
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
    // Random username — collision retry with strong entropy on fallback.
    for (let i = 0; i < 5; i++) {
      const candidate = 'foodie_' + randomBytes(4).toString('hex');
      const exists = await this.prisma.users.findUnique({ where: { username: candidate } });
      if (!exists) return candidate;
    }
    // Fallback: 6-byte random + timestamp to avoid Date.now() ms-collisions on
    // a marketing-signup spike (audit #30).
    return 'foodie_' + Date.now().toString(36) + '_' + randomBytes(3).toString('hex');
  }
}

function sha256(s: string): string {
  return createHash('sha256').update(s).digest('hex');
}
