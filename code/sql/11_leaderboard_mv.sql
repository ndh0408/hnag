-- ============================================================================
-- 11 — Materialized view for the leaderboard
-- ----------------------------------------------------------------------------
-- Closes audit hnag-audit-2026-05 §11 (HIGH) / §34: the live leaderboard
-- query at challenges.service.ts:102-113 used to scan users × reviews +
-- GROUP BY on every page view → 2-5s. With this MV the query is a
-- straight SELECT … FROM leaderboard_weekly LIMIT 100 → sub-millisecond.
--
-- Refresh strategy:
--   * REFRESH MATERIALIZED VIEW CONCURRENTLY every 5 minutes (cheap on
--     <100k users, parallelizable, doesn't block readers)
--   * pg_cron lines are at the bottom; install with `CREATE EXTENSION
--     pg_cron;` if not already present, OR use a backend cron job.
--
-- Apply once:
--   docker exec -i hnag-postgres psql -U hnag -d hnag < code/sql/11_leaderboard_mv.sql
-- ============================================================================

-- ── Weekly leaderboard ───────────────────────────────────────────────────────
DROP MATERIALIZED VIEW IF EXISTS leaderboard_weekly CASCADE;
CREATE MATERIALIZED VIEW leaderboard_weekly AS
SELECT
  u.id,
  u.username,
  u.display_name,
  u.avatar_url,
  u.city,
  u.foodie_class,
  u.xp,
  COUNT(r.id)::int                AS reviews_count,
  COALESCE(AVG(r.rating), 0)::numeric(3,2) AS avg_rating,
  MAX(r.created_at)               AS last_review_at
FROM users u
LEFT JOIN reviews r
  ON r.user_id = u.id
 AND r.created_at >= NOW() - INTERVAL '7 days'
WHERE u.status = 'active'
GROUP BY u.id
HAVING COUNT(r.id) > 0
ORDER BY reviews_count DESC, u.xp DESC, u.id ASC;

-- Required for REFRESH ... CONCURRENTLY
CREATE UNIQUE INDEX IF NOT EXISTS idx_leaderboard_weekly_id
  ON leaderboard_weekly (id);
CREATE INDEX IF NOT EXISTS idx_leaderboard_weekly_city_rank
  ON leaderboard_weekly (city, reviews_count DESC);

-- ── Monthly leaderboard ──────────────────────────────────────────────────────
DROP MATERIALIZED VIEW IF EXISTS leaderboard_monthly CASCADE;
CREATE MATERIALIZED VIEW leaderboard_monthly AS
SELECT
  u.id,
  u.username,
  u.display_name,
  u.avatar_url,
  u.city,
  u.foodie_class,
  u.xp,
  COUNT(r.id)::int                AS reviews_count,
  COALESCE(AVG(r.rating), 0)::numeric(3,2) AS avg_rating,
  MAX(r.created_at)               AS last_review_at
FROM users u
LEFT JOIN reviews r
  ON r.user_id = u.id
 AND r.created_at >= NOW() - INTERVAL '30 days'
WHERE u.status = 'active'
GROUP BY u.id
HAVING COUNT(r.id) > 0
ORDER BY reviews_count DESC, u.xp DESC, u.id ASC;

CREATE UNIQUE INDEX IF NOT EXISTS idx_leaderboard_monthly_id
  ON leaderboard_monthly (id);
CREATE INDEX IF NOT EXISTS idx_leaderboard_monthly_city_rank
  ON leaderboard_monthly (city, reviews_count DESC);

-- ── Refresh helpers ──────────────────────────────────────────────────────────
-- A single function the backend can call (or pg_cron can schedule) to
-- refresh both views without blocking readers.
CREATE OR REPLACE FUNCTION refresh_leaderboards()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_weekly;
  REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_monthly;
END;
$$ LANGUAGE plpgsql;

-- ── Optional: pg_cron schedule (uncomment after `CREATE EXTENSION pg_cron;`)
-- SELECT cron.schedule('refresh-leaderboards', '*/5 * * * *', $$SELECT refresh_leaderboards();$$);

-- Fallback if pg_cron isn't available: the backend's @nestjs/schedule
-- CronJob calls `SELECT refresh_leaderboards();` every 5 minutes — wire
-- this in `code/backend/src/modules/challenges/leaderboard-refresh.cron.ts`.

-- Seed an initial population now so the very first query has data.
SELECT refresh_leaderboards();

-- ============================================================================
-- DONE.
-- ============================================================================
