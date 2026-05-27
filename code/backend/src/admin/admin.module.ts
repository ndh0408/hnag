import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';

import { AdminResolver } from './admin.resolver';
import { ClaimsResolver } from './claims.resolver';
import { MetricsResolver } from './metrics.resolver';
import { ObservabilityController } from './observability.controller';
import { AdminAuthService } from './admin-auth.service';
import { GqlAdminGuard } from './gql-admin.guard';
import { AuthModule } from '../modules/auth/auth.module'; // re-exports JwtModule for the guard

@Module({
  imports: [
    AuthModule,
    // Same registerQueue trick as HealthModule — bind the live queue
    // singletons so the observability controller can read counts.
    BullModule.registerQueue({ name: 'otp:email' }, { name: 'push:fcm' }),
  ],
  controllers: [ObservabilityController],
  providers: [AdminAuthService, GqlAdminGuard, AdminResolver, ClaimsResolver, MetricsResolver],
  exports: [AdminAuthService],
})
export class AdminModule {}
