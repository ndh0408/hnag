-- ============================================================================
-- HNAG — Hôm Nay Ăn Gì? — 08_hardening.sql
-- DB HARDENING MIGRATION (idempotent) — generated from audit findings
-- ----------------------------------------------------------------------------
-- Target: PostgreSQL 15 + PostGIS 3.4
-- Pre-installed extensions assumed: pg_trgm, unaccent, pgcrypto, postgis, uuid-ossp
-- (pgvector "vector" is created here with IF NOT EXISTS).
--
-- WHAT THIS FILE DOES
--   1. Adds the ~20 missing foreign-key / hot-column indexes the audit flagged.
--   2. Fixes the events_archive partition time-bomb (adds DEFAULT partition +
--      pre-creates monthly partitions 2026-02 .. 2027-01).
--   3. Adds Vietnamese full-text search (tsvector) on foods & restaurants via an
--      IMMUTABLE unaccent wrapper + GIN indexes.
--   4. Prepares pgvector: enables extension, adds foods.embedding vector(256).
--      (HNSW index left COMMENTED OUT — create it AFTER backfilling embeddings.)
--   5. Adds a partial GiST spatial index for the "nearby active restaurants" query.
--
-- EVERY statement is idempotent (IF NOT EXISTS / CREATE OR REPLACE / DO-guards),
-- so this file is safe to re-run on the live, populated DB.
--
-- !!! CONCURRENTLY cannot run inside a transaction block !!!
-- Run with:
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f 08_hardening.sql
--   (do NOT wrap in BEGIN/COMMIT; uses CREATE INDEX CONCURRENTLY)
-- If you must run statement-by-statement, run each CONCURRENTLY line on its own.
-- ============================================================================


-- ============================================================================
-- SECTION 1 — MISSING FOREIGN-KEY / HOT-COLUMN INDEXES
-- Unindexed FK columns cause slow joins and, worse, slow/locking cascade
-- deletes on the parent table. CONCURRENTLY avoids taking an exclusive lock
-- on the (populated) tables. IF NOT EXISTS makes each safe to re-run.
-- ----------------------------------------------------------------------------

-- restaurants.owner_user_id  -> users(id)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_restaurants_owner
  ON restaurants(owner_user_id);

-- food_interactions.restaurant_id  -> restaurants(id)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fi_restaurant
  ON food_interactions(restaurant_id);

-- reviews.food_id  -> foods(id)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_reviews_food
  ON reviews(food_id);

-- orders.restaurant_id  -> restaurants(id)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_orders_restaurant
  ON orders(restaurant_id);

-- posts.restaurant_id  -> restaurants(id)   (idx_posts_food already exists for food_id)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_posts_restaurant
  ON posts(restaurant_id);

-- check_ins.food_id  -> foods(id)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_checkins_food
  ON check_ins(food_id);

-- stories.restaurant_id  -> restaurants(id)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_stories_restaurant
  ON stories(restaurant_id);

-- review_replies.review_id  -> reviews(id)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_review_replies_review
  ON review_replies(review_id);

-- review_replies.user_id  -> users(id)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_review_replies_user
  ON review_replies(user_id);

-- post_comments.user_id  -> users(id)   (idx_comments_post already covers post_id)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_post_comments_user
  ON post_comments(user_id);

-- post_comments.parent_id  -> post_comments(id)  (threaded replies)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_post_comments_parent
  ON post_comments(parent_id);

-- auth_sessions.user_id  -> users(id)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_auth_sessions_user
  ON auth_sessions(user_id);

-- auth_sessions.device_id  -> user_devices(id)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_auth_sessions_device
  ON auth_sessions(device_id);

-- groups.creator_id  -> users(id)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_groups_creator
  ON groups(creator_id);

-- group_polls.creator_id  -> users(id)  (idx_polls_group already covers group_id)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_group_polls_creator
  ON group_polls(creator_id);

-- subscriptions(provider, external_id)  — provider webhook reconciliation lookups
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_subs_provider_external
  ON subscriptions(provider, external_id);

-- orders(partner, external_id)  — aggregator webhook reconciliation lookups
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_orders_partner_external
  ON orders(partner, external_id);

-- user_achievements.achievement_id  -> achievements(id)
-- (PK is (user_id, achievement_id); leading-col user_id is indexed by PK,
--  but achievement_id alone is not — needed for "who unlocked X" + cascade.)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_achievements_achievement
  ON user_achievements(achievement_id);

-- couples.user_b  -> users(id)
-- (UNIQUE(user_a, user_b) indexes user_a as leading col; user_b is not indexed.)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_couples_user_b
  ON couples(user_b);

-- viral_videos.viral_dish_id  -> viral_dishes(id)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_viral_videos_dish
  ON viral_videos(viral_dish_id);

