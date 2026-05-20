import { Injectable, NotFoundException, ConflictException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../common/prisma/prisma.service';

@Injectable()
export class CoupleService {
  constructor(private readonly prisma: PrismaService) {}

  async invite(userId: string, partnerPhoneOrUsername: string) {
    const partner = await this.prisma.users.findFirst({
      where: {
        OR: [
          { phone: partnerPhoneOrUsername },
          { username: partnerPhoneOrUsername.toLowerCase() },
        ],
      },
    });
    if (!partner) throw new NotFoundException('Không tìm thấy người này');
    if (partner.id === userId) throw new BadRequestException('Không thể link chính mình');

    const existing = await this.prisma.couples.findFirst({
      where: {
        OR: [
          { user_a: userId, user_b: partner.id },
          { user_a: partner.id, user_b: userId },
        ],
        status: { in: ['pending', 'active'] },
      },
    });
    if (existing) throw new ConflictException('Đã có liên kết');

    return this.prisma.couples.create({
      data: { user_a: userId, user_b: partner.id, status: 'pending' },
    });
  }

  async accept(userId: string, coupleId: string) {
    const c = await this.prisma.couples.findUnique({ where: { id: coupleId } });
    if (!c) throw new NotFoundException();
    if (c.user_b !== userId) throw new BadRequestException('Chỉ người được mời mới accept được');
    if (c.status !== 'pending') throw new BadRequestException('Trạng thái không hợp lệ');
    return this.prisma.couples.update({
      where: { id: coupleId },
      data: { status: 'active' },
    });
  }

  async dissolve(userId: string, coupleId: string) {
    const c = await this.prisma.couples.findUnique({ where: { id: coupleId } });
    if (!c) throw new NotFoundException();
    if (c.user_a !== userId && c.user_b !== userId) throw new BadRequestException();
    return this.prisma.couples.update({
      where: { id: coupleId },
      data: { status: 'dissolved', dissolved_at: new Date() },
    });
  }

  async setAnniversary(userId: string, coupleId: string, date: Date) {
    const c = await this.prisma.couples.findUnique({ where: { id: coupleId } });
    if (!c || (c.user_a !== userId && c.user_b !== userId)) throw new BadRequestException();
    return this.prisma.couples.update({
      where: { id: coupleId },
      data: { anniversary: date },
    });
  }

  async myCouple(userId: string) {
    return this.prisma.couples.findFirst({
      where: {
        OR: [{ user_a: userId }, { user_b: userId }],
        status: 'active',
      },
    });
  }

  /**
   * Combined shared taste — Date Night recommendations use this.
   * Intersect cuisines both love, union allergies (HARD avoid), shared history.
   */
  async sharedTasteProfile(userId: string) {
    const couple = await this.myCouple(userId);
    if (!couple) return null;
    const partnerId = couple.user_a === userId ? couple.user_b : couple.user_a;
    const [me, partner] = await Promise.all([
      this.prisma.user_preferences.findUnique({ where: { user_id: userId } }),
      this.prisma.user_preferences.findUnique({ where: { user_id: partnerId! } }),
    ]);
    if (!me || !partner) return null;
    return {
      partnerId,
      cuisinesLove: intersection(me.cuisines_love, partner.cuisines_love),
      cuisinesHate: union(me.cuisines_hate, partner.cuisines_hate),
      allergies: union(me.allergies, partner.allergies),
      budget: {
        min: Math.min(me.budget_min ?? 0, partner.budget_min ?? 0),
        max: Math.min(me.budget_max ?? 9_999_999, partner.budget_max ?? 9_999_999),
      },
      spicyTolerance: Math.min(me.spicy_tolerance ?? 5, partner.spicy_tolerance ?? 5),
    };
  }

  /**
   * Memory book — places this couple has eaten together (check-ins within 5min of each other).
   */
  async memoryBook(userId: string) {
    const couple = await this.myCouple(userId);
    if (!couple) return [];
    const partnerId = couple.user_a === userId ? couple.user_b : couple.user_a;
    return this.prisma.$queryRawUnsafe<any[]>(`
      SELECT a.id, a.restaurant_id, r.name AS restaurant_name, a.food_id, a.created_at
      FROM check_ins a
      JOIN check_ins b
        ON b.restaurant_id = a.restaurant_id
       AND ABS(EXTRACT(EPOCH FROM (a.created_at - b.created_at))) < 600
      JOIN restaurants r ON r.id = a.restaurant_id
      WHERE a.user_id = $1 AND b.user_id = $2
      ORDER BY a.created_at DESC LIMIT 50;
    `, userId, partnerId);
  }
}

function intersection<T>(a: T[], b: T[]): T[] {
  const set = new Set(b);
  return a.filter((x) => set.has(x));
}
function union<T>(a: T[], b: T[]): T[] {
  return Array.from(new Set([...a, ...b]));
}
