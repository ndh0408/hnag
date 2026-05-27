-- ============================================================================
-- 16 — Cohort & retention views
-- ----------------------------------------------------------------------------
-- Audit production-killer §6 ("event-driven analytics — retention cohorts,
-- AI acceptance rate"). The `analytics_events` table (sql/13) collects
-- raw events; this file adds the rollup views the admin dashboard and
-- weekly reviews need.
--
-- Views vs. materialized views:
--   - DAU / WAU are MATERIALIZED — read-heavy on dashboards, write-once
--     per day via the leaderboard refresh cron.
--   - Funnel + acceptance views are plain VIEWS — they aggregate over
--     small windows (last 7-30 days) on demand. Cheap enough to leave
--     un-materialized until the dataset grows past a few million rows.
--
-- Apply once:
--   docker exec -i hnag-postgres psql -U hnag -d hnag < code/sql/16_cohort_views.sql
-- ============================================================================

-- ── DAU (last 30 days) ─────────────────────────────────────────────────────
DROP MATERIALIZED VIEW IF EXISTS daily_active_users CASCADE;
CREATE MATERIALIZED VIEW daily_active_users AS
SELECT
  DATE_TRUNC('day', occurred_at)::date     AS day,
  COUNT(DISTINCT user_id)                  AS users,
  COUNT(*)                                 AS events,
  COUNT(*) FILTER (WHERE event = 'ai:suggest')                   AS ai_suggests,
  COUNT(*) FILTER (WHERE event LIKE 'ai:feedback:%')             AS ai_feedbacks,
  COUNT(*) FILTER (WHERE event = 'order:intent')                 AS order_intents
FROM analytics_events
WHERE occurred_at >= NOW() - INTERVAL '30 days'
  AND user_id IS NOT NULL
GROUP BY 1;

CREATE UNIQUE INDEX IF NOT EXISTS idx_dau_day ON daily_active_users (day);

-- ── WAU (last 12 weeks) ────────────────────────────────────────────────────
DROP MATERIALIZED VIEW IF EXISTS weekly_active_users CASCADE;
CREATE MATERIALIZED VIEW weekly_active_users AS
SELECT
  DATE_TRUNC('week', occurred_at)::date    AS week,
  COUNT(DISTINCT user_id)                  AS users,
  COUNT(*)                                 AS events
FROM analytics_events
WHERE occurred_at >= NOW() - INTERVAL '12 weeks'
  AND user_id IS NOT NULL
GROUP BY 1;

CREATE UNIQUE INDEX IF NOT EXISTS idx_wau_week ON weekly_active_users (week);

-- ── Sign-up cohort retention (D1 / D7 / D30) ───────────────────────────────
-- For each signup-week cohort, what % came back on day 1 / 7 / 30. The
-- single retention question every consumer app needs answered.
DROP MATERIALIZED VIEW IF EXISTS retention_cohorts CASCADE;
CREATE MATERIALIZED VIEW retention_cohorts AS
WITH first_seen AS (
  SELECT user_id, MIN(DATE_TRUNC('day', occurred_at)::date) AS signup_day
    FROM analytics_events
   WHERE user_id IS NOT NULL
   GROUP BY user_id
),
cohort_size AS (
  SELECT DATE_TRUNC('week', signup_day)::date AS cohort_week, COUNT(*) AS cohort_n
    FROM first_seen GROUP BY 1
),
returns AS (
  SELECT
    DATE_TRUNC('week', f.signup_day)::date AS cohort_week,
    COUNT(DISTINCT f.user_id) FILTER (
      WHERE EXISTS (
        SELECT 1 FROM analytics_events e
         WHERE e.user_id = f.user_id
           AND e.occurred_at::date = f.signup_day + INTERVAL '1 day'
      )
    ) AS d1,
    COUNT(DISTINCT f.user_id) FILTER (
      WHERE EXISTS (
        SELECT 1 FROM analytics_events e
         WHERE e.user_id = f.user_id
           AND e.occurred_at::date = f.signup_day + INTERVAL '7 days'
      )
    ) AS d7,
    COUNT(DISTINCT f.user_id) FILTER (
      WHERE EXISTS (
        SELECT 1 FROM analytics_events e
         WHERE e.user_id = f.user_id
           AND e.occurred_at::date = f.signup_day + INTERVAL '30 days'
      )
    ) AS d30
  FROM first_seen f
  GROUP BY 1
)
SELECT
  c.cohort_week,
  c.cohort_n,
  r.d1,
  r.d7,
  r.d30,
  ROUND(100.0 * r.d1::numeric  / NULLIF(c.cohort_n, 0), 2) AS d1_rate,
  ROUND(100.0 * r.d7::numeric  / NULLIF(c.cohort_n, 0), 2) AS d7_rate,
  ROUND(100.0 * r.d30::numeric / NULLIF(c.cohort_n, 0), 2) AS d30_rate
FROM cohort_size c
JOIN returns r USING (cohort_week)
ORDER BY c.cohort_week DESC;

CREATE UNIQUE INDEX IF NOT EXISTS idx_retention_week ON retention_cohorts (cohort_week);

-- ── AI acceptance rate (live view, no MV) ──────────────────────────────────
-- For each AI suggest session, did the user actually save / order / cook a
-- recommended dish? Window = 24h after session creation.
CREATE OR REPLACE VIEW ai_acceptance_24h AS
WITH sessions AS (
  SELECT id, user_id, created_at
    FROM ai_sessions
   WHERE created_at >= NOW() - INTERVAL '30 days'
),
positive AS (
  SELECT s.id AS session_id, s.user_id, s.created_at,
         BOOL_OR(f.action IN ('save', 'cook', 'order', 'dine')) AS accepted
    FROM sessions s
    LEFT JOIN food_interactions f
      ON f.session_id = s.id
     AND f.created_at BETWEEN s.created_at AND s.created_at + INTERVAL '24 hours'
   GROUP BY s.id, s.user_id, s.created_at
)
SELECT
  DATE_TRUNC('day', created_at)::date AS day,
  COUNT(*)                            AS sessions,
  COUNT(*) FILTER (WHERE accepted)    AS accepted_sessions,
  ROUND(100.0 * COUNT(*) FILTER (WHERE accepted)::numeric / NULLIF(COUNT(*), 0), 2)
                                       AS acceptance_rate_pct
FROM positive
GROUP BY 1
ORDER BY 1 DESC;

-- ── Funnel — onboarding step views (last 14 days) ──────────────────────────
CREATE OR REPLACE VIEW onboarding_funnel_14d AS
SELECT
  event                                 AS step,
  COUNT(DISTINCT user_id)               AS users_reached,
  COUNT(*)                              AS step_views
FROM analytics_events
WHERE occurred_at >= NOW() - INTERVAL '14 days'
  AND event LIKE 'screen:view'
  AND (properties->>'screen') LIKE 'onboarding/%'
GROUP BY 1
ORDER BY 2 DESC;

-- ── Refresh helper (call from a cron, or wire to leaderboard-refresh) ───────
CREATE OR REPLACE FUNCTION refresh_cohort_views()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY daily_active_users;
  REFRESH MATERIALIZED VIEW CONCURRENTLY weekly_active_users;
  REFRESH MATERIALIZED VIEW CONCURRENTLY retention_cohorts;
END;
$$ LANGUAGE plpgsql;

-- Seed an initial population.
SELECT refresh_cohort_views();

-- ============================================================================
-- DONE.
-- ============================================================================
