import { Body, Controller, Get, Post, Query, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { OrdersService } from './orders.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/strategies/jwt.strategy';

@ApiTags('Orders')
@ApiBearerAuth()
@UseGuards(AuthGuard('jwt'))
@Controller('orders')
export class OrdersController {
  constructor(private readonly orders: OrdersService) {}

  @Post('intent')
  intent(@CurrentUser() u: JwtPayload, @Body() body: { foodId: string; restaurantId?: string; preferredPartner?: string }) {
    return this.orders.createIntent(u.sub, body);
  }

  @Get()
  history(@CurrentUser() u: JwtPayload, @Query('page') page?: string) {
    return this.orders.history(u.sub, page ? parseInt(page) : 1);
  }
}
