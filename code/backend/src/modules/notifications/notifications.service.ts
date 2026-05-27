import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import * as admin from 'firebase-admin';
import { PrismaService } from '../../common/prisma/prisma.service';

@Injectable()
export class NotificationsService implements OnModuleInit {
  private readonly logger = new Logger(NotificationsService.name);
  /** Firebase Admin SDK initialised once at module init. Null when env unset. */
  private fcm: admin.messaging.Messaging | null = null;

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Audit workflow-trace §10: legacy `fcm.googleapis.com/fcm/send` endpoint
   * was deprecated by Google June 2024. Migrate to FCM HTTP v1 via
   * `firebase-admin` (the dep is already in package.json). The SDK handles
   * OAuth 2.0 access-token exchange + refresh internally, so we do not
   * have to mint JWTs ourselves.
   *
   * Env vars required (all three or none):
   *   FIREBASE_PROJECT_ID
   *   FIREBASE_CLIENT_EMAIL
   *   FIREBASE_PRIVATE_KEY  (escape newlines as \n in env file)
   */
  onModuleInit() {
    const projectId = process.env.FIREBASE_PROJECT_ID;
    const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
    const privateKeyRaw = process.env.FIREBASE_PRIVATE_KEY;
    if (!projectId || !clientEmail || !privateKeyRaw) {
      this.logger.warn('FCM disabled — set FIREBASE_PROJECT_ID + FIREBASE_CLIENT_EMAIL + FIREBASE_PRIVATE_KEY');
      return;
    }
    // env vars often have \n escaped; restore real newlines for the PEM.
    const privateKey = privateKeyRaw.replace(/\\n/g, '\n');
    try {
      // Idempotent — if some other module already initialized the default
      // app (shouldn't happen in this codebase, but defence-in-depth),
      // re-use it; otherwise create a fresh one.
      const app = admin.apps.length
        ? admin.app()
        : admin.initializeApp({
            credential: admin.credential.cert({ projectId, clientEmail, privateKey }),
          });
      this.fcm = app.messaging();
      this.logger.log(`FCM HTTP v1 ready (project=${projectId})`);
    } catch (err) {
      this.logger.error(`FCM init failed: ${(err as Error).message}`);
    }
  }

  list(userId: string, opts: { unread?: boolean; page?: number }) {
    return this.prisma.notifications.findMany({
      where: {
        user_id: userId,
        ...(opts.unread ? { read_at: null } : {}),
      },
      orderBy: { created_at: 'desc' },
      take: 30,
      skip: ((opts.page ?? 1) - 1) * 30,
    });
  }

  async markRead(userId: string, ids: string[]) {
    await this.prisma.notifications.updateMany({
      where: { user_id: userId, id: { in: ids } },
      data: { read_at: new Date() },
    });
    return { ok: true };
  }

  async updatePrefs(userId: string, prefs: Record<string, unknown>) {
    return this.prisma.user_preferences.update({
      where: { user_id: userId },
      data: { notification_pref: prefs as any },
    });
  }

  async push(userId: string, type: string, title: string, body: string, data?: Record<string, unknown>) {
    // Always persist the in-app notification (works without FCM).
    const row = await this.prisma.notifications.create({
      data: { user_id: userId, type: type as any, title, body, data: data as any },
    });
    // Attempt real push if FCM is configured; otherwise no-op (in-app already saved).
    await this.dispatchFcm(userId, title, body, data).catch((e) =>
      this.logger.warn(`FCM dispatch skipped: ${(e as Error).message}`),
    );
    return row;
  }

  /**
   * Send via FCM HTTP v1 (firebase-admin SDK). The SDK supports multicast
   * delivery up to 500 tokens per call. We slice for safety.
   */
  private async dispatchFcm(userId: string, title: string, body: string, data?: Record<string, unknown>) {
    if (!this.fcm) {
      this.logger.debug(`[push:in-app-only] ${userId} :: ${title}`);
      return;
    }
    const devices = await this.prisma.user_devices.findMany({
      where: { user_id: userId, push_token: { not: null } },
      select: { push_token: true, platform: true },
    });
    const tokens = devices.map((d) => d.push_token).filter(Boolean) as string[];
    if (tokens.length === 0) return;

    // Coerce data payload to string-only (FCM v1 requirement).
    const stringData: Record<string, string> = {};
    if (data) {
      for (const [k, v] of Object.entries(data)) {
        stringData[k] = typeof v === 'string' ? v : JSON.stringify(v);
      }
    }

    // 500-token chunks per multicast.
    for (let i = 0; i < tokens.length; i += 500) {
      const chunk = tokens.slice(i, i + 500);
      try {
        const res = await this.fcm.sendEachForMulticast({
          tokens: chunk,
          notification: { title, body },
          data: stringData,
          android: { priority: 'high' },
          apns: { payload: { aps: { sound: 'default' } } },
        });
        // Prune permanently-invalid tokens so we don't keep retrying them.
        if (res.failureCount > 0) {
          const dead: string[] = [];
          res.responses.forEach((r, idx) => {
            if (!r.success) {
              const code = r.error?.code;
              if (
                code === 'messaging/registration-token-not-registered' ||
                code === 'messaging/invalid-registration-token'
              ) {
                dead.push(chunk[idx]);
              } else {
                this.logger.warn(`FCM send error ${code}: ${r.error?.message}`);
              }
            }
          });
          if (dead.length) {
            await this.prisma.user_devices
              .updateMany({ where: { push_token: { in: dead } }, data: { push_token: null } })
              .catch((e) => this.logger.warn(`Failed to clear dead tokens: ${(e as Error).message}`));
          }
        }
      } catch (err) {
        this.logger.warn(`FCM multicast failed: ${(err as Error).message}`);
      }
    }
  }
}
