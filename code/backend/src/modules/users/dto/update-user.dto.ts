import { IsOptional, IsString, IsUrl, MaxLength, IsObject } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

/**
 * Payload accepted by `PATCH /v1/users/me`.
 *
 * Audit hnag-audit-2026-05 #6: previously accepted `body: any` — the global
 * ValidationPipe (whitelist + forbidNonWhitelisted) already stripped extras,
 * but the controller still didn't communicate the contract via types and
 * `users.service.updateMe` had no first-line input shape check. This DTO is
 * the explicit allowlist that documents what a client may set on its own
 * profile. Anything else (is_premium, xp, is_verified, level…) cannot reach
 * Prisma even if a future refactor adds the field to the update payload.
 */
export class UpdateUserDto {
  @ApiPropertyOptional({ maxLength: 100 })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  displayName?: string;

  @ApiPropertyOptional({ maxLength: 500 })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  bio?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUrl({ require_protocol: true, protocols: ['http', 'https'] })
  @MaxLength(500)
  avatarUrl?: string;

  @ApiPropertyOptional({ maxLength: 80 })
  @IsOptional()
  @IsString()
  @MaxLength(80)
  city?: string;

  /**
   * Optional preferences blob. Each key inside is independently re-validated
   * against ALLOWED_PREF_KEYS in `UsersService.updatePreferences` — so even
   * if the DTO drift gives the wrong shape, mass-assignment is still blocked
   * at the service layer (defence in depth).
   */
  @ApiPropertyOptional({ type: Object })
  @IsOptional()
  @IsObject()
  preferences?: Record<string, unknown>;
}
