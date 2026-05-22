import { Module } from '@nestjs/common';
import { AdminResolver } from './admin.resolver';
import { ClaimsResolver } from './claims.resolver';
import { MetricsResolver } from './metrics.resolver';
import { AdminAuthService } from './admin-auth.service';
import { GqlAdminGuard } from './gql-admin.guard';
import { AuthModule } from '../modules/auth/auth.module'; // re-exports JwtModule for the guard

@Module({
  imports: [AuthModule],
  providers: [AdminAuthService, GqlAdminGuard, AdminResolver, ClaimsResolver, MetricsResolver],
  exports: [AdminAuthService],
})
export class AdminModule {}
