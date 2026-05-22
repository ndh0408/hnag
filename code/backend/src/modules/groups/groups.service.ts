import { Injectable, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common';
import { customAlphabet } from 'nanoid';
import { PrismaService } from '../../common/prisma/prisma.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';

const inviteCode = customAlphabet('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', 8);

@Injectable()
export class GroupsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly gw: RealtimeGateway,
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
    await this.prisma.group_members.upsert({
      where: { group_id_user_id: { group_id: groupId, user_id: userId } },
      update: {},
      create: { group_id: groupId, user_id: userId },
    });
    this.gw.broadcastGroup(groupId, 'group.member.joined', { userId });
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
    this.gw.broadcastGroup(groupId, 'group.poll.created', { pollId: poll.id, closesAt });
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

    // Atomic, race-free write: a single UPDATE sets only THIS user's key via
    // jsonb_set, so concurrent voters can't clobber each other (no read-modify-write).
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
    this.gw.broadcastGroup(groupId, 'group.poll.updated', { pollId, tally });
    return { tally };
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
