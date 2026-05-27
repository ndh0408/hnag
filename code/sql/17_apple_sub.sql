-- ============================================================================
-- 17 — Apple SSO: dedicated apple_sub column (closes Apple-SSO hijack)
-- ----------------------------------------------------------------------------
-- Closes audit #12: the previous Apple SSO upsert keyed on a SYNTHETIC email
-- `apple+{sub}@hnag.internal`. Because the `email` column is @unique and the
-- regular email-OTP path didn't refuse the `@hnag.internal` suffix, an
-- attacker could PRE-REGISTER `apple+<known-sub>@hnag.internal` via the
-- regular OTP flow (any 6-digit code on a domain they don't own, because
-- email OTP doesn't check deliverability). When the real Apple user signed
-- in, the upsert found the attacker's row and returned tokens for it →
-- silent account hijack.
--
-- Fix: introduce a dedicated `apple_sub TEXT @unique` column on users, key
-- Apple SSO upserts on that column (never on email), and refuse any regular
-- OTP signup with email LIKE '%@hnag.internal'.
--
-- Apply:
--   docker exec -i hnag-postgres psql -U hnag -d hnag < code/sql/17_apple_sub.sql
-- ============================================================================

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS apple_sub TEXT;

-- Unique only when non-null so existing rows (apple_sub NULL) don't all
-- collide. The unique constraint enforces one users row per Apple subject.
CREATE UNIQUE INDEX IF NOT EXISTS uq_users_apple_sub
  ON users (apple_sub)
  WHERE apple_sub IS NOT NULL;

COMMENT ON COLUMN users.apple_sub IS
  'Apple Sign-In stable subject (jwt.sub from verified identityToken). '
  || 'Auth path keys SSO upserts on THIS column, never on the synthesised '
  || 'apple+sub@hnag.internal email (audit #12 — account-hijack via email '
  || 'pre-registration). Set only by AuthService.signInWithApple().';

-- ── Backfill (best-effort) ─────────────────────────────────────────────────
-- Map existing synthetic-email rows to their apple_sub. The synthetic email
-- shape is `apple+{sub}@hnag.internal`. Any row that doesn't match the
-- shape is left untouched (real-email Apple users).
UPDATE users
   SET apple_sub = regexp_replace(email, '^apple\+(.+?)@hnag\.internal$', '\1')
 WHERE apple_sub IS NULL
   AND email LIKE 'apple+%@hnag.internal';

-- ── Defence-in-depth: reject the synthetic-email shape from the regular OTP
-- path at the DB level. Even if a future code change forgets the runtime
-- guard, this CHECK constraint makes the regular email-OTP signup fail.
-- ───────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'users_no_synthetic_apple_email'
  ) THEN
    ALTER TABLE users
      ADD CONSTRAINT users_no_synthetic_apple_email
      CHECK (
        email IS NULL
        OR apple_sub IS NOT NULL
        OR email NOT LIKE 'apple+%@hnag.internal'
      );
  END IF;
END $$;

-- ============================================================================
-- DONE.
-- ============================================================================
