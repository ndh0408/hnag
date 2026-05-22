import { Module } from '@nestjs/common';
import { FoodsController } from './foods.controller';
import { FoodsService } from './foods.service';
import { TrendingService } from './trending.service';

@Module({
  controllers: [FoodsController],
  providers: [FoodsService, TrendingService],
})
export class FoodsModule {}
