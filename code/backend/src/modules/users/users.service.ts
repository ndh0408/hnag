import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../common/prisma/prisma.service';

@Injectable()
export class UsersService {
  private readonly logger = new Logger(UsersService.name);
  constructor(private readonly prisma: PrismaService) {}

  async me(userId: string) {
    // Audit hnag-audit-2026-05 §11: was 6 sequential queries (~800ms cold).
    // Parallelize via Promise.all so latency is bounded by the slowest single
    // query (~150-250ms cold) instead of the sum.
    const [u, prefs, streaks, followers, following, reviewsCount] = await Promise.all([
      this.prisma.users.findUnique({ where: { id: userId } }),
      this.prisma.user_preferences.findUnique({ where: { user_id: userId } }),
      this.prisma.streaks.findUnique({ where: { user_id: userId } }),
      this.prisma.follows.count({ where: { followee_id: userId } }),
      this.prisma.follows.count({ where: { follower_id: userId } }),
      this.prisma.reviews.count({ where: { user_id: userId } }),
    ]);
    if (!u) throw new NotFoundException('User not found');
    return { user: u, preferences: prefs, streaks, followers, following, reviewsCount };
  }

  async updateMe(userId: string, dto: Partial<{ displayName: string; bio: string; avatarUrl: string; city: string; }>) {
    return this.prisma.users.update({
      where: { id: userId },
      data: {
        display_name: dto.displayName,
        bio: dto.bio,
        avatar_url: dto.avatarUrl,
        city: dto.city,
      },
    });
  }

  // Only these columns may be set by a client — prevents mass-assignment of
  // arbitrary fields (the previous `prefs as any` wrote whatever was sent).
  private static readonly ALLOWED_PREF_KEYS = new Set([
    'allergies', 'diet_type', 'cuisines_love', 'cuisines_hate',
    'spicy_tolerance', 'sweet_tolerance', 'salty_tolerance',
    'budget_min', 'budget_max', 'cook_skill', 'health_goal',
    'daily_calorie', 'macros_target', 'notification_pref',
  ]);

