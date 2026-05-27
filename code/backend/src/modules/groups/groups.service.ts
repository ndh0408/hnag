import { Inject, Injectable, NotFoundException, ForbiddenException, BadRequestException, Logger } from '@nestjs/common';
import { customAlphabet } from 'nanoid';
import IORedis from 'ioredis';
import { PrismaService } from '../../common/prisma/prisma.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import { REDIS } from '../../common/redis/redis.module';

const inviteCode = customAlphabet('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', 8);

/**
 * Audit realtime-trace §5/§D: prior `vote` emitted one broadcast PER vote.
 * 10 concurrent voters = 10 broadcasts × all members = O(N²) client re-
 * renders + flicker. Coalesce with a 200ms tumbling window per poll,
 * leader-elected via Redis SETNX so only ONE replica runs the flush
 * timer (audit §6 — cross-replica duplicates).
 */
const VOTE_COALESCE_MS = Number(process.env.WS_VOTE_COALESCE_MS ?? '200');

@Injectable()
export class GroupsService {
  private readonly logger = new Logger(GroupsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly gw: RealtimeGateway,
    @Inject(REDIS) private readonly redis: IORedis,
  ) {}

  async create(userId: string, name: string, type = 'casual') {
    const g = await this.prisma.groups.create({
      data: { name, type, creator_id: userId, invite_code: inviteCode() },
    });
    await this.prisma.group_members.create({
      data: { group_id: g.id, user_id: userId, role: 'creator' },
    });
    return g;
  }

  async join(userId: string, groupId: string, inviteCode: string) {
    const g = await this.prisma.groups.findUnique({ where: { id: groupId } });
    if (!g) throw new NotFoundException();
    if (g.invite_code !== inviteCode) throw new ForbiddenException('Mã mời sai');
    const result = await this.prisma.group_members.upsert({
      where: { group_id_user_id: { group_id: groupId, user_id: userId } },
      update: {},
      create: { group_id: groupId, user_id: userId },
    });
    // Only broadcast on a TRUE first-join. upsert with empty update returns
    // the row either way, so check joined_at instead — if it's within the
    // last few seconds, treat as new join.
    const isFresh = result.joined_at && Date.now() - result.joined_at.getTime() < 5000;
    if (isFresh) {
      await this.gw.broadcastGroup(groupId, 'group.member.joined', { userId });
    }
    return g;
  }

  async myGroups(userId: string) {
    return this.prisma.groups.findMany({
      where: { group_members: { some: { user_id: userId } } },
      orderBy: { created_at: 'desc' },
    });
  }

  async createPoll(userId: string, groupId: string, dto: { options: { foodId?: string; restaurantId?: string }[]; closesInMinutes?: number }) {
    await this.assertMember(userId, groupId);
    if (!dto.options || dto.options.length < 2) throw new BadRequestException('Cần ít nhất 2 lựa chọn');
    const closesAt = new Date(Date.now() + (dto.closesInMinutes ?? 5) * 60_000);
    const poll = await this.prisma.group_polls.create({
      data: {
        group_id: groupId,
        creator_id: userId,
        options: dto.options as any,
        status: 'open',
        closes_at: closesAt,
      },
    });
    await this.gw.broadcastGroup(groupId, 'group.poll.created', { pollId: poll.id, closesAt: closesAt.toISOString() });
    return poll;
  }

