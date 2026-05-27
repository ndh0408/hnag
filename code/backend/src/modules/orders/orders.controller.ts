import {
  Body,
  Controller,
  Get,
  Headers,
  Inject,
  Logger,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiBearerAuth, ApiHeader, ApiTags } from '@nestjs/swagger';
import IORedis from 'ioredis';

import { OrdersService } from './orders.service';
import { CreateOrderIntentDto, UpdateOrderStatusDto } from './dto/order.dto';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/strategies/jwt.strategy';
import { REDIS } from '../../common/redis/redis.module';

@ApiTags('Orders')
@ApiBearerAuth()
@UseGuards(AuthGuard('jwt'))
@Controller('orders')
export class OrdersController {
  private readonly logger = new Logger(OrdersController.name);

  constructor(
    private readonly orders: OrdersService,
    @Inject(REDIS) private readonly redis: IORedis,
  ) {}

  /**
   * Create a new order intent. Clients SHOULD send an `Idempotency-Key`
   * header — a stable UUID per logical user action (e.g. one tap on
   * "Đặt giao"). On retry within 24h with the same key the original
   * response is replayed verbatim, so a flaky mobile network can't
   * accidentally create duplicate orders.
   *
   * Audit hnag-audit-2026-05 §B-19 (HIGH): order creation had no idempotency
   * guard; double-tap or network retry → two orders.
   */
  @ApiHeader({
    name: 'Idempotency-Key',
    required: false,
    description:
      'Stable UUID v4 per logical action. Retries with the same key within 24h return the cached response.',
  })
  @Post('intent')
  async intent(
    @CurrentUser() u: JwtPayload,
    @Body() dto: CreateOrderIntentDto,
    @Headers('idempotency-key') idemKey?: string,
  ) {
    const key = this.normalizeIdempotencyKey(idemKey);
    if (!key) {
      // No idempotency key provided — still create, but log so we can spot
      // mobile clients that haven't migrated yet.
      this.logger.debug(`POST /orders/intent without Idempotency-Key user=${u.sub}`);
      return this.orders.createIntent(u.sub, dto);
    }

    const redisKey = `idem:order:${u.sub}:${key}`;
    // SET NX: only succeeds if no prior request claimed this key.
    const claimed = await this.redis.set(redisKey + ':lock', '1', 'EX', 86400, 'NX');

    if (!claimed) {
      // Either a prior request is still in flight OR it already finished.
      // Try to serve the cached result; if it's not there yet, the original
      // is still running — tell the client to retry shortly.
      const cached = await this.redis.get(redisKey + ':result');
      if (cached) {
        this.logger.debug(`Idempotency replay for key=${key} user=${u.sub}`);
        return JSON.parse(cached);
      }
      return { pending: true, retryAfter: 1 };
    }

    try {
      const result = await this.orders.createIntent(u.sub, dto);
      // Cache the response for 24h so any subsequent retry replays it.
      await this.redis.setex(redisKey + ':result', 86400, JSON.stringify(result));
      return result;
    } catch (err) {
      // On failure release the lock so the client can retry with the same
      // key without being stuck behind the failed attempt.
      await this.redis.del(redisKey + ':lock');
      throw err;
    }
  }

  @Get()
  history(@CurrentUser() u: JwtPayload, @Query('page') page?: string) {
    return this.orders.history(u.sub, page ? parseInt(page) : 1);
  }

  @Get(':id')
  getOne(@CurrentUser() u: JwtPayload, @Param('id', new ParseUUIDPipe()) id: string) {
    return this.orders.getOrder(u.sub, id);
  }

  // Owner-only dev/QA endpoint to advance an order's status — emits
  // `order:update` over WebSocket to the user room so the tracking screen
  // reacts live. Real production updates come from partner webhook handlers
  // (see PartnersModule) that bypass this guard via HMAC.
  @Post(':id/status')
  updateStatus(
    @CurrentUser() u: JwtPayload,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() body: UpdateOrderStatusDto,
  ) {
    return this.orders.updateStatus(id, body.status, { eta: body.eta, actorUserId: u.sub });
  }

  /**
   * Idempotency keys are client-generated; we reject anything that isn't a
   * plausibly-unique opaque string. Defence against an attacker spraying
   * `Idempotency-Key: a` to read another user's prior order response (the
   * Redis key is namespaced by user.sub so cross-user replay is already
   * impossible — this is the second layer).
   */
  private normalizeIdempotencyKey(raw: string | undefined): string | null {
    if (!raw) return null;
    const k = raw.trim();
    if (k.length < 8 || k.length > 128) return null;
    if (!/^[A-Za-z0-9._:-]+$/.test(k)) return null;
    return k;
  }
}
