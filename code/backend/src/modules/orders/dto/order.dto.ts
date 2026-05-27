import { IsIn, IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

/** Payload for `POST /v1/orders/intent`. */
export class CreateOrderIntentDto {
  @IsUUID('4')
  foodId!: string;

  @IsOptional()
  @IsUUID('4')
  restaurantId?: string;

  @ApiPropertyOptional({ enum: ['shopee', 'grab', 'baemin', 'gojek', 'now'] })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  preferredPartner?: string;
}

/** Payload for `POST /v1/orders/:id/status`. */
export class UpdateOrderStatusDto {
  @IsIn(['intent', 'placed', 'cooking', 'picking', 'delivering', 'done', 'cancelled'])
  status!: 'intent' | 'placed' | 'cooking' | 'picking' | 'delivering' | 'done' | 'cancelled';

  @IsOptional()
  @IsString()
  @MaxLength(50)
  eta?: string;
}
