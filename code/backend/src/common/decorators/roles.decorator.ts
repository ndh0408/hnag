import { SetMetadata, UseGuards, applyDecorators } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiBearerAuth } from '@nestjs/swagger';

import { RolesGuard } from '../guards/roles.guard';

/**
 * Public typed enum mirroring sql/14_user_roles.sql `user_role`. Keep in
 * sync — adding a value here without applying the DB ALTER will let
 * controller code "ask for" a role that no row can ever have.
 */
export type UserRole = 'user' | 'owner' | 'creator' | 'moderator' | 'support' | 'admin' | 'super_admin';

/** Reflector key — read by RolesGuard. */
export const ROLES_KEY = 'requiredRoles';

/**
 * Composite decorator: requires JWT + role check via RolesGuard.
 *
 * Usage:
 *
 *   @Roles('admin', 'super_admin')
 *   @Post('admin/users/:id/ban')
 *   ban(@Param('id') id: string) { ... }
 *
 * Role rules:
 *   - `super_admin` always passes (single-role override).
 *   - When `@Roles('admin')` is set, both 'admin' AND 'super_admin'
 *     pass — admin is a subset.
 *   - The guard checks the live DB row, not the JWT claim, so a
 *     just-demoted admin loses access on the next request (no need to
 *     invalidate their access token).
 */
export function Roles(...roles: UserRole[]): MethodDecorator & ClassDecorator {
  return applyDecorators(
    SetMetadata(ROLES_KEY, roles),
    ApiBearerAuth(),
    UseGuards(AuthGuard('jwt'), RolesGuard),
  );
}
