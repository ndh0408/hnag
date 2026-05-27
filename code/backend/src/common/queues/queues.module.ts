import { Module, Global } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';

import { EmailOtpProcessor } from './email-otp.processor';
import { PushProcessor } from './push.processor';
import { AuthModule } from '../../modules/auth/auth.module';
import { NotificationsModule } from '../../modules/notifications/notifications.module';

/**
 * Background workers (BullMQ).
 *
 * Audit hnag-audit-2026-05 §9: BullMQ was wired in app.module.ts but
 * never used — every email send + push notification ran synchronously in
 * the request thread. Under modest load (~50 req/s with a 1-2s SMTP RTT)
 * this exhausts the Node thread pool and stalls the auth route.
 *
 * This module:
 *   - registers the two queues the audit specifically flagged: `otp:email`
 *     and `push:fcm`
 *   - mounts the two processors that drain them
 *   - is @Global so individual modules can `@InjectQueue('otp-email')`
 *     without importing this module everywhere
 */
@Global()
@Module({
  imports: [
    BullModule.registerQueue(
      {
        name: 'otp-email',
        defaultJobOptions: {
          attempts: 4,
          backoff: { type: 'exponential', delay: 2000 },
          removeOnComplete: { age: 600, count: 1000 },
          removeOnFail: { age: 7 * 24 * 3600 },
        },
      },
      {
        name: 'push-fcm',
        defaultJobOptions: {
          attempts: 5,
          backoff: { type: 'exponential', delay: 3000 },
          removeOnComplete: { age: 3600, count: 5000 },
          removeOnFail: { age: 7 * 24 * 3600 },
        },
      },
    ),
    AuthModule,
    NotificationsModule,
  ],
  providers: [EmailOtpProcessor, PushProcessor],
  exports: [BullModule],
})
export class QueuesModule {}
