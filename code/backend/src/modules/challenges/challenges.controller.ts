import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { ChallengesService } from './challenges.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/strategies/jwt.strategy';

@ApiTags('Challenges')
@Controller('challenges')
export class ChallengesController {
  constructor(private readonly svc: ChallengesService) {}

  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Get('quests/today')
  todayQuests(@CurrentUser() u: JwtPayload) {
    return this.svc.todayQuests(u.sub);
  }

  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Get('achievements/me')
  myAchievements(@CurrentUser() u: JwtPayload) {
    return this.svc.myAchievements(u.sub);
  }

  @Get('leaderboard')
  leaderboard(@Query('scope') scope?: 'global' | 'weekly' | 'monthly', @Query('city') city?: string) {
    return this.svc.leaderboard(scope ?? 'weekly', city);
  }
}
