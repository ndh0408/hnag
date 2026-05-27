import { Body, Controller, Post, UseGuards, HttpCode } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { Throttle } from '@nestjs/throttler';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { z } from 'zod';

import { AiOrchestratorService } from './services/ai-orchestrator.service';
import { FridgeService } from './services/fridge.service';
import { VoiceService, audioExtFromMime } from './services/voice.service';
import { ModerationService } from './services/moderation.service';
import { HttpException, HttpStatus } from '@nestjs/common';
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

const FridgeScanDto = z.object({
  // data URL or https URL; ~8MB base64 ≈ 6MB image
  imageBase64: z.string().min(16).max(8_000_000),
});

const VoiceDto = z.object({
  audioBase64: z.string().min(16).max(14_000_000),
  mime: z.string().max(64).optional(),
});

@ApiTags('AI')
@ApiBearerAuth()
@UseGuards(AuthGuard('jwt'))
@Controller('ai')
export class AiController {
  constructor(
    private readonly orchestrator: AiOrchestratorService,
    private readonly fridge: FridgeService,
    private readonly voice: VoiceService,
    private readonly moderation: ModerationService,
  ) {}

  /** Fridge Scan — detect ingredients from a photo (GPT-4o vision) → recipes. */
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('fridge-scan')
  @HttpCode(200)
  async fridgeScan(
    @CurrentUser() _u: JwtPayload,
    @Body(new ZodValidationPipe(FridgeScanDto)) body: z.infer<typeof FridgeScanDto>,
  ) {
    const detected = await this.fridge.detectIngredients(body.imageBase64);
    const result = await this.fridge.matchRecipes(detected);
    return { detected, ...result };
  }

  /** Voice "Hỏi Hà" — Whisper transcribe → intent → suggestions. */
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('voice')
  @HttpCode(200)
  async voiceAsk(
    @CurrentUser() user: JwtPayload,
    @Body(new ZodValidationPipe(VoiceDto)) body: z.infer<typeof VoiceDto>,
  ) {
    const raw = body.audioBase64.replace(/^data:audio\/[^;]+;base64,/, '');
    const buf = Buffer.from(raw, 'base64');
    const transcript = await this.voice.transcribe(buf, `audio.${audioExtFromMime(body.mime)}`);

    // Moderation gate: user-supplied audio transcripts could carry abuse /
    // prompt injection. Check before paying GPT for intent extraction.
    const verdict = await this.moderation.check(transcript, { userId: user.sub });
    if (!verdict.allowed) {
      throw new HttpException(
        { code: 'MODERATION_BLOCKED', message: 'Nội dung không phù hợp', reason: verdict.reason },
        HttpStatus.UNPROCESSABLE_ENTITY,
      );
    }

    const intent = await this.voice.intent(transcript);
    const result = intent.mood
      ? await this.orchestrator.suggestByMood({ userId: user.sub, isPremium: !!user.isPremium, mood: intent.mood })
      : await this.orchestrator.suggest({ userId: user.sub, isPremium: !!user.isPremium, mode: 'voice', context: { mood: intent.query }, limit: 6 });
    return { transcript, intent, ...result };
  }

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
