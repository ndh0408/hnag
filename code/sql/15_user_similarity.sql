-- ============================================================================
-- 15 — Collaborative-filtering scaffolding
-- ----------------------------------------------------------------------------
-- Audit production-killer §3 ("Recommendation Layer 3-5"). The current
-- ranker has taste embeddings + skip memory (B8); next layer up is
-- collaborative filtering: "users who liked X also liked Y". This file
-- provides the storage layer; the offline-build job is in
-- code/backend/src/modules/ai/services/cf-builder.service.ts.
--
-- Two tables:
--
--   user_similarity      — top-K most-similar users for each user
--                          (cosine over the food_interactions matrix)
--   food_co_view         — pairs of foods commonly liked together
--                          (PMI / Jaccard on the food-user matrix)
--
-- Both are append-rebuild — a nightly cron drops + recomputes them. No
-- online updates yet. When user count crosses ~100k, replace with an
-- incremental builder (we have time).
--
-- Storage cost at 100k users × top-50 neighbours = 5M rows × ~40 bytes =
-- ~200 MB. Comfortable on the current Postgres.
--
-- Apply once:
--   docker exec -i hnag-postgres psql -U hnag -d hnag < code/sql/15_user_similarity.sql
-- ============================================================================

CREATE TABLE IF NOT EXISTS user_similarity (
  user_id       UUID NOT NULL,
  neighbor_id   UUID NOT NULL,
  similarity    REAL NOT NULL,          -- 0..1, cosine
  computed_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, neighbor_id)
);

CREATE INDEX IF NOT EXISTS idx_user_similarity_user_sim
  ON user_similarity (user_id, similarity DESC);
CREATE INDEX IF NOT EXISTS idx_user_similarity_computed
  ON user_similarity (computed_at);

COMMENT ON TABLE user_similarity IS
  'Top-K most-similar users for CF recommendations. Rebuild nightly.';

-- ── Food co-view ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS food_co_view (
  food_a        UUID NOT NULL,
  food_b        UUID NOT NULL,
  co_count      INT NOT NULL,           -- raw co-occurrence count
  jaccard       REAL NOT NULL,          -- 0..1
  computed_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (food_a, food_b),
  CHECK (food_a <> food_b)
);

CREATE INDEX IF NOT EXISTS idx_food_co_view_a_jaccard
  ON food_co_view (food_a, jaccard DESC);

COMMENT ON TABLE food_co_view IS
  'Top-K most-co-occurring food pairs. Drives the "users who liked X also liked Y" surface.';

-- ── Build view (used by the cron) ──────────────────────────────────────────
-- Quick boolean preference matrix used as input by the CF builder. A view
-- not a table so it's always live; the cron snapshots it at run time.
CREATE OR REPLACE VIEW v_user_food_likes AS
SELECT user_id, food_id
FROM food_interactions
WHERE action IN ('save', 'cook', 'order', 'dine')
   OR (action = 'rate' AND rating >= 4);

COMMENT ON VIEW v_user_food_likes IS
  'Implicit-feedback positives — what the CF builder considers a "like".';

-- ============================================================================
-- DONE.
-- ============================================================================
