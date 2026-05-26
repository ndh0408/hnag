import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../common/prisma/prisma.service';

@Injectable()
export class PostsService {
  constructor(private readonly prisma: PrismaService) {}

  async create(userId: string, dto: {
    type: 'photo' | 'video' | 'review' | 'story';
    caption?: string;
    mediaUrl: string;
    mediaPoster?: string;
    foodId?: string;
    restaurantId?: string;
    tags?: string[];
  }) {
    return this.prisma.posts.create({
      data: {
        user_id: userId,
        type: dto.type,
        caption: dto.caption,
        media_url: dto.mediaUrl,
        media_poster: dto.mediaPoster,
        food_id: dto.foodId,
        restaurant_id: dto.restaurantId,
        tags: dto.tags ?? [],
      },
    });
  }

  async feed(userId: string, tab: 'for_you' | 'following' | 'nearby' | 'trending', page: number) {
    const limit = 20;
    const skip = (page - 1) * limit;

    if (tab === 'following') {
      const follows = await this.prisma.follows.findMany({ where: { follower_id: userId } });
      const followeeIds = follows.map((f) => f.followee_id);
      if (followeeIds.length === 0) return [];
      return this.prisma.posts.findMany({
        where: { user_id: { in: followeeIds }, is_archived: false },
        orderBy: { created_at: 'desc' },
        take: limit, skip,
        include: { users: { select: { id: true, username: true, display_name: true, avatar_url: true } } },
      });
    }
    // for_you / trending — sort by recent + engagement
    return this.prisma.posts.findMany({
      where: { is_archived: false },
      orderBy: [{ like_count: 'desc' }, { created_at: 'desc' }],
      take: limit, skip,
      include: { users: { select: { id: true, username: true, display_name: true, avatar_url: true } } },
    });
  }

  async detail(id: string) {
    const post = await this.prisma.posts.findUnique({
      where: { id },
      include: {
        users: { select: { id: true, username: true, display_name: true, avatar_url: true } },
      },
    });
    if (!post) throw new NotFoundException();
    return post;
  }

  async like(userId: string, postId: string) {
    try {
      await this.prisma.post_likes.create({
        data: { user_id: userId, post_id: postId },
      });
      await this.prisma.posts.update({ where: { id: postId }, data: { like_count: { increment: 1 } } });
    } catch {
      // already liked — ignore
    }
    return { liked: true };
  }

  async unlike(userId: string, postId: string) {
    const r = await this.prisma.post_likes.deleteMany({ where: { user_id: userId, post_id: postId } });
    if (r.count > 0) {
      await this.prisma.posts.update({ where: { id: postId }, data: { like_count: { decrement: 1 } } });
    }
    return { liked: false };
  }

  async comment(userId: string, postId: string, content: string, parentId?: string) {
    const trimmed = content.trim();
    if (!trimmed) throw new NotFoundException('Empty comment');
    const c = await this.prisma.post_comments.create({
      data: { user_id: userId, post_id: postId, content: trimmed, parent_id: parentId },
    });
    await this.prisma.posts.update({ where: { id: postId }, data: { comment_count: { increment: 1 } } });
    // Hydrate author info so the client can render immediately without a refetch.
    const author = await this.prisma.users.findUnique({
      where: { id: userId },
      select: { id: true, username: true, display_name: true, avatar_url: true },
    });
    return { ...c, user: author };
  }

  async listComments(postId: string, page: number = 1) {
    const rows = await this.prisma.post_comments.findMany({
      where: { post_id: postId, parent_id: null },
      orderBy: { created_at: 'desc' },
      take: 30,
      skip: (page - 1) * 30,
    });
    if (rows.length === 0) return [];
    // post_comments has no Prisma relation to users in the schema, so join manually.
    const userIds = Array.from(new Set(rows.map((r) => r.user_id).filter((v): v is string => !!v)));
    const users = await this.prisma.users.findMany({
      where: { id: { in: userIds } },
      select: { id: true, username: true, display_name: true, avatar_url: true },
    });
    const byId = new Map(users.map((u) => [u.id, u]));
    return rows.map((r) => ({ ...r, user: r.user_id ? byId.get(r.user_id) ?? null : null }));
  }

  // Stories
  async createStory(userId: string, dto: { type: string; mediaUrl: string; data?: any; restaurantId?: string }) {
    return this.prisma.stories.create({
      data: {
        user_id: userId,
        media_url: dto.mediaUrl,
        type: dto.type,
        data: dto.data ?? {},
        restaurant_id: dto.restaurantId,
      },
    });
  }

  async storiesFeed(userId: string) {
    const follows = await this.prisma.follows.findMany({ where: { follower_id: userId } });
    const ids = follows.map((f) => f.followee_id);
    if (ids.length === 0) return [];
    return this.prisma.stories.findMany({
      where: { user_id: { in: ids }, expires_at: { gt: new Date() } },
      orderBy: { created_at: 'desc' },
      take: 50,
    });
  }
}
