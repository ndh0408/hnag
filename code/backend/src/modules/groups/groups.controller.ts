import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { GroupsService } from './groups.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/strategies/jwt.strategy';

@ApiTags('Groups')
@ApiBearerAuth()
@UseGuards(AuthGuard('jwt'))
@Controller('groups')
export class GroupsController {
  constructor(private readonly groups: GroupsService) {}

  @Get()
  myGroups(@CurrentUser() u: JwtPayload) {
    return this.groups.myGroups(u.sub);
  }

  @Post()
  create(@CurrentUser() u: JwtPayload, @Body() body: { name: string; type?: string }) {
    return this.groups.create(u.sub, body.name, body.type);
  }

  @Post(':id/members')
  join(@Param('id') id: string, @CurrentUser() u: JwtPayload, @Body() body: { inviteCode: string }) {
    return this.groups.join(u.sub, id, body.inviteCode);
  }

  @Post(':id/polls')
  createPoll(
    @Param('id') id: string,
    @CurrentUser() u: JwtPayload,
    @Body() body: { options: { foodId?: string; restaurantId?: string }[]; closesInMinutes?: number },
  ) {
    return this.groups.createPoll(u.sub, id, body);
  }

  @Post(':id/polls/:pollId/vote')
  vote(
    @Param('id') id: string,
    @Param('pollId') pollId: string,
    @CurrentUser() u: JwtPayload,
    @Body() body: { optionIdx: number },
  ) {
    return this.groups.vote(u.sub, id, pollId, body.optionIdx);
  }

  @Get(':id/polls/:pollId/result')
  result(@Param('id') id: string, @Param('pollId') pollId: string, @CurrentUser() u: JwtPayload) {
    return this.groups.result(u.sub, id, pollId);
  }
}
