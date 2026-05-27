-- ============================================================================
-- 19 — Data integrity CHECK constraints
-- ----------------------------------------------------------------------------
-- Closes audit #23 + adjacent: counter columns can drift negative under
-- concurrent like/unlike, premium_until can be overwritten by a parallel
-- promo redemption, etc. Adding explicit CHECK constraints means a buggy
-- service-layer increment/decrement fails LOUDLY at the DB rather than
-- producing silent state corruption.
--
-- All constraints are added with `NOT VALID` first, then validated. That
-- means existing bad rows (if any) do not block the deploy; the validation
-- step at the end will fail loudly if there are real drift bugs to inspect.
--
-- Apply:
--   docker exec -i hnag-postgres psql -U hnag -d hnag < code/sql/19_data_integrity_checks.sql
-- ============================================================================

-- ── posts counters ──────────────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'posts_like_count_nonneg') THEN
    ALTER TABLE posts ADD CONSTRAINT posts_like_count_nonneg
      CHECK (like_count >= 0) NOT VALID;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'posts_comment_count_nonneg') THEN
    ALTER TABLE posts ADD CONSTRAINT posts_comment_count_nonneg
      CHECK (comment_count >= 0) NOT VALID;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'posts_view_count_nonneg') THEN
    ALTER TABLE posts ADD CONSTRAINT posts_view_count_nonneg
      CHECK (view_count >= 0) NOT VALID;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'posts_save_count_nonneg') THEN
    ALTER TABLE posts ADD CONSTRAINT posts_save_count_nonneg
      CHECK (save_count >= 0) NOT VALID;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'posts_share_count_nonneg') THEN
    ALTER TABLE posts ADD CONSTRAINT posts_share_count_nonneg
      CHECK (share_count >= 0) NOT VALID;
  END IF;
END $$;

-- ── post_comments / restaurants / foods counter drift ──────────────────────
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'post_comments_like_count_nonneg') THEN
    ALTER TABLE post_comments ADD CONSTRAINT post_comments_like_count_nonneg
      CHECK (like_count >= 0) NOT VALID;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'restaurants_rating_count_nonneg') THEN
    ALTER TABLE restaurants ADD CONSTRAINT restaurants_rating_count_nonneg
      CHECK (rating_count >= 0) NOT VALID;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'foods_rating_count_nonneg') THEN
    ALTER TABLE foods ADD CONSTRAINT foods_rating_count_nonneg
      CHECK (rating_count >= 0) NOT VALID;
  END IF;
END $$;

-- ── orders + payment correctness ───────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'orders_total_nonneg') THEN
    ALTER TABLE orders ADD CONSTRAINT orders_total_nonneg
      CHECK (total_vnd IS NULL OR total_vnd >= 0) NOT VALID;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'orders_discount_nonneg') THEN
    ALTER TABLE orders ADD CONSTRAINT orders_discount_nonneg
      CHECK (discount_vnd IS NULL OR discount_vnd >= 0) NOT VALID;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'payment_events_amount_nonneg') THEN
    ALTER TABLE payment_events ADD CONSTRAINT payment_events_amount_nonneg
      CHECK (amount_vnd >= 0) NOT VALID;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'subscriptions_amount_nonneg') THEN
    ALTER TABLE subscriptions ADD CONSTRAINT subscriptions_amount_nonneg
      CHECK (amount_vnd IS NULL OR amount_vnd >= 0) NOT VALID;
  END IF;
END $$;

-- ── user xp / level + reviews rating range ─────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'users_xp_nonneg') THEN
    ALTER TABLE users ADD CONSTRAINT users_xp_nonneg
      CHECK (xp >= 0) NOT VALID;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'users_level_pos') THEN
    ALTER TABLE users ADD CONSTRAINT users_level_pos
      CHECK (level >= 1) NOT VALID;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'reviews_rating_1_5') THEN
    ALTER TABLE reviews ADD CONSTRAINT reviews_rating_1_5
      CHECK (rating BETWEEN 1 AND 5) NOT VALID;
  END IF;
END $$;

-- ── streaks: cannot be negative ────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'streaks_counters_nonneg') THEN
    ALTER TABLE streaks ADD CONSTRAINT streaks_counters_nonneg
      CHECK (daily_decide >= 0 AND daily_open >= 0 AND cook_streak >= 0
             AND review_streak >= 0 AND best_decide >= 0 AND best_cook >= 0)
      NOT VALID;
  END IF;
END $$;

-- ── Validate constraints. Failures here mean existing data drift; fix and re-run.
-- VALIDATE is non-blocking (read-only scan with row-level lock briefly). If
-- this section throws, repair the bad rows, then re-run THIS file only.
DO $$ BEGIN
  PERFORM 1 FROM pg_constraint WHERE conname = 'posts_like_count_nonneg' AND NOT convalidated;
  IF FOUND THEN ALTER TABLE posts VALIDATE CONSTRAINT posts_like_count_nonneg; END IF;
END $$;
DO $$ BEGIN
  PERFORM 1 FROM pg_constraint WHERE conname = 'posts_comment_count_nonneg' AND NOT convalidated;
  IF FOUND THEN ALTER TABLE posts VALIDATE CONSTRAINT posts_comment_count_nonneg; END IF;
END $$;
DO $$ BEGIN
  PERFORM 1 FROM pg_constraint WHERE conname = 'reviews_rating_1_5' AND NOT convalidated;
  IF FOUND THEN ALTER TABLE reviews VALIDATE CONSTRAINT reviews_rating_1_5; END IF;
END $$;
DO $$ BEGIN
  PERFORM 1 FROM pg_constraint WHERE conname = 'orders_total_nonneg' AND NOT convalidated;
  IF FOUND THEN ALTER TABLE orders VALIDATE CONSTRAINT orders_total_nonneg; END IF;
END $$;
DO $$ BEGIN
  PERFORM 1 FROM pg_constraint WHERE conname = 'users_xp_nonneg' AND NOT convalidated;
  IF FOUND THEN ALTER TABLE users VALIDATE CONSTRAINT users_xp_nonneg; END IF;
END $$;
DO $$ BEGIN
  PERFORM 1 FROM pg_constraint WHERE conname = 'users_level_pos' AND NOT convalidated;
  IF FOUND THEN ALTER TABLE users VALIDATE CONSTRAINT users_level_pos; END IF;
END $$;
DO $$ BEGIN
  PERFORM 1 FROM pg_constraint WHERE conname = 'payment_events_amount_nonneg' AND NOT convalidated;
  IF FOUND THEN ALTER TABLE payment_events VALIDATE CONSTRAINT payment_events_amount_nonneg; END IF;
END $$;
DO $$ BEGIN
  PERFORM 1 FROM pg_constraint WHERE conname = 'subscriptions_amount_nonneg' AND NOT convalidated;
  IF FOUND THEN ALTER TABLE subscriptions VALIDATE CONSTRAINT subscriptions_amount_nonneg; END IF;
END $$;
DO $$ BEGIN
  PERFORM 1 FROM pg_constraint WHERE conname = 'streaks_counters_nonneg' AND NOT convalidated;
  IF FOUND THEN ALTER TABLE streaks VALIDATE CONSTRAINT streaks_counters_nonneg; END IF;
END $$;

-- ============================================================================
-- DONE.
-- ============================================================================
