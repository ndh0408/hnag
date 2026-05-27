import {
  Body,
  Controller,
  Delete,
  ForbiddenException,
  Get,
  NotFoundException,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';

import { OwnerService } from './owner.service';
import {
  UpdateRestaurantLiveDto,
  UpdateRestaurantDto,
  UpsertMenuItemDto,
} from './dto/owner.dto';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/strategies/jwt.strategy';

/**
 * Owner-side endpoints for restaurant owners managing their claimed listings.
 *
 * Authorization model — every route validates that the caller is the
 * approved claimant of the `:id` restaurant via `OwnerService.assertOwner`.
 * No "admin override" backdoor is exposed here; admin tools live behind
 * the GraphQL admin guard.
 *
 * Audit hnag-audit-2026-05 §5 / §27 (B2B moat): owner dashboard was a UI
 * shell with no backend. These endpoints close the gap so restaurants can
 * actually run their listing through HNAG instead of GrabFood / ShopeeFood.
 */
@ApiTags('Owner')
@ApiBearerAuth()
@UseGuards(AuthGuard('jwt'))
@Controller('owner')
export class OwnerController {
  constructor(private readonly owner: OwnerService) {}

  /** Restaurants this user has approved claims on. */
  @Get('restaurants')
  myRestaurants(@CurrentUser() u: JwtPayload) {
    return this.owner.myRestaurants(u.sub);
  }

  /** One restaurant's full owner-side view (basic + live + menu count). */
  @Get('restaurants/:id')
  detail(@CurrentUser() u: JwtPayload, @Param('id', new ParseUUIDPipe()) id: string) {
    return this.owner.detail(u.sub, id);
  }

  /**
   * Update editable restaurant profile fields. Restricted by an explicit
   * allowlist server-side (see UpdateRestaurantDto) — mass assignment is
   * impossible even on an unintended field added later.
   */
  @Patch('restaurants/:id')
  update(
    @CurrentUser() u: JwtPayload,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: UpdateRestaurantDto,
  ) {
    return this.owner.updateRestaurant(u.sub, id, dto);
  }

  /**
   * Update live status / wait time. Broadcast to `restaurant:<id>` over
   * WebSocket so subscribers see the change in real time without polling.
   */
  @Patch('restaurants/:id/live')
  setLive(
    @CurrentUser() u: JwtPayload,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: UpdateRestaurantLiveDto,
  ) {
    return this.owner.setLive(u.sub, id, dto);
  }

  /** Last 50 live orders (status != done/cancelled) for a restaurant. */
  @Get('restaurants/:id/orders/live')
  ordersLive(@CurrentUser() u: JwtPayload, @Param('id', new ParseUUIDPipe()) id: string) {
    return this.owner.ordersLive(u.sub, id);
  }

  /** Recent reviews; pagination via `?page=`. */
  @Get('restaurants/:id/reviews')
  reviews(
    @CurrentUser() u: JwtPayload,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Query('page') page?: string,
  ) {
    return this.owner.reviews(u.sub, id, page ? parseInt(page) : 1);
  }

  /** Menu items the owner has published for this restaurant. */
  @Get('restaurants/:id/menu')
  menu(@CurrentUser() u: JwtPayload, @Param('id', new ParseUUIDPipe()) id: string) {
    return this.owner.menu(u.sub, id);
  }

  /**
   * Add or update a menu item. `:itemId` may be a UUID for an update,
   * or the literal `new` to create. Audit hnag-audit-2026-05 §27 — the
   * only reason a restaurant has to use HNAG over GrabFood/Shopee is the
   * ability to self-serve update menu and pricing.
   */
  @Post('restaurants/:id/menu')
  createMenuItem(
    @CurrentUser() u: JwtPayload,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: UpsertMenuItemDto,
  ) {
    return this.owner.upsertMenuItem(u.sub, id, null, dto);
  }

  @Patch('restaurants/:id/menu/:itemId')
  updateMenuItem(
    @CurrentUser() u: JwtPayload,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Param('itemId', new ParseUUIDPipe()) itemId: string,
    @Body() dto: UpsertMenuItemDto,
  ) {
    return this.owner.upsertMenuItem(u.sub, id, itemId, dto);
  }

  @Delete('restaurants/:id/menu/:itemId')
  deleteMenuItem(
    @CurrentUser() u: JwtPayload,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Param('itemId', new ParseUUIDPipe()) itemId: string,
  ) {
    return this.owner.deleteMenuItem(u.sub, id, itemId);
  }
}
