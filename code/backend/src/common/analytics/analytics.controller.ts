import { Body, Controller, HttpCode, Post, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { z } from 'zod';

import { AnalyticsService } from './analytics.service';
import { CurrentUser } from '../decorators/current-user.decorator';
import { JwtPayload } from '../../modules/auth/strategies/jwt.strategy';
import { ZodValidationPipe } from '../pipes/zod-validation.pipe';

/**
 * Front-end analytics ingest.
 *
 * Closes audit production-killer §6 — Flutter (`lib/observability/analytics.dart`)
 * buffers events client-side then POSTs in batches of up to 50.
 * Server-side this controller validates + drops them into `analytics_events`
 * via the same `AnalyticsService.track` used by backend code.
 *
 * Validation rules:
 *   - max 50 events per batch (matches client buffer cap)
 *   - event name ≤ 80 chars (sanity)
 *   - properties JSON ≤ 4 KB serialised (Postgres jsonb has no hard
 *     limit but we cap to avoid abusive payloads)
 *
 * Throttle: 6 batches/min/user × 50 events = 300 events/min/user ceiling.
 * That's well above legitimate usage (≈30 events/min for active swiping).
 */
const BatchDto = z.object({
  events: z.array(
    z.object({
      event: z.string().min(1).max(80),
      properties: z.record(z.any()).optional().default({}),
      occurredAt: z.string().optional(),
    }),
  ).min(1).max(50),
});

@ApiTags('Analytics')
@ApiBearerAuth()
@UseGuards(AuthGuard('jwt'))
@Controller('analytics')
export class AnalyticsController {
  constructor(private readonly analytics: AnalyticsService) {}

  @Throttle({ default: { limit: 6, ttl: 60_000 } })
  @Post('batch')
  @HttpCode(202)
  ingest(
    @CurrentUser() u: JwtPayload,
    @Body(new ZodValidationPipe(BatchDto)) body: z.infer<typeof BatchDto>,
  ) {
    for (const e of body.events) {
      // Sanity-limit serialized properties so a malicious client can't
      // pad the JSON column with megabytes.
      const props = e.properties ?? {};
      let propsJson: string;
      try {
        propsJson = JSON.stringify(props);
      } catch {
        continue;
      }
      if (propsJson.length > 4096) continue;

      this.analytics.track({
        event: e.event,
        userId: u.sub,
        source: 'app',
        properties: props,
      });
    }
    return { accepted: body.events.length };
  }
}
