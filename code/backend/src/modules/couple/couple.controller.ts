import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { CoupleService } from './couple.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/strategies/jwt.strategy';

@ApiTags('Couple')
@ApiBearerAuth()
@UseGuards(AuthGuard('jwt'))
@Controller('couple')
export class CoupleController {
  constructor(private readonly svc: CoupleService) {}

  @Get('me')
  me(@CurrentUser() u: JwtPayload) {
    return this.svc.myCouple(u.sub);
  }

  @Get('shared-taste')
  sharedTaste(@CurrentUser() u: JwtPayload) {
    return this.svc.sharedTasteProfile(u.sub);
  }

  @Get('memory-book')
  memoryBook(@CurrentUser() u: JwtPayload) {
    return this.svc.memoryBook(u.sub);
  }

  @Post('invite')
  invite(@CurrentUser() u: JwtPayload, @Body() body: { phoneOrUsername: string }) {
    return this.svc.invite(u.sub, body.phoneOrUsername);
  }

  @Patch(':id/accept')
  accept(@CurrentUser() u: JwtPayload, @Param('id') id: string) {
    return this.svc.accept(u.sub, id);
  }

  @Patch(':id/anniversary')
  setAnniversary(@CurrentUser() u: JwtPayload, @Param('id') id: string, @Body() body: { date: string }) {
    return this.svc.setAnniversary(u.sub, id, new Date(body.date));
  }

  @Delete(':id')
  dissolve(@CurrentUser() u: JwtPayload, @Param('id') id: string) {
    return this.svc.dissolve(u.sub, id);
  }
}
