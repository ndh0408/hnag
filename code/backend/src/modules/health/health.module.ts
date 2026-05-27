import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';

import { HealthController } from './health.controller';
import { MetricsController } from './metrics.controller';

@Module({
  // Import the queues purely so `@InjectQueue` in the health + metrics
  // controllers resolves the *same* instance the workers consume.
  imports: [BullModule.registerQueue({ name: 'otp-email' }, { name: 'push-fcm' })],
  controllers: [HealthController, MetricsController],
})
export class HealthModule {}