-- blocks.blocked_id  -> users(id)
-- (PK is (blocker_id, blocked_id); blocked_id alone is not indexed — needed for
--  "is user X blocked by anyone" checks + cascade delete.)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_blocks_blocked
  ON blocks(blocked_id);


-- ============================================================================
-- SECTION 2 — PARTITION TIME-BOMB FIX FOR events_archive
-- events_archive is RANGE-partitioned by created_at (TIMESTAMPTZ) but only
-- events_archive_2026_01 exists. Any insert dated outside Jan-2026 currently
-- FAILS ("no partition of relation ... found for row").
--
-- Fix: (a) add a DEFAULT partition so no insert can ever fail, and
--      (b) pre-create explicit monthly partitions 2026-02 .. 2027-01 so hot
--          recent data does not all land in the (unindexable-by-range) default.
-- All CREATE TABLE ... PARTITION OF use IF NOT EXISTS → idempotent.
-- NOTE: creating the DEFAULT partition takes a brief lock on the parent; the
--       explicit monthly partitions below will then be routed normally.
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS events_archive_default
  PARTITION OF events_archive DEFAULT;

CREATE TABLE IF NOT EXISTS events_archive_2026_02 PARTITION OF events_archive
  FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
CREATE TABLE IF NOT EXISTS events_archive_2026_03 PARTITION OF events_archive
  FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
CREATE TABLE IF NOT EXISTS events_archive_2026_04 PARTITION OF events_archive
  FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
CREATE TABLE IF NOT EXISTS events_archive_2026_05 PARTITION OF events_archive
  FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE IF NOT EXISTS events_archive_2026_06 PARTITION OF events_archive
  FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE IF NOT EXISTS events_archive_2026_07 PARTITION OF events_archive
  FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS events_archive_2026_08 PARTITION OF events_archive
  FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE IF NOT EXISTS events_archive_2026_09 PARTITION OF events_archive
  FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE IF NOT EXISTS events_archive_2026_10 PARTITION OF events_archive
  FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE IF NOT EXISTS events_archive_2026_11 PARTITION OF events_archive
  FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE IF NOT EXISTS events_archive_2026_12 PARTITION OF events_archive
  FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');
CREATE TABLE IF NOT EXISTS events_archive_2027_01 PARTITION OF events_archive
  FOR VALUES FROM ('2027-01-01') TO ('2027-02-01');

-- OPS REMINDER: schedule a monthly job (pg_cron / external cron) to create the
-- next month's partition ahead of time, e.g.:
--   CREATE TABLE IF NOT EXISTS events_archive_2027_02 PARTITION OF events_archive
--     FOR VALUES FROM ('2027-02-01') TO ('2027-03-01');
-- With the DEFAULT partition in place, a missed month is no longer fatal — rows
-- just land in events_archive_default until you detach+redistribute them.


-- ============================================================================
-- SECTION 3 — VIETNAMESE FULL-TEXT SEARCH (foods & restaurants)
-- We build a STORED generated tsvector column. We use the 'simple' config
-- (no stemming — appropriate for Vietnamese) over unaccent()-folded text so
-- search is diacritic-insensitive ("pho" matches "phở").
--
-- GOTCHA: public.unaccent(text) is STABLE, not IMMUTABLE, so it cannot be used
-- directly in a generated column. We wrap it in an IMMUTABLE SQL function that
-- pins the dictionary by name (public.unaccent(regdictionary, text)).
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION f_unaccent(text)
  RETURNS text
  LANGUAGE sql
  IMMUTABLE
  PARALLEL SAFE
  RETURNS NULL ON NULL INPUT
AS $$
  SELECT public.unaccent('public.unaccent', $1)
$$;

-- array_to_string is treated as non-IMMUTABLE by the planner in a generated
-- column context; wrap it in an IMMUTABLE function so the array (cuisine_tags)
-- can be folded into the tsvector.
CREATE OR REPLACE FUNCTION f_arr2text(text[])
  RETURNS text
  LANGUAGE sql
  IMMUTABLE
  PARALLEL SAFE
AS $$
  SELECT array_to_string(coalesce($1, '{}'), ' ')
$$;

-- ---- foods.search_tsv ----
-- Real text columns on foods: name_vi (req NOT NULL), name_en, description, cuisine.
-- (NOTE: foods has NO cuisine_tags / tags column — it has scalar `cuisine` plus
--  several *_tags arrays; we weight name highest, cuisine + description lower.)
ALTER TABLE foods
  ADD COLUMN IF NOT EXISTS search_tsv tsvector
  GENERATED ALWAYS AS (
      setweight(to_tsvector('simple', f_unaccent(coalesce(name_vi, ''))), 'A')
   || setweight(to_tsvector('simple', f_unaccent(coalesce(name_en, ''))), 'B')
   || setweight(to_tsvector('simple', f_unaccent(coalesce(cuisine, ''))), 'C')
   || setweight(to_tsvector('simple', f_unaccent(coalesce(description, ''))), 'D')
  ) STORED;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_foods_search_tsv
  ON foods USING gin(search_tsv);

