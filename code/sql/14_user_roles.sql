-- ============================================================================
-- 14 — User roles (RBAC)
-- ----------------------------------------------------------------------------
-- Audit prompt-pack §7 ("RBAC đầy đủ"): the previous admin gate was an
-- ADMIN_EMAILS env-var whitelist. That works for 3 admins; it does NOT
-- scale to:
--   - restaurant owners (need OWNER role with claim-specific perms)
--   - moderators (review queue, no DB write)
--   - billing-only (read invoices, no premium grant)
--   - support agents (read user / refund / unban; no delete)
--
-- This migration adds a `role` enum column on `users`. The default for
-- every existing row is 'user'; admins must be promoted manually
-- (recommended UPDATE statement at the bottom of this file).
--
-- The `@Roles('admin', 'moderator')` decorator in code/backend/src/common
-- reads this column on every guarded request, so changes take effect at
-- the next JWT issue or immediately on protected routes that re-check
-- the DB (most admin routes do — see GqlAdminGuard).
--
-- Apply:
--   docker exec -i hnag-postgres psql -U hnag -d hnag < code/sql/14_user_roles.sql
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
    CREATE TYPE user_role AS ENUM (
      'user',          -- default — regular consumer
      'owner',         -- restaurant owner (paired with restaurant_claims.status='approved')
      'creator',       -- KOC / influencer with monetization unlocks
      'moderator',     -- review queue + content takedowns
      'support',       -- read-write on user accounts (no delete, no premium grant)
      'admin',         -- everything except super_admin destructive ops
      'super_admin'    -- full access incl. DB schema migrations
    );
  END IF;
END $$;

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS role user_role NOT NULL DEFAULT 'user';

-- Index on role so admin-list queries (`WHERE role IN ('admin', 'super_admin')`)
-- are O(log n) instead of seq scan.
CREATE INDEX IF NOT EXISTS idx_users_role
  ON users (role)
  WHERE role <> 'user';

COMMENT ON COLUMN users.role IS 'RBAC role. Default user; promote via UPDATE statement, not via API. See @Roles() decorator in code/backend/src/common/decorators/roles.decorator.ts.';

-- ── Bootstrap (run manually after applying schema) ─────────────────────────
-- Promote the founding admin(s). Replace email below.
--
--   UPDATE users SET role = 'super_admin'
--     WHERE email = 'huy04082000@gmail.com';
--
-- Promote a restaurant owner (after their restaurant_claims row is approved):
--
--   UPDATE users SET role = 'owner'
--     WHERE id IN (SELECT claimant_user_id FROM restaurant_claims WHERE status = 'approved');

-- ============================================================================
-- DONE.
-- ============================================================================
