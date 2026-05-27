-- ============================================================================
-- 21 — Retention policies for write-heavy / unbounded-growth tables
-- ----------------------------------------------------------------------------
-- Closes audit db-trace §C-12 + §C-3: several tables accumulate rows
-- forever today. At 100k DAU this is fine for ~6 months; at 1M DAU these
-- tables eat disk + slow planner stats within weeks.
--
-- This file installs PL/pgSQL retention FUNCTIONS the backend cron calls
-- nightly (see RetentionCron in src/modules/health/retention.cron.ts).
-- Keeping the policy in SQL means ops can adjust thresholds without a
-- backend redeploy.
--
-- Apply:
--   docker exec -i hnag-postgres psql -U hnag -d hnag < code/sql/21_retention_policies.sql
-- ============================================================================

-- ── auth_sessions ─────────────────────────────────────────────────────
-- A revoked session is useful for ~7 days for forensic refresh-token-
-- reuse detection. After that it just bloats the table. Daily prune.
CREATE OR REPLACE FUNCTION purge_old_auth_sessions(keep_days INT DEFAULT 7)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE
  n INTEGER;
BEGIN
  DELETE FROM auth_sessions
  WHERE revoked_at IS NOT NULL
    AND revoked_at < NOW() - (keep_days || ' days')::interval;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END;
$$;

-- ── ai_sessions output_cards retention ───────────────────────────────
-- The full output_cards JSONB (3-5KB/row) is only useful for ~30d of
-- A/B testing + acceptance-rate analysis. After that we keep the row
-- (for cost analytics) but null the JSONB to free space.
CREATE OR REPLACE FUNCTION compact_old_ai_sessions(keep_days INT DEFAULT 30)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE
  n INTEGER;
BEGIN
  UPDATE ai_sessions
     SET output_cards = NULL,
         ranker_scores = NULL,
         input = NULL
   WHERE output_cards IS NOT NULL
     AND created_at < NOW() - (keep_days || ' days')::interval;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END;
$$;

-- ── analytics_events retention ───────────────────────────────────────
-- 90d retention for product analytics; aggregate dashboards downstream
-- should backfill into a warehouse if longer-term needed.
CREATE OR REPLACE FUNCTION purge_old_analytics_events(keep_days INT DEFAULT 90)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE
  n INTEGER;
BEGIN
  DELETE FROM analytics_events
  WHERE created_at < NOW() - (keep_days || ' days')::interval;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END;
$$;

-- ── account_deletions retention ──────────────────────────────────────
-- Per Decree 13/2023 we should keep the deletion audit for at least 12
-- months for regulatory inspection. Default 365d; ops can override
-- per consultation with legal.
CREATE OR REPLACE FUNCTION purge_old_account_deletions(keep_days INT DEFAULT 365)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE
  n INTEGER;
BEGIN
  DELETE FROM account_deletions
  WHERE deleted_at < NOW() - (keep_days || ' days')::interval;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END;
$$;

COMMENT ON FUNCTION purge_old_auth_sessions IS 'Hard delete revoked auth sessions older than keep_days. Called nightly by backend cron.';
COMMENT ON FUNCTION compact_old_ai_sessions IS 'NULL the JSONB columns on old ai_sessions; keeps cost row, frees ~3-5KB each.';
COMMENT ON FUNCTION purge_old_analytics_events IS 'Hard delete analytics_events older than keep_days (default 90).';
COMMENT ON FUNCTION purge_old_account_deletions IS 'Hard delete account_deletions older than keep_days (default 365, per Decree 13/2023 minimum retention).';

-- ============================================================================
-- DONE.
-- ============================================================================
