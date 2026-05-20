import { Module } from '@nestjs/common';
import { AdminResolver } from './admin.resolver';
import { ClaimsResolver } from './claims.resolver';
import { MetricsResolver } from './metrics.resolver';
import { AdminAuthService } from './admin-auth.service';

@Module({
  providers: [AdminAuthService, AdminResolver, ClaimsResolver, MetricsResolver],
  exports: [AdminAuthService],
})
export class AdminModule {}
