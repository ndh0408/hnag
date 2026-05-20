import { Body, Controller, Get, Post, UseGuards, Headers, HttpCode } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { SubscriptionsService, PLANS } from './subscriptions.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/strategies/jwt.strategy';

@ApiTags('Subscription')
@Controller('subscription')
export class SubscriptionsController {
  constructor(private readonly subs: SubscriptionsService) {}

  @Get('plans')
  plans() {
    return this.subs.listPlans();
  }

  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Post('checkout')
  checkout(
    @CurrentUser() u: JwtPayload,
    @Body() body: { plan: keyof typeof PLANS; provider: string; redirectUrl?: string },
  ) {
    return this.subs.startCheckout(u.sub, body.plan, body.provider, body.redirectUrl);
  }

  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Post('promo')
  redeem(@CurrentUser() u: JwtPayload, @Body() body: { code: string }) {
    return this.subs.redeemPromo(u.sub, body.code);
  }

  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Get('me')
  myStatus(@CurrentUser() u: JwtPayload) {
    return this.subs.myStatus(u.sub);
  }

  /** SePay bank-transfer webhook — no JWT, secured by Authorization token. */
  @Post('webhook/sepay')
  @HttpCode(200)
  sepayWebhook(@Body() body: any, @Headers('authorization') auth?: string) {
    const token = auth?.replace(/^(Bearer|Apikey)\s+/i, '') ?? auth;
    return this.subs.handleSepayWebhook(body, token);
  }
}
