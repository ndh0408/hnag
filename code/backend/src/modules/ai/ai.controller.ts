import { Body, Controller, Post, UseGuards, HttpCode } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { Throttle } from '@nestjs/throttler';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { z } from 'zod';

import { AiOrchestratorService } from './services/ai-orchestrator.service';
import { FridgeService } from './services/fridge.service';
import { VoiceService, audioExtFromMime } from './services/voice.service';
import { ModerationService } from './services/moderation.service';
import { newCostTracker } from './services/llm-reason.service';
import { AiCooldown, AiCooldownGuard } from '../../common/guards/ai-cooldown.guard';
import { Premium } from '../../common/guards/premium.guard';
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

// Audit #19, #20: tightened upload caps. The previous 14MB audio / 8MB image
// let a logged-in user run up O($100/hour) of OpenAI vendor cost.
//
//   audioBase64 max 2.7MB ≈ 2MB binary ≈ 60s @ 256kbps — enough for a
//   single voice query; longer audio is artisanal cost amplification.
//   imageBase64 max 2.7MB ≈ 2MB binary — well above a downsized 1280px JPEG.
const FridgeScanDto = z.object({
  imageBase64: z.string().min(16).max(2_700_000),
});

const VoiceDto = z.object({
  audioBase64: z.string().min(16).max(2_700_000),
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

  /**
   * Fridge Scan — detect ingredients from a photo (GPT-4o vision) → recipes.
   *
   * Audit #20: Premium-gated to bound vendor cost amplification (a 6MB
   * vision call costs ~$0.05 each; an abuser could run hundreds for free).
   * Free users get the text-based `/ai/fridge-recipes` instead.
   */
  @Premium()
  @UseGuards(AiCooldownGuard)
  @AiCooldown(3000)
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Post('fridge-scan')
  @HttpCode(200)
  async fridgeScan(
    @CurrentUser() user: JwtPayload,
    @Body(new ZodValidationPipe(FridgeScanDto)) body: z.infer<typeof FridgeScanDto>,
  ) {
    // Audit AI-trace §C-2: track vision spend so org-wide kill switch
    // + per-user budget sees this call (was: untracked → silent burn).
    const tracker = newCostTracker();
    const detected = await this.fridge.detectIngredients(body.imageBase64, {
      userId: user.sub,
      tracker,
    });
    const result = await this.fridge.matchRecipes(detected);
    // Push spend to the shared spend counters for this user + org.
    await this.orchestrator.chargeStandaloneCall(user.sub, tracker, 'fridge-scan');
    return { detected, ...result };
  }

  /**
   * Voice "Hỏi Hà" — Whisper transcribe → intent → suggestions.
   *
   * Audit #19: Premium-gated. Audio is also capped at 2.7MB in DTO so a
   * single call cannot transcribe > ~60s.
   */
  @Premium()
  @UseGuards(AiCooldownGuard)
  @AiCooldown(3000)
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Post('voice')
  @HttpCode(200)
  async voiceAsk(
    @CurrentUser() user: JwtPayload,
    @Body(new ZodValidationPipe(VoiceDto)) body: z.infer<typeof VoiceDto>,
  ) {
    // Audit AI-trace §C-1: shared cost tracker so Whisper + GPT-4o-mini
    // intent both feed org spend counters.
    const tracker = newCostTracker();
    const raw = body.audioBase64.replace(/^data:audio\/[^;]+;base64,/, '');
    const buf = Buffer.from(raw, 'base64');
    const transcript = await this.voice.transcribe(buf, `audio.${audioExtFromMime(body.mime)}`, tracker);

    const verdict = await this.moderation.check(transcript, { userId: user.sub });
    if (!verdict.allowed) {
      // Charge what we already spent (Whisper) even on moderation block.
      await this.orchestrator.chargeStandaloneCall(user.sub, tracker, 'voice');
      throw new HttpException(
        { code: 'MODERATION_BLOCKED', message: 'Nội dung không phù hợp', reason: verdict.reason },
        HttpStatus.UNPROCESSABLE_ENTITY,
      );
    }

    const intent = await this.voice.intent(transcript, tracker);
    // Charge before the suggest call — suggest has its OWN tracker.
    await this.orchestrator.chargeStandaloneCall(user.sub, tracker, 'voice');

    const result = intent.mood
      ? await this.orchestrator.suggestByMood({ userId: user.sub, isPremium: !!user.isPremium, mood: intent.mood })
      : await this.orchestrator.suggest({ userId: user.sub, isPremium: !!user.isPremium, mode: 'voice', context: { mood: intent.query }, limit: 6 });
    return { transcript, intent, ...result };
  }

  // Free users: 10/min · premium: unlimited (enforced inside orchestrator)
  // + 2s per-user cooldown so double-tap / mash-refresh doesn't burn the
  // daily LLM budget (audit production-killer §9). Throttle is per-IP;
  // cooldown is per-user, so abuse from one account behind shared IP is
  // still blocked even when the throttle bucket has headroom.
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @UseGuards(AiCooldownGuard)
  @AiCooldown(2000)
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
