import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Product analytics writer.
 *
 * Audit hnag-audit-2026-05 prompt-pack §11: user-behavior / session /
 * recommendation / search analytics had no store. This service is the
 * single write endpoint for high-volume product events — fire-and-forget
 * (never blocks the caller, errors swallowed and logged).
 *
 * Schema in code/sql/13_analytics_events.sql. We use $executeRawUnsafe
 * with proper parameterisation so the row insert is one statement; under
 * load, a future improvement is to batch writes (BullMQ queue) but at
 * current scale a per-event insert is fine.
 *
 * Usage:
 *
 *     // Anywhere in a service / controller:
 *     this.analytics.track({
 *       event: 'suggest:impression',
 *       userId: u.sub,
 *       sessionId,
 *       properties: { mode: 'mood', cards: cards.length, llmUsed: true },
 *     });
 *
 * Naming convention for `event`: `<domain>:<action>` (`food:view`,
 * `search:query`, `screen:enter`, `ai:feedback`). Keep them stable —
 * dashboards downstream depend on the strings.
 */
export interface AnalyticsEvent {
  event: string;
  userId?: string | null;
  sessionId?: string | null;
  source?: 'app' | 'web' | 'owner-dash' | 'admin';
  appVersion?: string;
  platform?: 'ios' | 'android' | 'web';
  city?: string;
  properties?: Record<string, unknown>;
}

@Injectable()
export class AnalyticsService {
  private readonly logger = new Logger(AnalyticsService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Fire-and-forget. The caller does NOT await this — the write is
   * non-blocking by design. Failures are logged at debug level (we don't
   * want to wake the on-call for a stat row miss).
   */
  track(event: AnalyticsEvent): void {
    // Voluntarily detach from the caller's promise chain.
    this.persist(event).catch((err) => {
      // analytics_events table not applied yet? Log once at warn (visible
      // on first boot) and never again at info.
      const msg = (err as Error).message;
      if (/relation .* does not exist/i.test(msg)) {
        this.logger.warn('analytics_events not found — apply code/sql/13_analytics_events.sql');
        return;
      }
      this.logger.debug(`analytics write failed (${event.event}): ${msg}`);
    });
  }

  /** Sync variant for tests / scripts. Prefer `track` in request paths. */
  async trackAwait(event: AnalyticsEvent): Promise<void> {
    await this.persist(event);
  }

  private async persist(e: AnalyticsEvent): Promise<void> {
    await this.prisma.$executeRawUnsafe(
      `INSERT INTO analytics_events
         (user_id, session_id, event, source, app_version, platform, city, properties)
       VALUES ($1::uuid, $2::uuid, $3, $4, $5, $6, $7, $8::jsonb)`,
      e.userId ?? null,
      e.sessionId ?? null,
      e.event,
      e.source ?? null,
      e.appVersion ?? null,
      e.platform ?? null,
      e.city ?? null,
      JSON.stringify(e.properties ?? {}),
    );
  }
}