  async updatePreferences(userId: string, prefs: Record<string, unknown>) {
    const clean: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(prefs ?? {})) {
      if (UsersService.ALLOWED_PREF_KEYS.has(k)) clean[k] = v;
    }
    return this.prisma.user_preferences.upsert({
      where: { user_id: userId },
      update: clean as any,
      create: { user_id: userId, ...(clean as any) },
    });
  }

  async follow(followerId: string, followeeId: string) {
    if (followerId === followeeId) return;
    await this.prisma.follows.upsert({
      where: { follower_id_followee_id: { follower_id: followerId, followee_id: followeeId } },
      update: {},
      create: { follower_id: followerId, followee_id: followeeId },
    });
  }

  async unfollow(followerId: string, followeeId: string) {
    await this.prisma.follows.deleteMany({ where: { follower_id: followerId, followee_id: followeeId } });
  }

  async listSaves(userId: string) {
    const rows = await this.prisma.saved_items.findMany({
      where: { user_id: userId },
      orderBy: { created_at: 'desc' },
      take: 200,
      select: { food_id: true, created_at: true },
    });
    if (!rows.length) return { items: [] };
    const ids = rows.map((r) => r.food_id).filter((id): id is string => !!id);
    const foods = await this.prisma.foods.findMany({ where: { id: { in: ids } } });
    const byId = new Map(foods.map((f) => [f.id, f]));
    return {
      items: rows
        .map((r) => ({ savedAt: r.created_at, food: r.food_id ? byId.get(r.food_id) ?? null : null }))
        .filter((x) => x.food !== null),
    };
  }

  async addSave(userId: string, foodId: string) {
    // createMany + skipDuplicates is the typed equivalent of
    // INSERT ... ON CONFLICT DO NOTHING. Replaces the audit-flagged raw SQL.
    await this.prisma.saved_items.createMany({
      data: [{ user_id: userId, food_id: foodId, collection: 'default' }],
      skipDuplicates: true,
    });
    return { saved: true };
  }

  async removeSave(userId: string, foodId: string) {
    await this.prisma.saved_items.deleteMany({
      where: { user_id: userId, food_id: foodId, collection: 'default' },
    });
    return { saved: false };
  }

  async getStreak(userId: string) {
    const row = await this.prisma.streaks.findUnique({ where: { user_id: userId } });
    return row ?? {
      user_id: userId, daily_decide: 0, daily_open: 0, cook_streak: 0, review_streak: 0,
      best_decide: 0, best_cook: 0,
    };
  }

  async bumpDecideStreak(userId: string) {
    // Audit #46: streak day boundaries are computed in Asia/Ho_Chi_Minh,
    // not in the server's local TZ (which is UTC on the deploy VM). Without
    // this, a user who decides at 22:00 VN time on Monday and 09:00 VN time
    // on Tuesday counted as "same day" because UTC midnight is 07:00 VN.
    //
    // Strategy: compute "today VN" as a YYYY-MM-DD string in Asia/Ho_Chi_Minh,
    // then store as a UTC midnight Date that round-trips faithfully via the
    // PostgreSQL `date` type (last_decide is @db.Date). All comparisons stay
    // in the date-string space.
    return this.prisma.$transaction(async (tx) => {
      const todayStr = vnDateString(new Date());
      const today = vnDateStringToUtcMidnight(todayStr);
      const yesterdayStr = vnDateString(new Date(Date.now() - 24 * 3600 * 1000));

      const existing = await tx.streaks.findUnique({
        where: { user_id: userId },
        select: { daily_decide: true, last_decide: true, best_decide: true },
      });
      if (!existing) {
        return tx.streaks.create({
          data: { user_id: userId, daily_decide: 1, best_decide: 1, last_decide: today },
        });
      }

      const lastStr = existing.last_decide ? vnDateString(new Date(existing.last_decide)) : null;
      if (lastStr === todayStr) {
        return tx.streaks.findUnique({ where: { user_id: userId } });
      }
      const continued = lastStr === yesterdayStr;
      const newCount = continued ? (existing.daily_decide ?? 0) + 1 : 1;
      const newBest = Math.max(existing.best_decide ?? 0, newCount);
      const result = await tx.streaks.updateMany({
        where: {
          user_id: userId,
          OR: [{ last_decide: null }, { last_decide: { lt: today } }],
        },
        data: {
          daily_decide: newCount,
          best_decide: newBest,
          last_decide: today,
          updated_at: new Date(),
        },
      });
      if (result.count === 0) {
        return tx.streaks.findUnique({ where: { user_id: userId } });
      }
      return tx.streaks.findUnique({ where: { user_id: userId } });
    });
  }

  async publicProfile(id: string) {
    const u = await this.prisma.users.findUnique({ where: { id } });
    if (!u) throw new NotFoundException();
    const followers = await this.prisma.follows.count({ where: { followee_id: id } });
    const following = await this.prisma.follows.count({ where: { follower_id: id } });
    const reviews = await this.prisma.reviews.count({ where: { user_id: id } });
    return {
      id: u.id, username: u.username, displayName: u.display_name, avatarUrl: u.avatar_url,
      bio: u.bio, city: u.city, level: u.level, foodieClass: u.foodie_class,
      isPremium: u.is_premium, isVerified: u.is_verified,
      followers, following, reviewsCount: reviews,
    };
  }

  /**
   * Delete the user account and all personally-identifying data.
   *
   * Compliance:
   *   - App Store Review Guideline 5.1.1(v) requires an in-app deletion path
   *     for any app that allows account creation.
   *   - Vietnam Decree 13/2023/ND-CP on Personal Data Protection grants the
   *     data subject the right to erasure.
   *
   * Soft-delete-then-purge strategy:
   *   1. Immediately anonymise the row + flip status to 'deleted' so the
   *      user disappears from every public-facing query (joins, search,
   *      leaderboard).
   *   2. Revoke every auth session so existing devices lose access.
   *   3. Hard-delete via the schema's onDelete:Cascade relationships will
   *      eventually be done by a separate purge job after 30 days, giving
   *      ops a window to recover from accidental deletions and satisfy
   *      legal-hold requirements.
   *
   * Payment / billing records (`payment_events`) keep `user_id` set to NULL
   * via the FK; the audit trail is preserved for accounting / PDPL records.
   */
  async deleteAccount(
    userId: string,
    audit?: { source?: 'app' | 'web' | 'admin' | 'api'; ip?: string; userAgent?: string; reason?: string },
  ) {
    const u = await this.prisma.users.findUnique({ where: { id: userId } });
    if (!u) throw new NotFoundException('User not found');
    if (u.status === 'deleted') {
      return { ok: true, alreadyDeleted: true };
    }

    const anonEmail = `deleted+${userId.replace(/-/g, '').slice(0, 16)}@hnag.invalid`;
    const anonUsername = `deleted_${userId.replace(/-/g, '').slice(0, 8)}`;

    // Snapshot stats BEFORE we drop the side-table rows, so the deletion
    // log carries forensic counters for compliance audits.
    const [followers, following, reviews, ordersCount, sessionsActive] = await Promise.all([
      this.prisma.follows.count({ where: { followee_id: userId } }),
      this.prisma.follows.count({ where: { follower_id: userId } }),
      this.prisma.reviews.count({ where: { user_id: userId } }),
      this.prisma.orders.count({ where: { user_id: userId } }),
      this.prisma.auth_sessions.count({ where: { user_id: userId, revoked_at: null } }),
    ]);

    await this.prisma.users.update({
      where: { id: userId },
      data: {
        status: 'deleted',
        email: anonEmail,
        phone: null,
        username: anonUsername,
        display_name: 'Tài khoản đã xoá',
        avatar_url: null,
        bio: null,
        city: null,
        is_verified: false,
        is_premium: false,
        premium_until: null,
        last_seen_at: null,
      },
    });

    // Kill every active session for this user. Future logins are blocked by
    // the jwt strategy checking user.status (separately implemented).
    await this.prisma.auth_sessions.updateMany({
      where: { user_id: userId, revoked_at: null },
      data: { revoked_at: new Date() },
    });

    // Drop personal-data side tables we own outright.
    await this.prisma.user_preferences.deleteMany({ where: { user_id: userId } });
    await this.prisma.user_devices.deleteMany({ where: { user_id: userId } });
    await this.prisma.follows.deleteMany({
      where: { OR: [{ follower_id: userId }, { followee_id: userId }] },
    });

    // Audit #21: posts / reviews / comments retain user_id but the user row
    // is soft-deleted (status='deleted') with PII anonymised; cascading
    // hard-delete is deferred 30d so accidental deletions can be undone.
    // Until the purge cron runs, scrub the FREE-TEXT fields so an active
    // viewer doesn't see the user's words attributed to "Tài khoản đã xoá".
    await this.prisma.posts.updateMany({
      where: { user_id: userId },
      data: { caption: null, is_archived: true },
    });
    await this.prisma.reviews.updateMany({
      where: { user_id: userId },
      data: { title: null, content: null, images: [] },
    });
    // post_comments has no Prisma relation back to users; scrub text directly.
    try {
      await this.prisma.$executeRawUnsafe(
        `UPDATE post_comments SET content = '[đã xoá]' WHERE user_id = $1::uuid`,
        userId,
      );
    } catch (err) {
      this.logger.warn(`post_comments anonymise failed: ${(err as Error).message}`);
    }

    // Forensic trail (App Store 5.1.1(v) + Decree 13/2023). Email + IP are
    // stored ONLY as SHA-256 fingerprints so the log is itself
    // privacy-respecting while remaining matchable for a "this was my
    // account" support request.
    try {
      await this.prisma.account_deletions.create({
        data: {
          user_id: userId,
          email_hash: u.email ? sha256(u.email.toLowerCase()) : null,
          ip_hash: audit?.ip ? sha256(audit.ip) : null,
          user_agent: audit?.userAgent?.slice(0, 500) ?? null,
          reason: audit?.reason ?? 'user_initiated',
          source: audit?.source ?? 'app',
          payload_summary: {
            followers, following, reviews, ordersCount, sessionsRevoked: sessionsActive,
          } as any,
        },
      });
    } catch (err) {
      // The audit row is non-blocking — if the table doesn't exist yet
      // (12_account_deletions.sql not applied) we still complete the
      // delete. Log loudly so ops notices.
      this.logger.warn(`account_deletions write failed: ${(err as Error).message}`);
    }

    return { ok: true, deletedAt: new Date().toISOString() };
  }
}

