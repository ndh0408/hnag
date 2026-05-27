import {
  IsBoolean,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUrl,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

/** Owner can edit a strictly-bounded set of profile fields. */
export class UpdateRestaurantDto {
  @ApiPropertyOptional({ maxLength: 200 })
  @IsOptional() @IsString() @MaxLength(200)
  name?: string;

  @ApiPropertyOptional({ maxLength: 1000 })
  @IsOptional() @IsString() @MaxLength(1000)
  description?: string;

  @ApiPropertyOptional({ maxLength: 500 })
  @IsOptional() @IsString() @MaxLength(500)
  address?: string;

  @ApiPropertyOptional({ maxLength: 30 })
  @IsOptional() @IsString() @MaxLength(30)
  phone?: string;

  @ApiPropertyOptional()
  @IsOptional() @IsUrl({ require_protocol: true, protocols: ['http', 'https'] }) @MaxLength(500)
  cover_url?: string;

  @ApiPropertyOptional({ description: 'Free-form weekly hours JSON.' })
  @IsOptional()
  opening_hours?: Record<string, unknown>;
}

/** Live status — what owners flip during service. */
export class UpdateRestaurantLiveDto {
  @IsIn(['empty', 'normal', 'busy', 'full'])
  crowding!: 'empty' | 'normal' | 'busy' | 'full';

  @ApiPropertyOptional({ minimum: 0, maximum: 240 })
  @IsOptional() @IsInt() @Min(0) @Max(240)
  wait_minutes?: number;

  @ApiPropertyOptional()
  @IsOptional() @IsBoolean()
  is_open?: boolean;
}

/** Create or update a single menu item. */
export class UpsertMenuItemDto {
  @IsString() @MaxLength(160)
  name!: string;

  @ApiPropertyOptional({ maxLength: 600 })
  @IsOptional() @IsString() @MaxLength(600)
  description?: string;

  @IsInt() @Min(0) @Max(10_000_000)
  price_vnd!: number;

  @ApiPropertyOptional()
  @IsOptional() @IsUrl({ require_protocol: true, protocols: ['http', 'https'] }) @MaxLength(500)
  photo_url?: string;

  @ApiPropertyOptional()
  @IsOptional() @IsBoolean()
  available?: boolean;

  @ApiPropertyOptional({ description: 'Sort order in the menu list.' })
  @IsOptional() @IsInt() @Min(0) @Max(9999)
  position?: number;

  /**
   * Optional link to a curated `foods` row (used for AI ranking + dish
   * deduplication). When set, AI recommendations can surface this menu
   * item under the canonical food entry.
   */
  @ApiPropertyOptional()
  @IsOptional() @IsString()
  food_id?: string;
}
