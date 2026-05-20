import { Module } from '@nestjs/common';
import { RestaurantsController } from './restaurants.controller';
import { RestaurantsService } from './restaurants.service';
import { ClaimController } from './claim.controller';
import { ClaimService } from './claim.service';
import { AuthModule } from '../auth/auth.module';

@Module({
  imports: [AuthModule],
  controllers: [RestaurantsController, ClaimController],
  providers: [RestaurantsService, ClaimService],
  exports: [RestaurantsService],
})
export class RestaurantsModule {}
