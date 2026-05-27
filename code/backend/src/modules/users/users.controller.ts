import { Body, Controller, Delete, Get, Headers, HttpCode, Ip, Param, ParseUUIDPipe, Patch, Post, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';

import { UsersService } from './users.service';
import { UpdateUserDto } from './dto/update-user.dto';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/strategies/jwt.strategy';

@ApiTags('Users')
@ApiBearerAuth()
@UseGuards(AuthGuard('jwt'))
@Controller('users')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get('me')
  me(@CurrentUser() u: JwtPayload) {
    return this.users.me(u.sub);
  }

  @Patch('me')
  async update(@CurrentUser() u: JwtPayload, @Body() dto: UpdateUserDto) {
    // Preferences are merged separately so the service-layer ALLOWED_PREF_KEYS
    // whitelist still applies (mass-assignment defence in depth). The profile
    // fields are written via Prisma using only the four allowed columns.
    const { preferences, ...profile } = dto;
    const updated = Object.keys(profile).length
      ? await this.users.updateMe(u.sub, profile)
      : null;
    const prefs = preferences ? await this.users.updatePreferences(u.sub, preferences) : null;
    return { user: updated, preferences: prefs };
  }

  /**
   * Delete this account and erase its personal data.
   *
   * Required by:
   *  - App Store Review Guideline 5.1.1(v) ("Account deletion")
   *  - Vietnam Decree 13/2023/ND-CP (right to erasure)
   *
   * Idempotent — a second call on an already-deleted account returns 200
   * with `{ alreadyDeleted: true }`. The session that called this is revoked
   * as part of the flow, so the next request from this device will 401.
   */
  @ApiOperation({ summary: 'Delete my account (App Store 5.1.1 / Decree 13/2023)' })
  @Delete('me')
  @HttpCode(200)
  deleteMe(
    @CurrentUser() u: JwtPayload,
    @Ip() ip: string,
    @Headers('user-agent') userAgent?: string,
    @Headers('x-hnag-client') client?: string,
  ) {
    const source = client === 'web' ? 'web' : client === 'api' ? 'api' : 'app';
    return this.users.deleteAccount(u.sub, { ip, userAgent, source });
  }

  @Get('me/saves')
  listSaves(@CurrentUser() u: JwtPayload) {
    return this.users.listSaves(u.sub);
  }

  @Post('me/saves/:foodId')
  addSave(@CurrentUser() u: JwtPayload, @Param('foodId', new ParseUUIDPipe()) foodId: string) {
    return this.users.addSave(u.sub, foodId);
  }

  @Delete('me/saves/:foodId')
  removeSave(@CurrentUser() u: JwtPayload, @Param('foodId', new ParseUUIDPipe()) foodId: string) {
    return this.users.removeSave(u.sub, foodId);
  }

  @Get('me/streak')
  streak(@CurrentUser() u: JwtPayload) {
    return this.users.getStreak(u.sub);
  }

  @Post('me/streak/decide')
  bumpDecide(@CurrentUser() u: JwtPayload) {
    return this.users.bumpDecideStreak(u.sub);
  }

  @Get(':id')
  publicProfile(@Param('id', new ParseUUIDPipe()) id: string) {
    return this.users.publicProfile(id);
  }

  @Post(':id/follow')
  follow(@CurrentUser() u: JwtPayload, @Param('id', new ParseUUIDPipe()) id: string) {
    return this.users.follow(u.sub, id);
  }

  @Delete(':id/follow')
  unfollow(@CurrentUser() u: JwtPayload, @Param('id', new ParseUUIDPipe()) id: string) {
    return this.users.unfollow(u.sub, id);
  }
}
