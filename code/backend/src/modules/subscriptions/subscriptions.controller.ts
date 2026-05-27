import {
  Body,
  Controller,
  Get,
  Post,
  Req,
  Ip,
  UseGuards,
  Headers,
  HttpCode,
} from '@nestjs/common';
import { Request } from 'express';
import { AuthGuard } from '@nestjs/passport';
import { ApiBearerAuth, ApiTags, ApiExcludeEndpoint } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { z } from 'zod';

import { SubscriptionsService, PLAN_IDS } from './subscriptions.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/strategies/jwt.strategy';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';

const CheckoutDto = z.object({
  plan: z.enum(PLAN_IDS as [string, ...string[]]),
  provider: z.enum(['trial', 'vietqr']),
  redirectUrl: z.string().url().max(2048).optional(),
});

const PromoDto = z.object({
  code: z.string().min(2).max(64).regex(/^[A-Za-z0-9._-]+$/),
});

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
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('checkout')
  checkout(
    @CurrentUser() u: JwtPayload,
    @Body(new ZodValidationPipe(CheckoutDto)) body: z.infer<typeof CheckoutDto>,
  ) {
    return this.subs.startCheckout(u.sub, body.plan as any, body.provider, body.redirectUrl);
  }

  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Post('promo')
  redeem(
    @CurrentUser() u: JwtPayload,
    @Body(new ZodValidationPipe(PromoDto)) body: z.infer<typeof PromoDto>,
  ) {
    return this.subs.redeemPromo(u.sub, body.code);
  }

  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Get('me')
  myStatus(@CurrentUser() u: JwtPayload) {
    return this.subs.myStatus(u.sub);
  }

  /**
   * Cancel auto-renewal — keeps premium active until current_period_end,
   * then expires naturally. Audit AI-quality §C-6: previously no
   * endpoint, user had to email admin to cancel.
   */
  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Post('cancel')
  @HttpCode(200)
  cancel(@CurrentUser() u: JwtPayload, @Body() body: { reason?: string }) {
    return this.subs.cancel(u.sub, body?.reason);
  }

  /**
   * SePay bank-transfer webhook.
   *
   * Security stack:
   *   1. Authorization bearer token — verified timing-safe in the service
   *   2. HMAC-SHA256 of the raw body signed with SEPAY_HMAC_SECRET
   *   3. Idempotency via UNIQUE(provider, external_txn_id) in payment_events
   *   4. Dedicated throttle bucket so retries from the provider do not get
   *      blocked by user-route limits
   *
   * The route consumes the raw body (`req.rawBody`) so the HMAC can match
   * exactly what the provider signed.
   */
  @ApiExcludeEndpoint()
  @Throttle({ default: { limit: 120, ttl: 60_000 } })
  @Post('webhook/sepay')
  @HttpCode(200)
  sepayWebhook(
    @Req() req: Request & { rawBody?: Buffer },
    @Body() body: any,
    @Ip() ip: string,
    @Headers('authorization') auth?: string,
    @Headers('x-hnag-signature') sigHnag?: string,
    @Headers('x-sepay-signature') sigSepay?: string,
  ) {
    const token = auth?.replace(/^(Bearer|Apikey)\s+/i, '') ?? auth;
    const signature = sigHnag ?? sigSepay;
    const raw = req.rawBody ? req.rawBody.toString('utf8') : JSON.stringify(body);
    return this.subs.handleSepayWebhook(body, raw, token, signature, ip);
  }
}
