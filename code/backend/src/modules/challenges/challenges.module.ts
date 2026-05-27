import { Module } from '@nestjs/common';
import { ChallengesController } from './challenges.controller';
import { ChallengesService } from './challenges.service';
import { LeaderboardRefreshCron } from './leaderboard-refresh.cron';

@Module({
  controllers: [ChallengesController],
  providers: [ChallengesService, LeaderboardRefreshCron],
  exports: [ChallengesService],
})
export class ChallengesModule {}
