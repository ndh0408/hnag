-- ============================================================================
-- 20 — Missing indexes surfaced by db-architecture audit
-- ----------------------------------------------------------------------------
-- Each index closes a specific query path that today either seq-scans or
-- relies on a leading column that doesn't match the WHERE clause. Every
-- statement is idempotent (IF NOT EXISTS). CONCURRENTLY where the table
-- is large enough to matter at our scale.
--
-- Apply on ServerLinux:
--   docker exec -i hnag-postgres psql -U hnag -d hnag < code/sql/20_missing_indexes.sql
--
-- NOTE: CONCURRENTLY cannot run inside a transaction block; psql executes
-- each statement on its own when there is no enclosing BEGIN.
-- ============================================================================

-- food_interactions.session_id — used by FK to ai_sessions + by "all
-- feedback for session X" queries. Today the only index containing
-- session_id is the (user_id, action, created_at DESC) composite which
-- doesn't help session lookups. Per-session debugging + acceptance-rate
-- analytics scan all interactions without this.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_food_interactions_session
  ON food_interactions(session_id)
  WHERE session_id IS NOT NULL;

-- posts: feed for "my posts" + profile timeline queries.  idx_posts_user_recent
-- already exists from sql/10; but on a heavily-archived account, scanning
-- non-archived posts only would help — partial index.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_posts_user_active
  ON posts(user_id, created_at DESC)
  WHERE is_archived = false;

-- notifications: list({ type, unread, page }) — `idx_notifications_user_unread`
-- exists (partial on read_at IS NULL). For typed inbox views (e.g. only
-- ai_suggest) a (user_id, type, created_at DESC) helps.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notifications_user_type_created
  ON notifications(user_id, type, created_at DESC);

-- saved_items: who saved this food (reverse direction). PK is
-- (user_id, food_id, collection); food_id alone is not the leading
-- column so "all savers of food X" was a seq scan.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_saved_items_food_created
  ON saved_items(food_id, created_at DESC);

-- ai_sessions: cost-anomaly dashboards filter by mode + day + user. The
-- table has no useful index today besides PK.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ai_sessions_user_created
  ON ai_sessions(user_id, created_at DESC);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ai_sessions_mode_created
  ON ai_sessions(mode, created_at DESC);

-- account_deletions: forensic lookup by ip_hash for "did this IP delete
-- multiple accounts" abuse signal. Today only by (user_id, deleted_at).
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_account_deletions_ip_hash
  ON account_deletions(ip_hash, deleted_at DESC)
  WHERE ip_hash IS NOT NULL;

-- admin_audit_log: forensic queries always filter by (action, created_at)
-- or (admin_id, created_at). Audit table has only PK today.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_admin_audit_action_created
  ON admin_audit_log(action, created_at DESC);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_admin_audit_admin_created
  ON admin_audit_log(admin_id, created_at DESC);

-- Refresh planner stats so it sees the new indexes immediately.
ANALYZE food_interactions;
ANALYZE posts;
ANALYZE notifications;
ANALYZE saved_items;
ANALYZE ai_sessions;
ANALYZE account_deletions;
ANALYZE admin_audit_log;

-- ============================================================================
-- DONE.
-- ============================================================================
