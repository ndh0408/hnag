import { Body, Controller, Delete, Get, Param, Post, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { BoostProductId, BoostService } from './boost.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/strategies/jwt.strategy';

@ApiTags('Boost')
@Controller('boost')
export class BoostController {
  constructor(private readonly svc: BoostService) {}

  @Get('products')
  products() {
    return this.svc.listProducts();
  }

  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Get('me')
  myCampaigns(@CurrentUser() u: JwtPayload) {
    return this.svc.myCampaigns(u.sub);
  }

  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Post('campaign')
  create(
    @CurrentUser() u: JwtPayload,
    @Body() body: { restaurantId: string; product: BoostProductId; durationDays: number; paymentRef?: string },
  ) {
    return this.svc.createCampaign(u.sub, body.restaurantId, body.product, body.durationDays, body.paymentRef);
  }

  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Delete('campaign/:restaurantId')
  cancel(@CurrentUser() u: JwtPayload, @Param('restaurantId') id: string) {
    return this.svc.cancel(u.sub, id);
  }
}
