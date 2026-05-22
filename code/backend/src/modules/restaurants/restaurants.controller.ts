import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { RestaurantsService } from './restaurants.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/strategies/jwt.strategy';

@ApiTags('Restaurants')
@Controller('restaurants')
export class RestaurantsController {
  constructor(private readonly r: RestaurantsService) {}

  @ApiBearerAuth() @UseGuards(AuthGuard('jwt'))
  @Post(':id/reviews')
  addReview(
    @CurrentUser() u: JwtPayload,
    @Param('id') id: string,
    @Body() body: { rating: number; title?: string; content?: string; images?: string[]; pricePaidVnd?: number },
  ) {
    return this.r.addReview(u.sub, id, body);
  }

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
