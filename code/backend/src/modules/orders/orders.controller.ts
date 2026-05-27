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
import { Roles } from '../../common/decorators/roles.decorator';

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
      this.logger.debug(`POST /orders/intent without Idempotency-Key user=${u.sub}`);
      return this.orders.createIntent(u.sub, dto);
    }

    const redisKey = `idem:order:${u.sub}:${key}`;
    const claimed = await this.redis.set(redisKey + ':lock', '1', 'EX', 86400, 'NX');

    if (!claimed) {
      const cached = await this.redis.get(redisKey + ':result');
      if (cached) {
        this.logger.debug(`Idempotency replay for key=${key} user=${u.sub}`);
        return JSON.parse(cached);
      }
      return { pending: true, retryAfter: 1 };
    }

    try {
      const result = await this.orders.createIntent(u.sub, dto);
      // Pipeline so result-cache and lock-extend land atomically; if Redis
      // network blips after the order is created, both fail together and the
      // 24h lock auto-expires without the client being stuck forever (audit #36).
      const pipe = this.redis.pipeline();
      pipe.setex(redisKey + ':result', 86400, JSON.stringify(result));
      pipe.expire(redisKey + ':lock', 86400);
      await pipe.exec();
      return result;
    } catch (err) {
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

  /**
   * ADMIN-ONLY order status transition. Audit #4: the previous endpoint
   * allowed a JWT-authed USER to mark their own order `done`, defeating any
   * fulfilment reconciliation. The only legitimate sources of status updates
   * are:
   *   - Partner aggregator webhooks (Grab/Shopee/Baemin) — implemented under
   *     /v1/partners/webhook with HMAC auth (out of scope for this guard).
   *   - Admin/support intervention (refunds, edge cases).
   *
   * Users can NEVER mutate their own order status via this route.
   */
  @Roles('admin', 'support', 'super_admin')
  @Post(':id/status')
  updateStatus(
    @CurrentUser() u: JwtPayload,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() body: UpdateOrderStatusDto,
  ) {
    return this.orders.updateStatus(id, body.status, { eta: body.eta, actorUserId: u.sub, actorRole: 'admin' });
  }

  private normalizeIdempotencyKey(raw: string | undefined): string | null {
    if (!raw) return null;
    const k = raw.trim();
    if (k.length < 8 || k.length > 128) return null;
    if (!/^[A-Za-z0-9._:-]+$/.test(k)) return null;
    return k;
  }
}
