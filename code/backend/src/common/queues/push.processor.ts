import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import { Job } from 'bullmq';

import { NotificationsService } from '../../modules/notifications/notifications.service';

export interface PushJob {
  userId: string;
  type: string;
  title: string;
  body: string;
  data?: Record<string, unknown>;
}

/**
 * Drains the `push:fcm` queue. The handler delegates back to the canonical
 * `NotificationsService.push` so the in-app row + FCM dispatch logic stays
 * in one place — this worker exists only to take the FCM round-trip off
 * the request thread.
 *
 * concurrency=10 — FCM HTTP API tolerates this comfortably and most
 * notifications are sent in bursts (group voting result, order updates).
 */
@Processor('push:fcm', { concurrency: 10 })
export class PushProcessor extends WorkerHost {
  private readonly logger = new Logger(PushProcessor.name);

  constructor(private readonly notifications: NotificationsService) {
    super();
  }

  async process(job: Job<PushJob>): Promise<void> {
    const { userId, type, title, body, data } = job.data;
    try {
      await this.notifications.push(userId, type, title, body, data);
    } catch (err) {
      this.logger.warn(
        `Push worker: ${userId}/${type} attempt ${job.attemptsMade + 1} failed: ${(err as Error).message}`,
      );
      throw err;
    }
  }
}
