import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';

import { HealthController } from './health.controller';

@Module({
  // Import the queues purely so `@InjectQueue` in the health controller
  // resolves the *same* instance the workers consume. Health endpoint
  // reads job counts; it never enqueues.
  imports: [BullModule.registerQueue({ name: 'otp:email' }, { name: 'push:fcm' })],
  controllers: [HealthController],
})
export class HealthModule {}
