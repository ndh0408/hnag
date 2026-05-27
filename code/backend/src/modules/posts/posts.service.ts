import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../common/prisma/prisma.service';

import { CreatePostDto, CreateStoryDto } from './dto/posts.dto';

@Injectable()
export class PostsService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Create a new post.
   *
   * The DTO is the explicit allowlist of writable fields (audit #12);
   * server-derived columns (counts, type, archive flag, timestamps) are
   * never taken from the client.
   */
  async create(userId: string, dto: CreatePostDto) {
    const images = (dto.images ?? []).filter(Boolean);
    const mediaUrl = dto.mediaUrl ?? images[0];
    if (!mediaUrl && !dto.caption) {
      throw new BadRequestException('Bài đăng cần ít nhất 1 ảnh hoặc caption');
    }
    // Cheap mime-style inference so the DB still carries a `type` value.
    // Clients no longer pick this — preventing them from forging e.g. an
    // "admin" or "system" type.
    const ext = (mediaUrl ?? '').toLowerCase().split('?')[0].split('.').pop() ?? '';
    const type: 'photo' | 'video' | 'text' = ['mp4', 'mov', 'm3u8', 'webm'].includes(ext)
      ? 'video'
      : mediaUrl
        ? 'photo'
        : 'text';
    return this.prisma.posts.create({
      data: {
        user_id: userId,
        type,
        caption: dto.caption,
        media_url: mediaUrl,
        food_id: dto.foodId,
        restaurant_id: dto.restaurantId,
        tags: images.length > 1 ? images.slice(1) : [],
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
    // Audit hnag-audit-2026-05 #13 (race) + #23 (counter drift): createMany
    // with skipDuplicates returns 0 when the like already exists, so we only
    // increment on a fresh create. The CHECK constraint in sql/19 blocks any
    // negative drift if a stray decrement still reaches the DB.
    const created = await this.prisma.post_likes.createMany({
      data: [{ user_id: userId, post_id: postId }],
      skipDuplicates: true,
    });
    if (created.count > 0) {
      await this.prisma.posts.update({
        where: { id: postId },
        data: { like_count: { increment: 1 } },
      });
    }
    return { liked: true };
  }

  async unlike(userId: string, postId: string) {
    const r = await this.prisma.post_likes.deleteMany({ where: { user_id: userId, post_id: postId } });
    if (r.count > 0) {
      // Use GREATEST(like_count - 1, 0) so a drifted counter can never go
      // negative (defence in depth — CHECK constraint in sql/19 enforces it
      // at the DB level too).
      await this.prisma.$executeRawUnsafe(
        `UPDATE posts SET like_count = GREATEST(like_count - 1, 0) WHERE id = $1::uuid`,
        postId,
      );
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
  async createStory(userId: string, dto: CreateStoryDto) {
    if (!dto.mediaUrl && !dto.caption) {
      throw new BadRequestException('Story cần ít nhất 1 ảnh hoặc caption');
    }
    const ext = (dto.mediaUrl ?? '').toLowerCase().split('?')[0].split('.').pop() ?? '';
    const type: 'photo' | 'video' = ['mp4', 'mov', 'm3u8', 'webm'].includes(ext) ? 'video' : 'photo';
    return this.prisma.stories.create({
      data: {
        user_id: userId,
        media_url: dto.mediaUrl ?? '',
        type,
        data: dto.caption ? ({ caption: dto.caption } as any) : ({} as any),
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
