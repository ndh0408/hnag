import { Controller, Get, Param, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { RestaurantsService } from './restaurants.service';

@ApiTags('Restaurants')
@Controller('restaurants')
export class RestaurantsController {
  constructor(private readonly r: RestaurantsService) {}

  @Get('nearby')
  nearby(
    @Query('lat') lat: string,
    @Query('lng') lng: string,
    @Query('radius') radius?: string,
    @Query('openNow') openNow?: string,
    @Query('priceLevel') priceLevel?: string,
    @Query('cuisine') cuisine?: string,
    @Query('minRating') minRating?: string,
  ) {
    return this.r.nearby({
      lat: parseFloat(lat),
      lng: parseFloat(lng),
      radius: radius ? parseInt(radius) : 3000,
      openNow: openNow === 'true',
      priceLevel: priceLevel ? parseInt(priceLevel) : undefined,
      cuisine,
      minRating: minRating ? parseFloat(minRating) : undefined,
    });
  }

  @Get(':id')
  detail(@Param('id') id: string) {
    return this.r.detail(id);
  }

  @Get(':id/menu')
  menu(@Param('id') id: string) {
    return this.r.menu(id);
  }

  @Get(':id/reviews')
  reviews(
    @Param('id') id: string,
    @Query('sort') sort?: 'recent' | 'helpful' | 'rating',
    @Query('page') page?: string,
  ) {
    return this.r.reviews(id, sort ?? 'recent', page ? parseInt(page) : 1);
  }
}
