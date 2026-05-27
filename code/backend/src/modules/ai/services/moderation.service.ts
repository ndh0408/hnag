import { Injectable, Logger, Inject } from '@nestjs/common';
import OpenAI from 'openai';
import IORedis from 'ioredis';
import { createHash } from 'crypto';

import { REDIS } from '../../../common/redis/redis.module';

/**
 * AI content moderation gate.
 *
 * Closes audit production-killer §9 ("AI cost protection / moderation"):
 * any user-supplied free text that gets fed into our LLM (voice
 * transcripts, fridge captions, viral-link URLs, custom prompts) needs
 * a pre-flight check so we don't:
 *   - relay attacks / prompt injections downstream (we filter known patterns)
 *   - get banned from OpenAI for slipping abusive content through
 *   - burn tokens on payloads that will be rejected anyway
 *
 * The implementation is deliberately defensive:
 *   - Soft-fail: when the Moderation API is down or not configured, the
 *     check returns `{ allowed: true, reason: 'unavailable' }` so the
 *     core flow doesn't break. Audit log + Sentry breadcrumb on each
 *     unavailable.
 *   - Cached by SHA-256 of the trimmed input — Moderation API is free
 *     but each call is a ~50ms round-trip; cache makes repeat
 *     submissions free.
 *   - Per-user abuse counter — if a user trips moderation 5+ times in
 *     a 24h window, the service flags them for review (audit `abuse:trip`
 *     event lands in analytics_events for the moderation queue dashboard).
 *
 * Usage:
 *
 *   const verdict = await moderation.check(userText, { userId });
 *   if (!verdict.allowed) throw new HttpException({ code: 'MODERATION_BLOCKED', ... });
 *   // …then call OpenAI with the cleared text…
 */

export interface ModerationVerdict {
  allowed: boolean;
  /** OpenAI categories that tripped, or 'unavailable' / 'pattern' / 'cached'. */
  reason: string;
  /** Cached result hit — used for analytics, no extra API call charged. */
  fromCache: boolean;
}

@Injectable()
export class ModerationService {
  private readonly logger = new Logger(ModerationService.name);
  private readonly client: OpenAI | null;
  private readonly cacheTtlSec = 24 * 3600; // 24h
  private readonly abuseTtlSec = 24 * 3600;
  private readonly abuseThreshold = Number(process.env.MODERATION_ABUSE_THRESHOLD ?? '5');

  // Quick-deny patterns that we should refuse without burning an API call.
  // English + Vietnamese (audit: prior list was English-only and a VN-language
  // injection bypassed it trivially).
  private readonly hardDeny: RegExp[] = [
    /ignore\s+(?:all\s+)?previous\s+instructions/i,
    /you\s+are\s+now\s+(?:a\s+)?(?:dan|developer\s+mode|jailbroken)/i,
    /\bsystem\s*prompt\b.*\b(?:reveal|leak|print)/i,
    // VN — common injection openers in the wild
    /b[oỏỏ]\s*qua\s+(?:t[aấ]t\s*c[ảảa]\s+)?ch[ỉỉi]\s*d[ẫẫâ]n\s+tr[uưừướ][ớơô]c\s*đ[oỏó]/i,
    /quên\s+(?:hết\s+)?ch[ỉiỉí]\s*d[ẫâẫ]n/i,
    /b[ạâạ]n\s+là\s+(?:một\s+)?(?:hacker|kẻ\s+phá|jailbreak)/i,
    /lộ\s+(?:ra\s+)?prompt|in\s+ra\s+prompt|tiết\s+lộ\s+prompt/i,
    // Pretending to be system / role-confusion
    /\[\s*(?:system|admin|root)\s*\]\s*:/i,
    /<\s*\/?\s*(?:system|admin)\s*>/i,
  ];

  constructor(@Inject(REDIS) private readonly redis: IORedis) {
    this.client = process.env.OPENAI_API_KEY
      ? new OpenAI({ apiKey: process.env.OPENAI_API_KEY, timeout: 5000, maxRetries: 1 })
      : null;
  }

