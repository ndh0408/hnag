import { Body, Controller, Param, Post, Get, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { ClaimService } from './claim.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/strategies/jwt.strategy';

@ApiTags('Claims')
@ApiBearerAuth()
@UseGuards(AuthGuard('jwt'))
@Controller('restaurants')
export class ClaimController {
  constructor(private readonly claim: ClaimService) {}

  @Post(':id/claim')
  start(
    @Param('id') restaurantId: string,
    @CurrentUser() u: JwtPayload,
    @Body() dto: { position: string; contactEmail?: string; contactPhone?: string },
  ) {
    return this.claim.start(u.sub, restaurantId, dto);
  }

  @Get('claims/me')
  myClaims(@CurrentUser() u: JwtPayload) {
    return this.claim.myClaims(u.sub);
  }

  @Post('claims/:claimId/verify/phone/send')
  sendPhone(@Param('claimId') id: string, @CurrentUser() u: JwtPayload) {
    return this.claim.sendPhoneOtp(id, u.sub);
  }

  @Post('claims/:claimId/verify/phone')
  verifyPhone(@Param('claimId') id: string, @CurrentUser() u: JwtPayload, @Body() body: { otp: string }) {
    return this.claim.verifyPhone(id, u.sub, body.otp);
  }

  @Post('claims/:claimId/verify/license')
  uploadLicense(
    @Param('claimId') id: string,
    @CurrentUser() u: JwtPayload,
    @Body() body: { licenseUrl: string; ocr: any },
  ) {
    return this.claim.submitLicense(id, u.sub, body.licenseUrl, body.ocr);
  }

  @Post('claims/:claimId/verify/geo')
  verifyGeo(
    @Param('claimId') id: string,
    @CurrentUser() u: JwtPayload,
    @Body() body: { lat: number; lng: number },
  ) {
    return this.claim.verifyGeo(id, u.sub, body.lat, body.lng);
  }

  @Post('claims/:claimId/cancel')
  cancel(@Param('claimId') id: string, @CurrentUser() u: JwtPayload) {
    return this.claim.cancel(id, u.sub);
  }
}
