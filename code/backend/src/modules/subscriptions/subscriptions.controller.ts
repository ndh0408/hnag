import {
  Body,
  Controller,
  Get,
  Post,
  Req,
  UseGuards,
  Headers,
  HttpCode,
  RawBodyRequest,
} from '@nestjs/common';
import { Request } from 'express';
import { AuthGuard } from '@nestjs/passport';
import { ApiBearerAuth, ApiTags, ApiExcludeEndpoint } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
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

  /**
   * SePay bank-transfer webhook.
   *
   * Security stack (closes audit hnag-audit-2026-05 CRITICAL "forgeable webhook"):
   *   1. Authorization bearer token — verified timing-safe in the service
   *   2. HMAC-SHA256 of the raw body signed with SEPAY_HMAC_SECRET, sent in
   *      `X-HNAG-Signature` (or `X-Sepay-Signature`) — verified timing-safe
   *   3. Idempotency: bank `id` is recorded in payment_events with a UNIQUE
   *      constraint, so a replayed webhook is a no-op
   *   4. Dedicated throttle bucket so retries from the payment provider do
   *      not get blocked by user-route limits
   *
   * The route consumes the raw body (`req.rawBody`) so the HMAC can match
   * exactly what the provider signed — JSON.stringify on the parsed object
   * would normalize whitespace and break the signature.
   */
  @ApiExcludeEndpoint()
  @Throttle({ default: { limit: 120, ttl: 60_000 } })
  @Post('webhook/sepay')
  @HttpCode(200)
  sepayWebhook(
    @Req() req: RawBodyRequest<Request>,
    @Body() body: any,
    @Headers('authorization') auth?: string,
    @Headers('x-hnag-signature') sigHnag?: string,
    @Headers('x-sepay-signature') sigSepay?: string,
  ) {
    const token = auth?.replace(/^(Bearer|Apikey)\s+/i, '') ?? auth;
    const signature = sigHnag ?? sigSepay;
    // `rawBody` is populated by enabling `rawBody: true` in NestFactory.create
    // (see main.ts). When not present (e.g. unit tests posting parsed JSON),
    // fall back to a stable JSON.stringify so the service can still validate.
    const raw = req.rawBody ? req.rawBody.toString('utf8') : JSON.stringify(body);
    return this.subs.handleSepayWebhook(body, raw, token, signature);
  }
}
