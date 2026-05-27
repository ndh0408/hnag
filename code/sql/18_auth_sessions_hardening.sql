-- ============================================================================
-- 18 — Auth session hardening (refresh-token rotation, absolute lifetime)
-- ----------------------------------------------------------------------------
-- Closes audit #5: previously `auth.service.refresh()` created a FRESH 30-day
-- session on every call. A stolen refresh token could be rotated forever
-- and the "reuse detected" logic only fired if an *already-revoked* token
-- was presented — if an attacker stole BEFORE the user's next use, the
-- attacker rotated first and got a clean chain.
--
-- This migration adds the columns needed for:
--   • absolute_expires_at — never extends past this date, no matter how many
--     legitimate refreshes happen. Hard cap at 30 days from FIRST issuance.
--   • family_id — every rotated descendant of an initial login carries the
--     same `family_id`. Reuse-detection now revokes the whole family in one
--     shot (was: walked the chain via user_id, slow + susceptible to races).
--   • rotation_count — anomaly signal; > 100 rotations in 30 days means a
--     stuck client polling refresh, alert-worthy.
--   • ip_inet / user_agent already existed in schema.prisma.
--
-- Backend code in code/backend/src/modules/auth/auth.service.ts is updated
-- in the same change to consume these columns.
--
-- Apply:
--   docker exec -i hnag-postgres psql -U hnag -d hnag < code/sql/18_auth_sessions_hardening.sql
-- ============================================================================

ALTER TABLE auth_sessions
  ADD COLUMN IF NOT EXISTS absolute_expires_at TIMESTAMPTZ;

ALTER TABLE auth_sessions
  ADD COLUMN IF NOT EXISTS family_id UUID;

ALTER TABLE auth_sessions
  ADD COLUMN IF NOT EXISTS rotation_count INTEGER NOT NULL DEFAULT 0;

-- Default `absolute_expires_at = created_at + 30 days` for any legacy row
-- so the new code path treats existing chains as bounded too.
UPDATE auth_sessions
   SET absolute_expires_at = created_at + INTERVAL '30 days'
 WHERE absolute_expires_at IS NULL;

-- Default `family_id = id` for any legacy row — they become single-member
-- families. New rotations descending from these inherit the same family_id.
UPDATE auth_sessions
   SET family_id = id
 WHERE family_id IS NULL;

-- After backfill, lock the columns so future inserts must populate them.
ALTER TABLE auth_sessions
  ALTER COLUMN absolute_expires_at SET NOT NULL,
  ALTER COLUMN family_id SET NOT NULL;

-- Lookup index for the "revoke whole family" operation.
CREATE INDEX IF NOT EXISTS idx_auth_sessions_family
  ON auth_sessions (family_id)
  WHERE revoked_at IS NULL;

-- The `idx_auth_sessions_user_active` partial in 10_indexes.sql remains for
-- the per-user active-session list.

COMMENT ON COLUMN auth_sessions.absolute_expires_at IS
  'Hard cap on the entire refresh chain. Never extends. After this point '
  || 'the user must re-authenticate (OTP / Apple), even if their last refresh '
  || 'token is still within its rolling 30d window.';
COMMENT ON COLUMN auth_sessions.family_id IS
  'Every descendant of the initial login carries the SAME family_id. Reuse '
  || 'detection revokes the whole family. (Audit #5 — refresh-chain hijack.)';
COMMENT ON COLUMN auth_sessions.rotation_count IS
  'Number of times this chain has been rotated. > 100 in 30d means a stuck '
  || 'client; surface in monitoring.';

-- ============================================================================
-- DONE.
-- ============================================================================
