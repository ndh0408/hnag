-- ============================================================================
-- 13 — Analytics events
-- ----------------------------------------------------------------------------
-- Audit hnag-audit-2026-05 prompt-pack §11 launch checklist: "user behavior
-- tracking", "session analytics", "recommendation analytics", "search
-- analytics" — none of these had a backing store. `food_interactions` is
-- specialized to the recommender; everything else (impressions, scroll,
-- screen-view, button-click) had nowhere to land.
--
-- This is the single thin table for product analytics. Keep it lean — we
-- ingest at high volume and run aggregate queries off MVs or a separate
-- warehouse (BigQuery / ClickHouse) in the future. Don't add joins-by-id
-- columns here.
--
-- The deletion path treats `user_id` as a soft FK: when a user deletes
-- their account, `users.service.deleteAccount` anonymises the row in
-- place but does NOT cascade to analytics_events — those rows are aggregate
-- forensic data already aggregated downstream, removing them would break
-- weekly rollups. New rows with the deleted user_id will never appear
-- because the JWT for that account is revoked.
-- ============================================================================

CREATE TABLE IF NOT EXISTS analytics_events (
  id           BIGSERIAL PRIMARY KEY,
  user_id      UUID,                       -- nullable: anonymous events
  session_id   UUID,                       -- the AI suggest session id, when applicable
  event        TEXT NOT NULL,              -- 'suggest:impression' | 'food:view' | 'search:query' | 'screen:view' | …
  source       TEXT,                       -- 'app' | 'web' | 'owner-dash' | 'admin'
  app_version  TEXT,
  platform     TEXT,                       -- 'ios' | 'android' | 'web'
  city         TEXT,                       -- if known (request-time)
  properties   JSONB NOT NULL DEFAULT '{}'::jsonb,
  occurred_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_analytics_events_event_time
  ON analytics_events (event, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_analytics_events_user_time
  ON analytics_events (user_id, occurred_at DESC)
  WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_analytics_events_session
  ON analytics_events (session_id)
  WHERE session_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_analytics_events_time
  ON analytics_events (occurred_at DESC);

COMMENT ON TABLE analytics_events IS
  'Append-only product analytics. High write volume; aggregate via MVs.';

-- Retention sketch (out of scope for this migration):
--   - keep raw rows 90 days
--   - daily MV (event, day, count) for 2 years
--   - hourly MV (event, hour, count) for 30 days
-- Implement once volume exceeds ~10M/month.

-- ============================================================================
-- DONE.
-- ============================================================================
