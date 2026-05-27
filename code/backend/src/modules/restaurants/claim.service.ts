import { Injectable, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../common/prisma/prisma.service';
import { OtpService } from '../auth/otp.service';

@Injectable()
export class ClaimService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly otp: OtpService,
  ) {}

  async start(userId: string, restaurantId: string, dto: {
    position: string; contactEmail?: string; contactPhone?: string;
  }) {
    const r = await this.prisma.restaurants.findUnique({ where: { id: restaurantId } });
    if (!r) throw new NotFoundException();
    if (r.is_claimed) throw new ForbiddenException('Quán đã được claim');

    const existing = await this.prisma.restaurant_claims.findFirst({
      where: { restaurant_id: restaurantId, claimant_user_id: userId, status: { in: ['pending', 'verifying', 'manual_review'] as any } },
    });
    if (existing) return existing;

    const claim = await this.prisma.restaurant_claims.create({
      data: {
        restaurant_id: restaurantId,
        claimant_user_id: userId,
        position: dto.position,
        contact_email: dto.contactEmail,
        contact_phone: dto.contactPhone,
        status: 'pending',
      },
    });
    return claim;
  }

  async sendEmailOtp(claimId: string, userId: string) {
    const claim = await this.find(claimId, userId);
    const email = claim.contact_email;
    if (!email) throw new BadRequestException('Thiếu email liên hệ');
    await this.otp.sendEmail(email, 'claim');
    return { sent: true };
  }

  async verifyEmail(claimId: string, userId: string, code: string) {
    const claim = await this.find(claimId, userId);
    if (!claim.contact_email) throw new BadRequestException('Thiếu email liên hệ');
    const ok = await this.otp.verifyEmail(claim.contact_email, code, 'claim');
    if (!ok) throw new BadRequestException('Mã OTP không đúng');
    await this.prisma.restaurant_claims.update({
      where: { id: claimId },
      // reuse the contact-verified scoring slot (was phone, now email)
      data: { phone_otp_passed: true },
    });
    return this.tallyAndDecide(claimId);
  }

  async submitLicense(claimId: string, userId: string, licenseUrl: string, ocrResult: any) {
    const claim = await this.find(claimId, userId);
    const r = await this.prisma.restaurants.findUnique({ where: { id: claim.restaurant_id! } });
    const score = this.scoreLicense(ocrResult, r?.name ?? '', r?.address ?? '');
    await this.prisma.restaurant_claims.update({
      where: { id: claimId },
      data: {
        license_url: licenseUrl,
        license_ocr: ocrResult,
        license_score: score,
      },
    });
    return this.tallyAndDecide(claimId);
  }

  async verifyGeo(claimId: string, userId: string, lat: number, lng: number) {
    const claim = await this.find(claimId, userId);
    const r = await this.prisma.restaurants.findUnique({ where: { id: claim.restaurant_id! } });
    // ST_DWithin <= 50m check
    const within = await this.prisma.$queryRawUnsafe<any[]>(
      `SELECT ST_DWithin(location::geography, ST_GeogFromText($1)::geography, 50) AS ok FROM restaurants WHERE id = $2`,
      `POINT(${lng} ${lat})`,
      claim.restaurant_id,
    );
    const ok = !!within?.[0]?.ok;
    if (!ok) throw new BadRequestException('GPS quá xa quán');
    await this.prisma.restaurant_claims.update({
      where: { id: claimId },
      data: { geo_verified: true, geo_visit_at: new Date() },
    });
    return this.tallyAndDecide(claimId);
  }

  async cancel(claimId: string, userId: string) {
    const claim = await this.find(claimId, userId);
    return this.prisma.restaurant_claims.update({
      where: { id: claimId },
      data: { status: 'rejected', notes: 'Cancelled by user' },
    });
  }

  async myClaims(userId: string) {
    return this.prisma.restaurant_claims.findMany({
      where: { claimant_user_id: userId },
      orderBy: { created_at: 'desc' },
    });
  }

  // ----- internals -----

  private async find(claimId: string, userId: string) {
    const c = await this.prisma.restaurant_claims.findUnique({ where: { id: claimId } });
    if (!c) throw new NotFoundException();
    if (c.claimant_user_id !== userId) throw new ForbiddenException();
    return c;
  }

  private scoreLicense(ocr: any, restaurantName: string, address: string): number {
    if (!ocr) return 0;
    let score = 0;
    const ocrText = JSON.stringify(ocr).toLowerCase();
    if (restaurantName && ocrText.includes(restaurantName.toLowerCase().slice(0, 8))) score += 0.25;
    if (address) {
      const tokens = address.toLowerCase().split(/\s+/).filter((t) => t.length > 3);
      const hits = tokens.filter((t) => ocrText.includes(t)).length;
      if (hits >= 2) score += 0.15;
    }
    return Math.min(score, 0.4);
  }

  private async tallyAndDecide(claimId: string) {
    const c = await this.prisma.restaurant_claims.findUnique({ where: { id: claimId } });
    if (!c) throw new NotFoundException();
    let score = 0;
    if (c.phone_otp_passed) score += 0.6;
    if (c.license_score) score += Number(c.license_score);
    if (c.geo_verified) score += 0.3;
    if (c.email_domain_match) score += 0.2;

    // Audit #47: auto-approval REQUIRES geo_verified. Without an on-site GPS
    // ping, even a verified email + scribbled "license" image can pass the
    // 0.7 score threshold and grab the restaurant. With geo_verified as a
    // HARD GATE, auto-approval is impossible from a remote impersonator.
    let status: 'approved' | 'manual_review' | 'pending' = 'pending';
    if (score >= 0.7 && c.geo_verified) status = 'approved';
    else if (score >= 0.4) status = 'manual_review';
    else if (score >= 0.7 /* high score without geo → still manual */) status = 'manual_review';

    const updated = await this.prisma.restaurant_claims.update({
      where: { id: claimId },
      data: {
        total_score: score,
        status,
        resolved_at: status === 'approved' ? new Date() : null,
      },
    });

    if (status === 'approved') {
      await this.grantOwnership(c.claimant_user_id!, c.restaurant_id!);
    }
    return updated;
  }

  private async grantOwnership(userId: string, restaurantId: string) {
    await this.prisma.restaurant_owners.upsert({
      where: { restaurant_id_user_id: { restaurant_id: restaurantId, user_id: userId } },
      update: { role: 'owner' },
      create: {
        restaurant_id: restaurantId,
        user_id: userId,
        role: 'owner',
        permissions: ['menu', 'photos', 'boost', 'live', 'reply'],
      },
    });
    await this.prisma.restaurants.update({
      where: { id: restaurantId },
      data: { is_claimed: true, is_verified: true, owner_user_id: userId },
    });
  }
}
