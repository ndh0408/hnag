import { Controller, Get, Param, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { FoodsService } from './foods.service';

@ApiTags('Foods')
@Controller('foods')
export class FoodsController {
  constructor(private readonly foods: FoodsService) {}

  @Get()
  list(
    @Query('cuisine') cuisine?: string,
    @Query('category') category?: string,
    @Query('q') q?: string,
    @Query('maxPrice') maxPrice?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.foods.list({
      cuisine, category, q,
      maxPrice: maxPrice ? parseInt(maxPrice) : undefined,
      page: page ? parseInt(page) : 1,
      limit: limit ? parseInt(limit) : 20,
    });
  }

  @Get('trending')
  trending(@Query('city') city?: string, @Query('period') period?: 'day' | 'week' | 'month') {
    return this.foods.trending(city, period ?? 'week');
  }

  @Get(':id')
  detail(@Param('id') id: string) {
    return this.foods.detail(id);
  }

  @Get(':id/restaurants')
  restaurants(@Param('id') id: string) {
    return this.foods.restaurantsServing(id);
  }
}
