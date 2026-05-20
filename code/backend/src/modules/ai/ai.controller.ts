import { Body, Controller, Post, UseGuards, HttpCode } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { Throttle } from '@nestjs/throttler';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { z } from 'zod';

import { AiOrchestratorService } from './services/ai-orchestrator.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import { JwtPayload } from '../auth/strategies/jwt.strategy';

const ContextSchema = z.object({
  hunger: z.number().int().min(1).max(10).optional(),
  budget: z.object({ min: z.number().int(), max: z.number().int() }).optional(),
  timeMin: z.number().int().min(1).max(360).optional(),
  mood: z.string().optional(),
  with: z.enum(['solo', 'couple', 'friends', 'family']).optional(),
  location: z.object({ lat: z.number(), lng: z.number() }).optional(),
  diet: z.string().optional(),
  cuisinePref: z.array(z.string()).optional(),
});

const SuggestDto = z.object({
  mode: z.enum(['quick', 'detail', 'mood', 'voice', 'fridge', 'group']),
  context: ContextSchema,
  limit: z.number().int().min(1).max(10).default(5),
});

const FeedbackDto = z.object({
  sessionId: z.string().uuid(),
  foodId: z.string().uuid(),
  action: z.enum(['view', 'save', 'skip', 'cook', 'order', 'dine', 'rate']),
  rating: z.number().int().min(1).max(5).optional(),
  reason: z.string().optional(),
});

const MoodDto = z.object({
  mood: z.enum(['happy', 'sad', 'stress', 'lonely', 'chill', 'late_night', 'tired', 'rushed', 'broke']),
  location: z.object({ lat: z.number(), lng: z.number() }).optional(),
});

const MatchLinkDto = z.object({
  url: z.string().url(),
  location: z.object({ lat: z.number(), lng: z.number() }).optional(),
});

@ApiTags('AI')
@ApiBearerAuth()
@UseGuards(AuthGuard('jwt'))
@Controller('ai')
export class AiController {
  constructor(private readonly orchestrator: AiOrchestratorService) {}

  // Free users: 10/min · premium: unlimited (enforced inside orchestrator)
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @Post('suggest')
  @HttpCode(200)
  async suggest(
    @CurrentUser() user: JwtPayload,
    @Body(new ZodValidationPipe(SuggestDto)) body: z.infer<typeof SuggestDto>,
  ) {
    return this.orchestrator.suggest({
      userId: user.sub,
      isPremium: !!user.isPremium,
      mode: body.mode,
      context: body.context,
      limit: body.limit,
    });
  }

  @Post('feedback')
  @HttpCode(200)
  async feedback(
    @CurrentUser() user: JwtPayload,
    @Body(new ZodValidationPipe(FeedbackDto)) body: z.infer<typeof FeedbackDto>,
  ) {
    await this.orchestrator.recordFeedback({
      userId: user.sub,
      sessionId: body.sessionId,
      foodId: body.foodId,
      action: body.action,
      rating: body.rating,
      reason: body.reason,
    });
    return { ok: true };
  }

  @Post('refresh')
  @HttpCode(200)
  async refresh(
    @CurrentUser() user: JwtPayload,
    @Body() body: { sessionId: string },
  ) {
    return this.orchestrator.refresh(user.sub, body.sessionId);
  }

  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @Post('mood')
  @HttpCode(200)
  async mood(
    @CurrentUser() user: JwtPayload,
    @Body(new ZodValidationPipe(MoodDto)) body: z.infer<typeof MoodDto>,
  ) {
    return this.orchestrator.suggestByMood({
      userId: user.sub,
      isPremium: !!user.isPremium,
      mood: body.mood,
      location: body.location,
    });
  }

  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  @Post('match-link')
  @HttpCode(200)
  async matchLink(
    @CurrentUser() user: JwtPayload,
    @Body(new ZodValidationPipe(MatchLinkDto)) body: z.infer<typeof MatchLinkDto>,
  ) {
    return this.orchestrator.matchViralLink({
      userId: user.sub,
      url: body.url,
      location: body.location,
    });
  }
}
