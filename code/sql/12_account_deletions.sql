-- ============================================================================
-- 12 — Account deletion audit log
-- ----------------------------------------------------------------------------
-- App Store Review Guideline 5.1.1(v) and Vietnam Nghị định 13/2023/NĐ-CP
-- both require a deletion path AND a record of when/why a deletion happened
-- (for compliance audit + legal-hold windows). The `users` row is
-- anonymized in place by `users.service.deleteAccount` — that's right for
-- privacy but wipes the timeline. This table is the forensic trail that
-- survives the anonymization.
--
-- Retention: 12 months by default, then a separate cron drops rows older
-- than that (legal hold satisfied).
--
-- Apply on the server:
--   docker exec -i hnag-postgres psql -U hnag -d hnag < code/sql/12_account_deletions.sql
-- ============================================================================

CREATE TABLE IF NOT EXISTS account_deletions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL,        -- the original user id (not FK — user row is anonymized)
  email_hash      TEXT,                 -- SHA-256 of the email (forensic match without storing PII)
  reason          TEXT,                 -- 'user_initiated' | 'admin' | 'gdpr' | 'tos_violation' | ...
  source          TEXT NOT NULL,        -- 'app' | 'web' | 'admin' | 'api'
  ip_hash         TEXT,                 -- SHA-256 of the request IP (matches without storing PII)
  user_agent      TEXT,                 -- raw UA string at the moment of deletion (clipped to 500)
  deleted_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  payload_summary JSONB                 -- {followers, reviews, orders, sessions_revoked, …}
);

CREATE INDEX IF NOT EXISTS idx_account_deletions_user
  ON account_deletions (user_id, deleted_at DESC);
CREATE INDEX IF NOT EXISTS idx_account_deletions_recent
  ON account_deletions (deleted_at DESC);

COMMENT ON TABLE account_deletions IS
  'Forensic trail of account deletions. App Store 5.1.1(v) + Decree 13/2023 audit requirement.';
COMMENT ON COLUMN account_deletions.email_hash IS
  'SHA-256(email). Lets us match a "this was my account" support request without storing PII.';

-- ============================================================================
-- DONE.
-- ============================================================================
