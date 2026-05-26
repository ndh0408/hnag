import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
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

  @Get(':id')
  getOne(@CurrentUser() u: JwtPayload, @Param('id') id: string) {
    return this.orders.getOrder(u.sub, id);
  }

  // Owner-only dev/QA endpoint to advance an order's status — emits
  // `order:update` over WebSocket to the user room so the tracking screen
  // reacts live. Real production updates come from partner webhook handlers
  // (see PartnersModule) that bypass this guard via HMAC.
  @Post(':id/status')
  updateStatus(
    @CurrentUser() u: JwtPayload,
    @Param('id') id: string,
    @Body() body: { status: 'intent' | 'placed' | 'cooking' | 'picking' | 'delivering' | 'done' | 'cancelled'; eta?: string },
  ) {
    return this.orders.updateStatus(id, body.status, { eta: body.eta, actorUserId: u.sub });
  }
}
