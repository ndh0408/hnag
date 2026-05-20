import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/prisma/prisma.service';

@Injectable()
export class ChallengesService {
  constructor(private readonly prisma: PrismaService) {}

  // ─── Daily Quests ────────────────────────────────────────────────────────

  async todayQuests(userId: string) {
    const today = new Date(); today.setHours(0, 0, 0, 0);
    const quests = await this.prisma.daily_quests.findMany({
      where: { active_date: today },
      orderBy: { xp_reward: 'desc' },
      take: 3,
    });
    const progress = await this.prisma.user_quests.findMany({
      where: { user_id: userId, date: today },
    });
    return quests.map((q) => {
      const p = progress.find((x) => x.quest_id === q.id);
      return {
        id: q.id,
        code: q.code,
        name: q.name_vi,
        description: q.description,
        xpReward: q.xp_reward,
        progress: Number(p?.progress ?? 0),
        completed: !!p?.completed_at,
      };
    });
  }

  /**
   * Track an action → maybe complete a quest.
   * Called from food_interactions hooks (orchestrator).
   */
  async trackAction(userId: string, action: string, payload: Record<string, unknown> = {}) {
    const today = new Date(); today.setHours(0, 0, 0, 0);
    const quests = await this.prisma.daily_quests.findMany({ where: { active_date: today } });

    for (const q of quests) {
      const criteria = (q.criteria as { action?: string } | null) ?? {};
      if (criteria.action !== action) continue;

      const existing = await this.prisma.user_quests.findUnique({
        where: { user_id_quest_id_date: { user_id: userId, quest_id: q.id, date: today } },
      });
      if (existing?.completed_at) continue;

      await this.prisma.user_quests.upsert({
        where: { user_id_quest_id_date: { user_id: userId, quest_id: q.id, date: today } },
        update: { progress: 1, completed_at: new Date() },
        create: { user_id: userId, quest_id: q.id, date: today, progress: 1, completed_at: new Date() },
      });
      await this.awardXp(userId, q.xp_reward ?? 0);
    }
  }

  // ─── Achievements ────────────────────────────────────────────────────────

  async myAchievements(userId: string) {
    const all = await this.prisma.achievements.findMany({ orderBy: { tier: 'asc' } });
    const unlocked = await this.prisma.user_achievements.findMany({ where: { user_id: userId } });
    const map = new Map(unlocked.map((u) => [u.achievement_id, u]));
    return all.map((a) => ({
      ...a,
      unlocked: !!map.get(a.id)?.unlocked_at,
      progress: Number(map.get(a.id)?.progress ?? 0),
    }));
  }

  async checkAchievements(userId: string) {
    // Lightweight: check 2 simple ones — extend with all 15 in production
    const user = await this.prisma.users.findUnique({ where: { id: userId } });
    if (!user) return;

    const reviewsCount = await this.prisma.reviews.count({ where: { user_id: userId } });
    if (reviewsCount >= 1) await this.unlock(userId, 'first_review');
    if (reviewsCount >= 30) await this.unlock(userId, 'vua_pho');

    const cookedCount = await this.prisma.food_interactions.count({
      where: { user_id: userId, action: 'cooked' as any },
    });
    if (cookedCount >= 1) await this.unlock(userId, 'first_cook');

    const distinctFoods = await this.prisma.$queryRawUnsafe<{ c: bigint }[]>(
      `SELECT COUNT(DISTINCT food_id)::bigint AS c FROM food_interactions WHERE user_id = $1 AND action IN ('ate','ordered','cooked')`,
      userId,
    );
    if ((Number(distinctFoods[0]?.c) ?? 0) >= 10) await this.unlock(userId, 'ten_dishes');
  }

  // ─── Leaderboard ─────────────────────────────────────────────────────────

  async leaderboard(scope: 'global' | 'weekly' | 'monthly' = 'weekly', city?: string) {
    const since = new Date();
    if (scope === 'weekly')  since.setDate(since.getDate() - 7);
    if (scope === 'monthly') since.setMonth(since.getMonth() - 1);
    if (scope === 'global')  since.setFullYear(2020);

    return this.prisma.$queryRawUnsafe<any[]>(`
      SELECT u.id, u.username, u.display_name, u.avatar_url, u.foodie_class, u.level,
             COUNT(r.id) AS reviews_count, COALESCE(AVG(r.rating), 0)::numeric(3,2) AS rating_avg
      FROM users u
      LEFT JOIN reviews r ON r.user_id = u.id AND r.created_at >= $1
      WHERE u.status = 'active' ${city ? 'AND u.city = $2' : ''}
      GROUP BY u.id
      HAVING COUNT(r.id) > 0
      ORDER BY reviews_count DESC, u.xp DESC
      LIMIT 100;
    `, since, ...(city ? [city] : []));
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  private async unlock(userId: string, code: string) {
    const a = await this.prisma.achievements.findUnique({ where: { code } });
    if (!a) return;
    const existing = await this.prisma.user_achievements.findUnique({
      where: { user_id_achievement_id: { user_id: userId, achievement_id: a.id } },
    });
    if (existing?.unlocked_at) return;
    await this.prisma.user_achievements.upsert({
      where: { user_id_achievement_id: { user_id: userId, achievement_id: a.id } },
      update: { progress: 1, unlocked_at: new Date() },
      create: { user_id: userId, achievement_id: a.id, progress: 1, unlocked_at: new Date() },
    });
    await this.awardXp(userId, a.xp_reward ?? 0);
  }

  private async awardXp(userId: string, xp: number) {
    if (xp <= 0) return;
    const u = await this.prisma.users.update({
      where: { id: userId },
      data: { xp: { increment: xp } },
    });
    // Update foodie_class & level based on xp
    const newLevel = Math.max(1, Math.floor(Math.pow(u.xp / 100, 1 / 2.5)));
    const newClass = this.classFor(newLevel);
    if (newLevel !== u.level || newClass !== u.foodie_class) {
      await this.prisma.users.update({
        where: { id: userId },
        data: { level: newLevel, foodie_class: newClass },
      });
    }
  }

  private classFor(level: number): string {
    if (level >= 50) return 'vua';
    if (level >= 25) return 'rong';
    if (level >= 15) return 'camap';
    if (level >= 10) return 'muc';
    if (level >= 5)  return 'cua';
    return 'tep';
  }
}