  async vote(userId: string, groupId: string, pollId: string, optionIdx: number) {
    await this.assertMember(userId, groupId);
    const poll = await this.prisma.group_polls.findUnique({ where: { id: pollId } });
    if (!poll || poll.group_id !== groupId) throw new NotFoundException();
    if (poll.status !== 'open') throw new BadRequestException('Vote đã đóng');
    if (poll.closes_at && poll.closes_at < new Date()) throw new BadRequestException('Vote đã hết hạn');
    const opts = poll.options as any[];
    if (optionIdx < 0 || optionIdx >= opts.length) throw new BadRequestException('Option không hợp lệ');

    // Atomic write: jsonb_set sets only THIS user's key.
    const updated: any[] = await this.prisma.$queryRawUnsafe(
      `UPDATE group_polls
         SET votes = jsonb_set(coalesce(votes, '{}'::jsonb), ARRAY[$1], $2::jsonb, true)
       WHERE id = $3::uuid AND status = 'open'
       RETURNING votes`,
      userId, JSON.stringify([optionIdx]), pollId,
    );
    if (!updated.length) throw new BadRequestException('Vote đã đóng');
    const votes = (updated[0].votes as Record<string, number[]>) ?? {};
    const tally = this.tally(votes, opts.length);
    // Audit realtime-trace §5/§D: previously a broadcast PER vote. Now
    // coalesced — only the leader-elected replica fires after a 200ms
    // tumbling window. Callers still get the latest tally HTTP-side; the
    // WS broadcast is the multicast.
    this.scheduleVoteBroadcast(groupId, pollId, tally);
    return { tally };
  }

  /**
   * Coalesce vote broadcasts. The first vote in a poll's 200ms window
   * claims the timer via Redis SETNX (so across replicas, only one timer
   * runs). Subsequent votes overwrite the pending tally key. When the
   * timer fires, we read the latest tally and broadcast once.
   *
   * Trade-off: up to 200ms latency on the FIRST vote of a window. Worth
   * it: 10 simultaneous voters now produce 1 broadcast instead of 10.
   */
  private async scheduleVoteBroadcast(groupId: string, pollId: string, tally: number[]): Promise<void> {
    const pendingKey = `vote:pending:${pollId}`;
    const leaderKey = `vote:leader:${pollId}`;
    try {
      // Always write the latest tally so whoever flushes uses the freshest.
      await this.redis.setex(pendingKey, 30, JSON.stringify({ groupId, pollId, tally }));
      const claimed = await this.redis.set(leaderKey, '1', 'PX', VOTE_COALESCE_MS, 'NX');
      if (claimed !== 'OK') return; // another replica owns this window
      setTimeout(() => { void this.flushVoteBroadcast(pollId); }, VOTE_COALESCE_MS);
    } catch (err) {
      this.logger.warn(`vote coalesce schedule failed: ${(err as Error).message}`);
      // Fail open: broadcast immediately so users don't lose updates on Redis blip.
      await this.gw.broadcastGroup(groupId, 'group.poll.updated', { pollId, tally });
    }
  }

  private async flushVoteBroadcast(pollId: string): Promise<void> {
    const pendingKey = `vote:pending:${pollId}`;
    try {
      const raw = await this.redis.get(pendingKey);
      if (!raw) return;
      await this.redis.del(pendingKey);
      const { groupId, tally } = JSON.parse(raw) as { groupId: string; pollId: string; tally: number[] };
      await this.gw.broadcastGroup(groupId, 'group.poll.updated', { pollId, tally });
    } catch (err) {
      this.logger.warn(`vote coalesce flush failed for ${pollId}: ${(err as Error).message}`);
    }
  }

  async result(userId: string, groupId: string, pollId: string) {
    await this.assertMember(userId, groupId);
    const poll = await this.prisma.group_polls.findUnique({ where: { id: pollId } });
    if (!poll) throw new NotFoundException();
    const opts = poll.options as any[];
    const tally = this.tally((poll.votes as any) ?? {}, opts.length);
    const winnerIdx = tally.indexOf(Math.max(...tally));
    return { tally, winner: opts[winnerIdx], status: poll.status };
  }

  // ----- internals -----

  private async assertMember(userId: string, groupId: string) {
    const m = await this.prisma.group_members.findUnique({
      where: { group_id_user_id: { group_id: groupId, user_id: userId } },
    });
    if (!m) throw new ForbiddenException('Bạn không thuộc nhóm này');
  }

  private tally(votes: Record<string, number[]>, n: number): number[] {
    const t = new Array(n).fill(0);
    for (const arr of Object.values(votes)) for (const i of arr) if (i < n) t[i]++;
    return t;
  }
}
