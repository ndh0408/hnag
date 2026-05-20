import { Body, Controller, Get, Post, Put, Query, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { NotificationsService } from './notifications.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/strategies/jwt.strategy';

@ApiTags('Notifications')
@ApiBearerAuth()
@UseGuards(AuthGuard('jwt'))
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notif: NotificationsService) {}

  @Get()
  list(@CurrentUser() u: JwtPayload, @Query('unread') unread?: string, @Query('page') page?: string) {
    return this.notif.list(u.sub, { unread: unread === 'true', page: page ? parseInt(page) : 1 });
  }

  @Post('read')
  markRead(@CurrentUser() u: JwtPayload, @Body() body: { ids: string[] }) {
    return this.notif.markRead(u.sub, body.ids);
  }

  @Put('prefs')
  prefs(@CurrentUser() u: JwtPayload, @Body() body: Record<string, unknown>) {
    return this.notif.updatePrefs(u.sub, body);
  }
}
