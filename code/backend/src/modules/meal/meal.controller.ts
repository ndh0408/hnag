import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { MealService } from './meal.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/strategies/jwt.strategy';

@ApiTags('Meal Plan')
@ApiBearerAuth()
@UseGuards(AuthGuard('jwt'))
@Controller('meal-plan')
export class MealController {
  constructor(private readonly meal: MealService) {}

  @Get()
  current(@CurrentUser() u: JwtPayload) {
    return this.meal.getCurrent(u.sub);
  }

  @Post('generate')
  generate(@CurrentUser() u: JwtPayload, @Body() body: { budgetPerDay?: number; diet?: string }) {
    return this.meal.generate(u.sub, body ?? {});
  }
}