-- ---- restaurants.search_tsv ----
-- Real text columns: name (NOT NULL), description, cuisine_tags (TEXT[]).
-- array_to_string folds the cuisine_tags array into searchable text.
ALTER TABLE restaurants
  ADD COLUMN IF NOT EXISTS search_tsv tsvector
  GENERATED ALWAYS AS (
      setweight(to_tsvector('simple', f_unaccent(coalesce(name, ''))), 'A')
   || setweight(to_tsvector('simple', f_unaccent(f_arr2text(cuisine_tags))), 'B')
   || setweight(to_tsvector('simple', f_unaccent(coalesce(description, ''))), 'C')
  ) STORED;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_restaurants_search_tsv
  ON restaurants USING gin(search_tsv);

-- USAGE (reference):
--   SELECT id, name_vi
--   FROM foods
--   WHERE search_tsv @@ websearch_to_tsquery('simple', f_unaccent('pho bo'))
--   ORDER BY ts_rank(search_tsv, websearch_to_tsquery('simple', f_unaccent('pho bo'))) DESC
--   LIMIT 20;


-- ============================================================================
-- SECTION 4 — PGVECTOR READINESS (foods.embedding)
-- Enable pgvector and add a 256-dim embedding column. The existing
-- foods.embedding_id (UUID) is an external pointer; this NEW column holds the
-- actual vector for in-DB ANN search.
-- ----------------------------------------------------------------------------

-- pgvector is NOT bundled with the postgis/postgis image, so guard the whole
-- section: if the extension isn't installable, skip without aborting the migration.
-- To enable later, switch the DB image to one with pgvector (e.g. pgvector/pgvector
-- or add the extension to the image) and re-run this file.
DO $pgv$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'vector') THEN
    CREATE EXTENSION IF NOT EXISTS vector;
    ALTER TABLE foods ADD COLUMN IF NOT EXISTS embedding vector(256);
    RAISE NOTICE 'pgvector enabled; foods.embedding ready.';
  ELSE
    RAISE NOTICE 'pgvector NOT available in this image — skipping embedding column. Use a pgvector-enabled Postgres image to enable ANN search.';
  END IF;
END
$pgv$;

-- !!! BACKFILL FIRST !!!
-- Building an HNSW index on an all-NULL column is allowed but pointless, and it
-- still pays the build cost. Backfill foods.embedding for all active rows, THEN
-- create the index ONCE (uncomment the line below, or run it via the ops runbook).
-- CONCURRENTLY is required so the build does not lock the populated foods table.
--
--   CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_foods_embedding
--     ON foods USING hnsw (embedding vector_cosine_ops)
--     WITH (m = 16, ef_construction = 64);
--
-- Query side (after index exists), set probe quality per-session:
--   SET hnsw.ef_search = 64;
--   SELECT id, name_vi
--   FROM foods
--   WHERE embedding IS NOT NULL
--   ORDER BY embedding <=> $1::vector(256)   -- cosine distance, KNN via HNSW
--   LIMIT 20;


-- ============================================================================
-- SECTION 5 — PARTIAL COMPOSITE SPATIAL INDEX (nearby active restaurants)
-- Most "nearby" queries filter status='active'. A partial GiST index on
-- location restricted to active rows is smaller and faster than the existing
-- full idx_restaurants_location for that hot path.
-- ----------------------------------------------------------------------------

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_restaurants_loc_active
  ON restaurants USING gist(location)
  WHERE status = 'active';


-- ============================================================================
-- DONE.
-- ----------------------------------------------------------------------------
-- REFERENCE ONLY (do NOT execute here) — recommended nearby-query rewrite using
-- the GiST KNN <-> operator so the partial spatial index above is used for the
-- ORDER BY (true index-ordered nearest-neighbour), with ST_DWithin as the
-- bounded pre-filter:
--
--   -- :lon, :lat = user location; :radius_m = search radius in metres
--   WITH origin AS (
--     SELECT ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography AS g
--   )
--   SELECT r.id,
--          r.name,
--          ST_Distance(r.location, o.g) AS distance_m
--   FROM restaurants r, origin o
--   WHERE r.status = 'active'
--     AND r.location IS NOT NULL
--     AND ST_DWithin(r.location, o.g, :radius_m)   -- uses idx_restaurants_loc_active (bbox)
--   ORDER BY r.location <-> o.g                      -- KNN index-ordered nearest first
--   LIMIT 20;
--
-- Notes:
--   * <-> on geography returns distance in metres; ordering is index-assisted.
--   * Keep ST_DWithin so the planner can bound the candidate set; without a
--     radius, drop ST_DWithin and rely purely on <-> + LIMIT for top-K.
--   * The WHERE status='active' must match the partial index predicate exactly
--     for the planner to use idx_restaurants_loc_active.
-- ============================================================================
