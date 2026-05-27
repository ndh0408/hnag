import { ArrayMaxSize, IsArray, IsNumber, IsObject, IsOptional, IsString, IsUrl, IsUUID, MaxLength, Min, Max } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

/**
 * Payload for `POST /v1/posts`. Audit hnag-audit-2026-05 #12 — the route
 * previously accepted `body: any`, which (combined with whitelist on the
 * global ValidationPipe) was already safe-by-default but the contract was
 * undocumented. This DTO is the explicit allowlist of writable fields.
 */
export class CreatePostDto {
  @ApiPropertyOptional({ maxLength: 2000 })
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  caption?: string;

  @ApiPropertyOptional({ description: 'Single hero image/video URL (legacy clients).' })
  @IsOptional()
  @IsUrl({ require_protocol: true, protocols: ['http', 'https'] })
  @MaxLength(500)
  mediaUrl?: string;

  @ApiPropertyOptional({ description: 'Up to 5 image URLs. Must be HTTPS/HTTP.' })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(5)
  @IsUrl({ require_protocol: true, protocols: ['http', 'https'] }, { each: true })
  images?: string[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID('4')
  foodId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID('4')
  restaurantId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(120)
  location?: string;

  @ApiPropertyOptional({ description: 'Lat in decimal degrees.', minimum: -90, maximum: 90 })
  @IsOptional()
  @IsNumber()
  @Min(-90)
  @Max(90)
  lat?: number;

  @ApiPropertyOptional({ description: 'Lng in decimal degrees.', minimum: -180, maximum: 180 })
  @IsOptional()
  @IsNumber()
  @Min(-180)
  @Max(180)
  lng?: number;

  @ApiPropertyOptional({ type: Object, description: 'Free-form metadata blob (mood, weather, etc.). Server-side keys are ignored.' })
  @IsOptional()
  @IsObject()
  metadata?: Record<string, unknown>;
}

/** Payload for `POST /v1/posts/:id/comment`. */
export class CreateCommentDto {
  @IsString()
  @MaxLength(2000)
  content!: string;

  @IsOptional()
  @IsUUID('4')
  parentId?: string;
}

/** Payload for `POST /v1/stories`. */
export class CreateStoryDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsUrl({ require_protocol: true, protocols: ['http', 'https'] })
  @MaxLength(500)
  mediaUrl?: string;

  @ApiPropertyOptional({ maxLength: 200 })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  caption?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID('4')
  foodId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID('4')
  restaurantId?: string;
}
