import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../common/prisma/prisma.service';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async me(userId: string) {
    const u = await this.prisma.users.findUnique({ where: { id: userId } });
    if (!u) throw new NotFoundException('User not found');
    const prefs = await this.prisma.user_preferences.findUnique({ where: { user_id: userId } });
    const streaks = await this.prisma.streaks.findUnique({ where: { user_id: userId } });
    const followers = await this.prisma.follows.count({ where: { followee_id: userId } });
    const following = await this.prisma.follows.count({ where: { follower_id: userId } });
    const reviewsCount = await this.prisma.reviews.count({ where: { user_id: userId } });
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

  async updatePreferences(userId: string, prefs: Record<string, unknown>) {
    return this.prisma.user_preferences.upsert({
      where: { user_id: userId },
      update: prefs as any,
      create: { user_id: userId, ...(prefs as any) },
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
    const rows: Array<{ food_id: string; created_at: Date }> = await this.prisma.$queryRawUnsafe(
      `SELECT food_id, created_at FROM saved_items WHERE user_id = $1::uuid ORDER BY created_at DESC LIMIT 200`,
      userId,
    );
    if (!rows.length) return { items: [] };
    const ids = rows.map(r => r.food_id);
    const foods = await this.prisma.foods.findMany({ where: { id: { in: ids } } });
    const byId = new Map(foods.map(f => [f.id, f]));
    return {
      items: rows.map(r => ({
        savedAt: r.created_at,
        food: byId.get(r.food_id) ?? null,
      })).filter(x => x.food !== null),
    };
  }

  async addSave(userId: string, foodId: string) {
    await this.prisma.$executeRawUnsafe(
      `INSERT INTO saved_items (user_id, food_id, collection) VALUES ($1::uuid, $2::uuid, 'default')
       ON CONFLICT (user_id, food_id, collection) DO NOTHING`,
      userId, foodId,
    );
    return { saved: true };
  }

  async removeSave(userId: string, foodId: string) {
    await this.prisma.$executeRawUnsafe(
      `DELETE FROM saved_items WHERE user_id = $1::uuid AND food_id = $2::uuid AND collection = 'default'`,
      userId, foodId,
    );
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
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const existing = await this.prisma.streaks.findUnique({ where: { user_id: userId } });
    if (!existing) {
      return this.prisma.streaks.create({
        data: {
          user_id: userId, daily_decide: 1, best_decide: 1,
          last_decide: today,
        },
      });
    }

    const last = existing.last_decide ? new Date(existing.last_decide) : null;
    if (last) last.setHours(0, 0, 0, 0);

    if (last && last.getTime() === today.getTime()) {
      return existing;
    }

    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);
    const continued = last && last.getTime() === yesterday.getTime();
    const newCount = continued ? existing.daily_decide + 1 : 1;
    const newBest = Math.max(existing.best_decide ?? 0, newCount);
    return this.prisma.streaks.update({
      where: { user_id: userId },
      data: {
        daily_decide: newCount,
        best_decide: newBest,
        last_decide: today,
        updated_at: new Date(),
      },
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
}