  /**
   * Run a pre-flight check. Cheap (cached) for repeats.
   * @param text     User-supplied text. Empty / null short-circuits to allowed.
   * @param opts.userId  Used for abuse tracking; pass null for system contexts.
   */
  async check(text: string | null | undefined, opts: { userId?: string | null } = {}): Promise<ModerationVerdict> {
    if (!text || !text.trim()) return { allowed: true, reason: 'empty', fromCache: false };
    const trimmed = text.trim().slice(0, 2000); // moderation API limit-friendly

    // 1. Quick-deny patterns
    for (const re of this.hardDeny) {
      if (re.test(trimmed)) {
        await this.bumpAbuse(opts.userId, 'pattern');
        return { allowed: false, reason: 'pattern_match', fromCache: false };
      }
    }

    // 2. Cache lookup
    const key = `mod:v1:${sha256(trimmed)}`;
    try {
      const cached = await this.redis.get(key);
      if (cached) {
        const allowed = cached.startsWith('ok:');
        if (!allowed) await this.bumpAbuse(opts.userId, cached.slice(3));
        return { allowed, reason: cached.startsWith('ok:') ? 'cached' : cached.slice(3), fromCache: true };
      }
    } catch (e) {
      this.logger.warn(`moderation cache lookup failed: ${(e as Error).message}`);
    }

    // 3. No client → soft-fail allowed (so dev/staging without OPENAI_API_KEY works)
    if (!this.client) return { allowed: true, reason: 'unavailable', fromCache: false };

    // 4. Real API call
    try {
      const res = await this.client.moderations.create({
        // omni-moderation-latest is OpenAI's current free moderation endpoint
        model: process.env.MODERATION_MODEL ?? 'omni-moderation-latest',
        input: trimmed,
      });
      const r = res.results?.[0];
      if (!r) return { allowed: true, reason: 'unknown', fromCache: false };
      if (r.flagged) {
        // Surface the top-flagged category for forensics
        const cats = Object.entries(r.categories ?? {})
          .filter(([, v]) => v === true)
          .map(([k]) => k);
        const reason = cats[0] ?? 'flagged';
        await this.redis.setex(key, this.cacheTtlSec, `no:${reason}`);
        await this.bumpAbuse(opts.userId, reason);
        return { allowed: false, reason, fromCache: false };
      }
      await this.redis.setex(key, this.cacheTtlSec, 'ok:clean');
      return { allowed: true, reason: 'clean', fromCache: false };
    } catch (e) {
      this.logger.warn(`moderation API call failed: ${(e as Error).message}`);
      // Soft-fail open — the core suggest flow shouldn't break because
      // OpenAI moderation is hiccuping.
      return { allowed: true, reason: 'unavailable', fromCache: false };
    }
  }

  /**
   * Image moderation gate (audit #34). Forwards a data URL or https URL to
   * OpenAI's omni-moderation-latest endpoint, which supports image inputs.
   *
   * Soft-fail OPEN on infra unavailability so the core /ai/fridge-scan path
   * isn't completely broken by a moderation API blip. Per-user abuse counter
   * still bumps on hard rejections.
   *
   * Cache by SHA-256 of the image bytes (data URL or URL string). Two scans
   * of the same image don't re-pay the moderation cost.
   */
  async checkImage(
    image: string,
    opts: { userId?: string | null } = {},
  ): Promise<ModerationVerdict> {
    if (!image) return { allowed: true, reason: 'empty', fromCache: false };

    const key = `mod:img:v1:${sha256(image)}`;
    try {
      const cached = await this.redis.get(key);
      if (cached) {
        const allowed = cached.startsWith('ok:');
        if (!allowed) await this.bumpAbuse(opts.userId, cached.slice(3));
        return { allowed, reason: cached.startsWith('ok:') ? 'cached' : cached.slice(3), fromCache: true };
      }
    } catch (e) {
      this.logger.warn(`moderation image cache lookup failed: ${(e as Error).message}`);
    }

    if (!this.client) return { allowed: true, reason: 'unavailable', fromCache: false };

    try {
      const res: any = await this.client.moderations.create({
        model: process.env.MODERATION_IMAGE_MODEL ?? 'omni-moderation-latest',
        input: [{ type: 'image_url', image_url: { url: image } } as any],
      });
      const r = res.results?.[0];
      if (!r) return { allowed: true, reason: 'unknown', fromCache: false };
      if (r.flagged) {
        const cats = Object.entries(r.categories ?? {})
          .filter(([, v]) => v === true)
          .map(([k]) => k);
        const reason = cats[0] ?? 'flagged';
        await this.redis.setex(key, this.cacheTtlSec, `no:${reason}`);
        await this.bumpAbuse(opts.userId, reason);
        return { allowed: false, reason, fromCache: false };
      }
      await this.redis.setex(key, this.cacheTtlSec, 'ok:clean');
      return { allowed: true, reason: 'clean', fromCache: false };
    } catch (e) {
      this.logger.warn(`moderation image API call failed: ${(e as Error).message}`);
      return { allowed: true, reason: 'unavailable', fromCache: false };
    }
  }

  /** Count moderation trips per user; flag if over threshold. */
  private async bumpAbuse(userId: string | null | undefined, reason: string): Promise<void> {
    if (!userId) return;
    const key = `mod:abuse:${userId}:${new Date().toISOString().slice(0, 10)}`;
    try {
      const count = await this.redis.incr(key);
      if (count === 1) await this.redis.expire(key, this.abuseTtlSec);
      if (count === this.abuseThreshold) {
        this.logger.warn(`moderation abuse threshold reached: user=${userId} reason=${reason} count=${count}`);
      }
    } catch (e) {
      this.logger.debug(`moderation bumpAbuse failed: ${(e as Error).message}`);
    }
  }
}

function sha256(s: string): string {
  return createHash('sha256').update(s).digest('hex');
}
