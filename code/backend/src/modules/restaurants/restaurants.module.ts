import { Module, forwardRef } from '@nestjs/common';
import { RestaurantsController } from './restaurants.controller';
import { RestaurantsService } from './restaurants.service';
import { ClaimController } from './claim.controller';
import { ClaimService } from './claim.service';
import { OwnerController } from './owner.controller';
import { OwnerService } from './owner.service';
import { AuthModule } from '../auth/auth.module';
import { RealtimeModule } from '../realtime/realtime.module';

@Module({
  imports: [AuthModule, forwardRef(() => RealtimeModule)],
  controllers: [RestaurantsController, ClaimController, OwnerController],
  providers: [RestaurantsService, ClaimService, OwnerService],
  exports: [RestaurantsService],
})
export class RestaurantsModule {}
