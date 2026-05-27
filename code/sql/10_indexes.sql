-- ============================================================================
-- 10 — Missing indexes (audit hnag-audit-2026-05 §3, §11, §34)
-- ----------------------------------------------------------------------------
-- Adds the indexes the planner needs for every hot read path. None of these
-- introduce new constraints; every one is `CREATE INDEX IF NOT EXISTS` so
-- this file is idempotent and safe to run multiple times.
--
-- Apply on ServerLinux:
--   docker exec -i hnag-postgres psql -U hnag -d hnag < code/sql/10_indexes.sql
--
-- Expected impact (audit numbers): p95 latency on feed/profile/leaderboard
-- queries down 60–80% at current traffic; restaurant nearby queries become
-- index-ordered KNN instead of seq scan.
--
-- The geospatial index on restaurants.location is added in 08_hardening.sql
-- (partial GiST). This file complements it with the relational hot paths.
-- ============================================================================

-- follows: every feed + profile read uses one of these directions
CREATE INDEX IF NOT EXISTS idx_follows_follower
  ON follows (follower_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_follows_followee
  ON follows (followee_id, created_at DESC);

-- reviews: leaderboard scans by user+time, restaurant detail by restaurant+rating
CREATE INDEX IF NOT EXISTS idx_reviews_user_created
  ON reviews (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reviews_restaurant_rating
  ON reviews (restaurant_id, rating DESC);

-- food_interactions: Taste Memory + streak checks scan by (user, action, time)
-- Use a regular btree; if events_archive grows past 50M rows consider
-- partitioning by month (out of scope for this migration).
CREATE INDEX IF NOT EXISTS idx_food_interactions_user_action_created
  ON food_interactions (user_id, action, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_food_interactions_food_created
  ON food_interactions (food_id, created_at DESC);

-- notifications: the "unread badge" query is `WHERE user_id = ? AND read_at IS NULL`
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON notifications (user_id, created_at DESC)
  WHERE read_at IS NULL;

-- posts: feed is ordered by (like_count DESC, created_at DESC) on is_archived=false
CREATE INDEX IF NOT EXISTS idx_posts_active_recent
  ON posts (is_archived, created_at DESC)
  WHERE is_archived = false;
CREATE INDEX IF NOT EXISTS idx_posts_user_recent
  ON posts (user_id, created_at DESC);

-- saved_items / saves: profile saves list is scanned by user_id, created_at
CREATE INDEX IF NOT EXISTS idx_saved_items_user_created
  ON saved_items (user_id, created_at DESC);

-- auth_sessions: refresh-token lookup uses refresh_token_hash (already unique
-- index) but expiry-sweep / list-by-user benefit from this composite
CREATE INDEX IF NOT EXISTS idx_auth_sessions_user_active
  ON auth_sessions (user_id, expires_at DESC)
  WHERE revoked_at IS NULL;

-- subscriptions: webhook matcher does prefix on id::text — the LIKE was the
-- audit hot spot (#7-8). With the service now using findMany+startsWith on
-- a small recent window, a btree on (provider, status, created_at) makes
-- the planner's life easy.
CREATE INDEX IF NOT EXISTS idx_subscriptions_provider_status_created
  ON subscriptions (provider, status, created_at DESC);

-- payment_events (created in 09_payment_events.sql) already has its indexes.

-- ============================================================================
-- ANALYZE so the planner can see the new indexes immediately.
-- ============================================================================
ANALYZE follows;
ANALYZE reviews;
ANALYZE food_interactions;
ANALYZE notifications;
ANALYZE posts;
ANALYZE saved_items;
ANALYZE auth_sessions;
ANALYZE subscriptions;

-- ============================================================================
-- DONE.
-- ============================================================================