// eslint-disable-next-line @typescript-eslint/no-var-requires
const { createHash } = require('crypto') as typeof import('crypto');
function sha256(s: string): string {
  return createHash('sha256').update(s).digest('hex');
}

/**
 * Audit #46: "Today" for streak purposes must be Asia/Ho_Chi_Minh (UTC+7),
 * not the deploy VM's UTC. A user deciding at 22:00 VN (15:00 UTC) on Monday
 * and 09:00 VN (02:00 UTC) on Tuesday must count as TWO different days; the
 * old code computed in UTC and treated them as same-day.
 *
 * `Intl.DateTimeFormat` is the only stdlib-correct way to get a YYYY-MM-DD
 * string in a specific named TZ without pulling a dependency. It's slower
 * than direct math but called once per streak bump, so cheap enough.
 */
function vnDateString(d: Date): string {
  const fmt = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Ho_Chi_Minh',
    year: 'numeric', month: '2-digit', day: '2-digit',
  });
  return fmt.format(d); // en-CA gives "YYYY-MM-DD" already
}

function vnDateStringToUtcMidnight(s: string): Date {
  // Date "YYYY-MM-DD" parsed as UTC midnight — round-trips cleanly with the
  // PostgreSQL `date` type which is TZ-less.
  return new Date(`${s}T00:00:00Z`);
}
