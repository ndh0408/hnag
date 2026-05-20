import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../common/prisma/prisma.service';

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);
  constructor(private readonly prisma: PrismaService) {}

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
   * Send via Firebase Cloud Messaging HTTP v1 if FCM_SERVER_KEY is configured.
   * Looks up active device push tokens for the user. No-op when key absent.
   */
  private async dispatchFcm(userId: string, title: string, body: string, data?: Record<string, unknown>) {
    const serverKey = process.env.FCM_SERVER_KEY;
    if (!serverKey) {
      this.logger.debug(`[push:in-app-only] ${userId} :: ${title}`);
      return;
    }
    const devices = await this.prisma.user_devices.findMany({
      where: { user_id: userId, push_token: { not: null } },
      select: { push_token: true },
    });
    const tokens = devices.map((d) => d.push_token).filter(Boolean) as string[];
    if (tokens.length === 0) return;

    // Legacy FCM HTTP API (simple server key). For HTTP v1 swap to OAuth + project endpoint.
    for (const token of tokens) {
      const res = await fetch('https://fcm.googleapis.com/fcm/send', {
        method: 'POST',
        headers: {
          Authorization: `key=${serverKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          to: token,
          notification: { title, body },
          data: data ?? {},
        }),
      });
      if (!res.ok) {
        this.logger.warn(`FCM send failed (${res.status}) for token ${token.slice(0, 12)}…`);
      }
    }
  }
}
