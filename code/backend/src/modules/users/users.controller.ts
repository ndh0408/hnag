import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';

import { UsersService } from './users.service';
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
  update(@CurrentUser() u: JwtPayload, @Body() body: any) {
    if (body.preferences) {
      return this.users.updatePreferences(u.sub, body.preferences);
    }
    return this.users.updateMe(u.sub, body);
  }

  @Get('me/saves')
  listSaves(@CurrentUser() u: JwtPayload) {
    return this.users.listSaves(u.sub);
  }

  @Post('me/saves/:foodId')
  addSave(@CurrentUser() u: JwtPayload, @Param('foodId') foodId: string) {
    return this.users.addSave(u.sub, foodId);
  }

  @Delete('me/saves/:foodId')
  removeSave(@CurrentUser() u: JwtPayload, @Param('foodId') foodId: string) {
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
  publicProfile(@Param('id') id: string) {
    return this.users.publicProfile(id);
  }

  @Post(':id/follow')
  follow(@CurrentUser() u: JwtPayload, @Param('id') id: string) {
    return this.users.follow(u.sub, id);
  }

  @Delete(':id/follow')
  unfollow(@CurrentUser() u: JwtPayload, @Param('id') id: string) {
    return this.users.unfollow(u.sub, id);
  }
}
