-- ============================================================================
-- HNAG — Hôm Nay Ăn Gì? — DATABASE SCHEMA v1
-- PostgreSQL 15+ with PostGIS extension
-- ============================================================================

-- Required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "postgis";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";          -- fuzzy search
CREATE EXTENSION IF NOT EXISTS "unaccent";          -- Vietnamese diacritic-insensitive search

-- ============================================================================
-- ENUMS
-- ============================================================================
CREATE TYPE user_status        AS ENUM ('active', 'paused', 'suspended', 'deleted');
CREATE TYPE diet_type          AS ENUM ('none', 'vegetarian', 'vegan', 'pescatarian', 'halal', 'keto', 'low_carb');
CREATE TYPE cook_skill         AS ENUM ('none', 'basic', 'intermediate', 'pro');
CREATE TYPE health_goal        AS ENUM ('lose', 'maintain', 'gain', 'clean', 'none');
CREATE TYPE food_category      AS ENUM ('noodle','rice','soup','snack','dessert','drink','grill','street','fastfood','seafood','vegetarian');
CREATE TYPE meal_type          AS ENUM ('breakfast','lunch','dinner','snack','latenight','brunch');
CREATE TYPE origin_region      AS ENUM ('bac','trung','nam','other','intl');
CREATE TYPE action_type        AS ENUM ('viewed','saved','skipped','cooked','ordered','ate','rated','shared','checked_in');
CREATE TYPE order_partner      AS ENUM ('grabfood','shopeefood','befood','gojek','loship','walkin','dinein','manual');
CREATE TYPE order_status       AS ENUM ('intent','placed','confirmed','preparing','delivering','delivered','cancelled');
CREATE TYPE poll_status        AS ENUM ('open','closed','expired');
CREATE TYPE notification_type  AS ENUM ('ai_suggest','social_like','social_comment','social_follow','order_status','streak','group_invite','poll','system','tip');
CREATE TYPE subscription_plan  AS ENUM ('monthly','yearly','family_monthly','family_yearly');
CREATE TYPE subscription_status AS ENUM ('trialing','active','past_due','cancelled','expired');

-- ============================================================================
-- USERS & PROFILE
-- ============================================================================
CREATE TABLE users (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone             VARCHAR(20) UNIQUE,
  phone_hash        VARCHAR(64) UNIQUE,
  email             VARCHAR(160) UNIQUE,
  username          VARCHAR(40) UNIQUE,
  display_name      VARCHAR(80),
  avatar_url        TEXT,
  cover_url         TEXT,
  bio               TEXT,
  city              VARCHAR(80),
  district          VARCHAR(80),
  birthdate         DATE,
  gender            VARCHAR(20),
  language          VARCHAR(8) DEFAULT 'vi',
  level             SMALLINT DEFAULT 1,
  xp                INT DEFAULT 0,
  foodie_class      VARCHAR(20) DEFAULT 'tep',           -- tep,cua,muc,camap,rong,vua
  is_verified       BOOLEAN DEFAULT FALSE,
  is_creator        BOOLEAN DEFAULT FALSE,
  is_premium        BOOLEAN DEFAULT FALSE,
  premium_until     TIMESTAMPTZ,
  food_dna          JSONB,
  privacy_settings  JSONB DEFAULT '{}'::jsonb,
  status            user_status DEFAULT 'active',
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW(),
  last_seen_at      TIMESTAMPTZ
);
CREATE INDEX idx_users_city          ON users(city);
CREATE INDEX idx_users_username_low  ON users(LOWER(username));
CREATE INDEX idx_users_premium       ON users(is_premium) WHERE is_premium = TRUE;
CREATE INDEX idx_users_last_seen     ON users(last_seen_at DESC);

CREATE TABLE user_preferences (
  user_id           UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  allergies         TEXT[]  DEFAULT '{}',
  diet_type         diet_type DEFAULT 'none',
  cuisines_love     TEXT[]  DEFAULT '{}',
  cuisines_hate     TEXT[]  DEFAULT '{}',
  spicy_tolerance   SMALLINT CHECK (spicy_tolerance BETWEEN 0 AND 5),
  sweet_tolerance   SMALLINT CHECK (sweet_tolerance BETWEEN 0 AND 5),
  salty_tolerance   SMALLINT CHECK (salty_tolerance BETWEEN 0 AND 5),
  budget_min        INT,
  budget_max        INT,
  cook_skill        cook_skill DEFAULT 'basic',
  health_goal       health_goal DEFAULT 'none',
  daily_calorie     INT,
  macros_target     JSONB,
  notification_pref JSONB DEFAULT '{"push": true, "email": false, "zalo": true, "quiet_hours": [22,7]}',
  updated_at        TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE user_devices (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID REFERENCES users(id) ON DELETE CASCADE,
  device_id       VARCHAR(120) UNIQUE,
  platform        VARCHAR(20),           -- ios, android, web
  app_version     VARCHAR(40),
  os_version      VARCHAR(40),
  push_token      TEXT,
  locale          VARCHAR(10),
  last_active_at  TIMESTAMPTZ DEFAULT NOW(),
  created_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_user_devices_user ON user_devices(user_id);

CREATE TABLE auth_sessions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID REFERENCES users(id) ON DELETE CASCADE,
  device_id     UUID REFERENCES user_devices(id),
  refresh_token_hash VARCHAR(120) UNIQUE,
  expires_at    TIMESTAMPTZ,
  ip_inet       INET,
  user_agent    TEXT,
  revoked_at    TIMESTAMPTZ,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- FOODS (master catalog)
-- ============================================================================
CREATE TABLE foods (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name_vi         VARCHAR(180) NOT NULL,
  name_en         VARCHAR(180),
  slug            VARCHAR(200) UNIQUE,
  description     TEXT,
  primary_image   TEXT,
  images          TEXT[],
  primary_video   TEXT,
  origin_region   origin_region DEFAULT 'other',
  cuisine         VARCHAR(60) DEFAULT 'vietnamese',
  category        food_category,
  meal_types      meal_type[] DEFAULT '{}',
  diet_tags       TEXT[] DEFAULT '{}',
  flavor_tags     TEXT[] DEFAULT '{}',
  mood_tags       TEXT[] DEFAULT '{}',
  vibe_tags       TEXT[] DEFAULT '{}',
  avg_calories    INT,
  avg_price_vnd   INT,
  cook_time_min   INT,
  difficulty      SMALLINT CHECK (difficulty BETWEEN 1 AND 5),
  ingredients     JSONB,
  recipe          JSONB,
  nutrition       JSONB,
  allergens       TEXT[] DEFAULT '{}',
  spicy_level     SMALLINT CHECK (spicy_level BETWEEN 0 AND 5),
  sweet_level     SMALLINT CHECK (sweet_level BETWEEN 0 AND 5),
  popularity      INT DEFAULT 0,
  trending_score  NUMERIC(6,2) DEFAULT 0,
  rating_avg      NUMERIC(3,2) DEFAULT 0,
  rating_count    INT DEFAULT 0,
  embedding_id    UUID,
  is_seasonal     BOOLEAN DEFAULT FALSE,
  season_tags     TEXT[] DEFAULT '{}',
  status          VARCHAR(20) DEFAULT 'active',
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_foods_cuisine     ON foods(cuisine);
CREATE INDEX idx_foods_category    ON foods(category);
CREATE INDEX idx_foods_origin      ON foods(origin_region);
CREATE INDEX idx_foods_diet        ON foods USING gin(diet_tags);
CREATE INDEX idx_foods_mood        ON foods USING gin(mood_tags);
CREATE INDEX idx_foods_meal_types  ON foods USING gin(meal_types);
CREATE INDEX idx_foods_trending    ON foods(trending_score DESC) WHERE status = 'active';
CREATE INDEX idx_foods_name_trgm   ON foods USING gin(name_vi gin_trgm_ops);
CREATE INDEX idx_foods_popularity  ON foods(popularity DESC);

-- ============================================================================
-- RESTAURANTS
-- ============================================================================
CREATE TABLE restaurants (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name           VARCHAR(180) NOT NULL,
  slug           VARCHAR(200) UNIQUE,
  description    TEXT,
  cover_image    TEXT,
  images         TEXT[] DEFAULT '{}',
  videos         TEXT[] DEFAULT '{}',
  address        TEXT,
  city           VARCHAR(80),
  district       VARCHAR(80),
  ward           VARCHAR(80),
  location       GEOGRAPHY(POINT, 4326),
  phone          VARCHAR(30),
  email          VARCHAR(160),
  website        TEXT,
  open_hours     JSONB,
  price_level    SMALLINT CHECK (price_level BETWEEN 1 AND 4),
  cuisine_tags   TEXT[] DEFAULT '{}',
  feature_tags   TEXT[] DEFAULT '{}',      -- wifi, parking, family, ac, view, rooftop
  vibe_tags      TEXT[] DEFAULT '{}',      -- date, casual, fancy, business
  rating_avg     NUMERIC(3,2) DEFAULT 0,
  rating_count   INT DEFAULT 0,
  delivery_links JSONB DEFAULT '{}'::jsonb,
  is_verified    BOOLEAN DEFAULT FALSE,
  is_claimed     BOOLEAN DEFAULT FALSE,
  is_sponsored   BOOLEAN DEFAULT FALSE,
  sponsor_until  TIMESTAMPTZ,
  popularity     INT DEFAULT 0,
  trending_score NUMERIC(6,2) DEFAULT 0,
  status         VARCHAR(20) DEFAULT 'active',
  owner_user_id  UUID REFERENCES users(id),
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_restaurants_location  ON restaurants USING gist(location);
CREATE INDEX idx_restaurants_city      ON restaurants(city, district);
CREATE INDEX idx_restaurants_cuisine   ON restaurants USING gin(cuisine_tags);
CREATE INDEX idx_restaurants_name_trgm ON restaurants USING gin(name gin_trgm_ops);
CREATE INDEX idx_restaurants_trending  ON restaurants(trending_score DESC) WHERE status = 'active';

CREATE TABLE menu_items (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE,
  food_id       UUID REFERENCES foods(id) ON DELETE SET NULL,
  name          VARCHAR(180),
  description   TEXT,
  image_url     TEXT,
  price_vnd     INT,
  category      VARCHAR(60),
  available     BOOLEAN DEFAULT TRUE,
  is_signature  BOOLEAN DEFAULT FALSE,
  position      INT DEFAULT 0,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_menu_restaurant ON menu_items(restaurant_id);
CREATE INDEX idx_menu_food       ON menu_items(food_id);

-- Restaurant live status (high-write, separated)
CREATE TABLE restaurant_live (
  restaurant_id   UUID PRIMARY KEY REFERENCES restaurants(id) ON DELETE CASCADE,
  is_open         BOOLEAN DEFAULT TRUE,
  closing_in_min  INT,
  crowdedness     NUMERIC(3,2),       -- 0.0–1.0
  wait_minutes    INT,
  recent_orders_24h INT DEFAULT 0,
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- USER ↔ FOOD/RESTAURANT INTERACTIONS
-- ============================================================================
CREATE TABLE food_interactions (
  id          BIGSERIAL PRIMARY KEY,
  user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
  food_id     UUID REFERENCES foods(id) ON DELETE CASCADE,
  restaurant_id UUID REFERENCES restaurants(id),
  action      action_type NOT NULL,
  context     JSONB,
  rating      SMALLINT CHECK (rating BETWEEN 1 AND 5),
  session_id  UUID,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_fi_user_time   ON food_interactions(user_id, created_at DESC);
CREATE INDEX idx_fi_food        ON food_interactions(food_id, created_at DESC);
CREATE INDEX idx_fi_action      ON food_interactions(action);

CREATE TABLE saved_items (
  user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
  food_id     UUID REFERENCES foods(id) ON DELETE CASCADE,
  collection  VARCHAR(60) DEFAULT 'default',
  note        TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, food_id, collection)
);

CREATE TABLE saved_restaurants (
  user_id       UUID REFERENCES users(id) ON DELETE CASCADE,
  restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE,
  collection    VARCHAR(60) DEFAULT 'default',
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, restaurant_id, collection)
);

-- ============================================================================
-- REVIEWS
-- ============================================================================
CREATE TABLE reviews (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID REFERENCES users(id) ON DELETE CASCADE,
  restaurant_id   UUID REFERENCES restaurants(id),
  food_id         UUID REFERENCES foods(id),
  rating          SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  title           VARCHAR(180),
  content         TEXT,
  images          TEXT[] DEFAULT '{}',
  video_url       TEXT,
  price_paid_vnd  INT,
  helpful_count   INT DEFAULT 0,
  reply_count     INT DEFAULT 0,
  is_verified     BOOLEAN DEFAULT FALSE,
  is_flagged      BOOLEAN DEFAULT FALSE,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_reviews_restaurant ON reviews(restaurant_id, created_at DESC);
CREATE INDEX idx_reviews_user       ON reviews(user_id, created_at DESC);
CREATE INDEX idx_reviews_helpful    ON reviews(helpful_count DESC);

CREATE TABLE review_helpful (
  review_id UUID REFERENCES reviews(id) ON DELETE CASCADE,
  user_id   UUID REFERENCES users(id)   ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (review_id, user_id)
);

CREATE TABLE review_replies (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id   UUID REFERENCES reviews(id) ON DELETE CASCADE,
  user_id     UUID REFERENCES users(id)   ON DELETE CASCADE,
  content     TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- ORDERS (delivery aggregator)
-- ============================================================================
CREATE TABLE orders (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID REFERENCES users(id),
  partner        order_partner NOT NULL,
  external_id    VARCHAR(120),
  restaurant_id  UUID REFERENCES restaurants(id),
  items          JSONB NOT NULL,
  total_vnd      INT,
  discount_vnd   INT DEFAULT 0,
  status         order_status DEFAULT 'intent',
  context        JSONB,
  placed_at      TIMESTAMPTZ DEFAULT NOW(),
  confirmed_at   TIMESTAMPTZ,
  delivered_at   TIMESTAMPTZ,
  cancelled_at   TIMESTAMPTZ,
  notes          TEXT
);
CREATE INDEX idx_orders_user   ON orders(user_id, placed_at DESC);
CREATE INDEX idx_orders_status ON orders(status);

-- ============================================================================
-- FRIDGE INVENTORY
-- ============================================================================
CREATE TABLE fridge_items (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID REFERENCES users(id) ON DELETE CASCADE,
  name         VARCHAR(120) NOT NULL,
  name_en      VARCHAR(120),
  quantity     NUMERIC(10,2),
  unit         VARCHAR(20),
  category     VARCHAR(40),
  source       VARCHAR(20),               -- scan, manual, import
  confidence   NUMERIC(3,2),
  added_at     TIMESTAMPTZ DEFAULT NOW(),
  expires_at   DATE,
  consumed_at  TIMESTAMPTZ
);
CREATE INDEX idx_fridge_user ON fridge_items(user_id) WHERE consumed_at IS NULL;

-- ============================================================================
-- MEAL PLAN
-- ============================================================================
CREATE TABLE meal_plans (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID REFERENCES users(id) ON DELETE CASCADE,
  week_start   DATE NOT NULL,
  plan_json    JSONB NOT NULL,             -- {monday: {breakfast,lunch,dinner,snack}, ...}
  total_calorie INT,
  total_budget INT,
  shopping_list JSONB,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (user_id, week_start)
);

-- ============================================================================
-- GROUPS & VOTING
-- ============================================================================
CREATE TABLE groups (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name         VARCHAR(120),
  description  TEXT,
  avatar_url   TEXT,
  type         VARCHAR(20) DEFAULT 'casual',  -- casual, crew, family, office, event
  creator_id   UUID REFERENCES users(id),
  invite_code  VARCHAR(20) UNIQUE,
  is_active    BOOLEAN DEFAULT TRUE,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE group_members (
  group_id   UUID REFERENCES groups(id) ON DELETE CASCADE,
  user_id    UUID REFERENCES users(id) ON DELETE CASCADE,
  role       VARCHAR(20) DEFAULT 'member',  -- creator, admin, member
  nickname   VARCHAR(80),
  joined_at  TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (group_id, user_id)
);

CREATE TABLE group_polls (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id     UUID REFERENCES groups(id) ON DELETE CASCADE,
  creator_id   UUID REFERENCES users(id),
  status       poll_status DEFAULT 'open',
  options      JSONB NOT NULL,                  -- [{food_id, restaurant_id, name, image}]
  votes        JSONB DEFAULT '{}'::jsonb,       -- {user_id: [option_idx, ...]}
  context      JSONB,
  closes_at    TIMESTAMPTZ,
  closed_at    TIMESTAMPTZ,
  winner       JSONB,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_polls_group   ON group_polls(group_id, created_at DESC);
CREATE INDEX idx_polls_status  ON group_polls(status);

-- ============================================================================
-- COUPLE LINKS
-- ============================================================================
CREATE TABLE couples (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_a          UUID REFERENCES users(id) ON DELETE CASCADE,
  user_b          UUID REFERENCES users(id) ON DELETE CASCADE,
  anniversary     DATE,
  status          VARCHAR(20) DEFAULT 'active',  -- pending, active, paused, dissolved
  shared_emb      JSONB,                          -- cached shared taste embedding hash
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  dissolved_at    TIMESTAMPTZ,
  UNIQUE (user_a, user_b)
);

-- ============================================================================
-- SOCIAL — Posts, Stories, Follows
-- ============================================================================
CREATE TABLE follows (
  follower_id  UUID REFERENCES users(id) ON DELETE CASCADE,
  followee_id  UUID REFERENCES users(id) ON DELETE CASCADE,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (follower_id, followee_id)
);
CREATE INDEX idx_follows_followee ON follows(followee_id);

CREATE TABLE posts (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID REFERENCES users(id) ON DELETE CASCADE,
  type           VARCHAR(20) DEFAULT 'photo',  -- photo, video, review, story
  caption        TEXT,
  media_url      TEXT,
  media_poster   TEXT,
  blurhash       VARCHAR(40),
  food_id        UUID REFERENCES foods(id),
  restaurant_id  UUID REFERENCES restaurants(id),
  location       GEOGRAPHY(POINT, 4326),
  music_id       VARCHAR(120),
  tags           TEXT[] DEFAULT '{}',
  like_count     INT DEFAULT 0,
  comment_count  INT DEFAULT 0,
  view_count     INT DEFAULT 0,
  save_count     INT DEFAULT 0,
  share_count    INT DEFAULT 0,
  quality_score  NUMERIC(4,2) DEFAULT 0,
  is_flagged     BOOLEAN DEFAULT FALSE,
  is_archived    BOOLEAN DEFAULT FALSE,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_posts_user    ON posts(user_id, created_at DESC);
CREATE INDEX idx_posts_food    ON posts(food_id);
CREATE INDEX idx_posts_recent  ON posts(created_at DESC) WHERE is_archived = FALSE;

CREATE TABLE post_likes (
  post_id   UUID REFERENCES posts(id) ON DELETE CASCADE,
  user_id   UUID REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (post_id, user_id)
);

CREATE TABLE post_comments (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id     UUID REFERENCES posts(id) ON DELETE CASCADE,
  user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
  parent_id   UUID REFERENCES post_comments(id),
  content     TEXT NOT NULL,
  like_count  INT DEFAULT 0,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_comments_post ON post_comments(post_id, created_at);

CREATE TABLE stories (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID REFERENCES users(id) ON DELETE CASCADE,
  media_url    TEXT,
  type         VARCHAR(20),  -- photo, video, checkin, poll, food_tag
  data         JSONB,
  restaurant_id UUID REFERENCES restaurants(id),
  view_count   INT DEFAULT 0,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  expires_at   TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '24 hours')
);
CREATE INDEX idx_stories_active ON stories(user_id, expires_at);

CREATE TABLE check_ins (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID REFERENCES users(id) ON DELETE CASCADE,
  restaurant_id UUID REFERENCES restaurants(id),
  food_id      UUID REFERENCES foods(id),
  caption      TEXT,
  image_url    TEXT,
  location     GEOGRAPHY(POINT, 4326),
  gps_verified BOOLEAN DEFAULT FALSE,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_checkins_user ON check_ins(user_id, created_at DESC);
CREATE INDEX idx_checkins_rest ON check_ins(restaurant_id, created_at DESC);

CREATE TABLE blocks (
  blocker_id UUID REFERENCES users(id) ON DELETE CASCADE,
  blocked_id UUID REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (blocker_id, blocked_id)
);

-- ============================================================================
-- SUBSCRIPTIONS
-- ============================================================================
CREATE TABLE subscriptions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES users(id),
  plan        subscription_plan NOT NULL,
  status      subscription_status DEFAULT 'trialing',
  provider    VARCHAR(20),  -- apple, google, stripe, momo, zalopay
  external_id VARCHAR(120),
  amount_vnd  INT,
  started_at  TIMESTAMPTZ DEFAULT NOW(),
  trial_ends_at TIMESTAMPTZ,
  current_period_end TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  cancel_reason TEXT,
  auto_renew  BOOLEAN DEFAULT TRUE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_subs_user   ON subscriptions(user_id);
CREATE INDEX idx_subs_active ON subscriptions(status) WHERE status IN ('trialing','active');

-- ============================================================================
-- GAMIFICATION
-- ============================================================================
CREATE TABLE achievements (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code        VARCHAR(80) UNIQUE NOT NULL,
  name_vi     VARCHAR(120) NOT NULL,
  name_en     VARCHAR(120),
  description TEXT,
  icon_url    TEXT,
  tier        VARCHAR(20),  -- common, rare, epic, legendary
  xp_reward   INT DEFAULT 0,
  criteria    JSONB,
  hidden      BOOLEAN DEFAULT FALSE
);

CREATE TABLE user_achievements (
  user_id        UUID REFERENCES users(id) ON DELETE CASCADE,
  achievement_id UUID REFERENCES achievements(id),
  progress       NUMERIC(5,2) DEFAULT 0,
  unlocked_at    TIMESTAMPTZ,
  PRIMARY KEY (user_id, achievement_id)
);

CREATE TABLE streaks (
  user_id       UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  daily_decide  INT DEFAULT 0,
  daily_open    INT DEFAULT 0,
  cook_streak   INT DEFAULT 0,
  review_streak INT DEFAULT 0,
  last_decide   DATE,
  last_open     DATE,
  last_cook     DATE,
  last_review   DATE,
  best_decide   INT DEFAULT 0,
  best_cook     INT DEFAULT 0,
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE daily_quests (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code        VARCHAR(80),
  name_vi     VARCHAR(120),
  description TEXT,
  xp_reward   INT,
  criteria    JSONB,
  active_date DATE
);

CREATE TABLE user_quests (
  user_id    UUID REFERENCES users(id) ON DELETE CASCADE,
  quest_id   UUID REFERENCES daily_quests(id),
  progress   NUMERIC(5,2) DEFAULT 0,
  completed_at TIMESTAMPTZ,
  date       DATE DEFAULT CURRENT_DATE,
  PRIMARY KEY (user_id, quest_id, date)
);

-- ============================================================================
-- NOTIFICATIONS
-- ============================================================================
CREATE TABLE notifications (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
  type        notification_type NOT NULL,
  title       TEXT,
  body        TEXT,
  image_url   TEXT,
  data        JSONB,
  read_at     TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_notifs_user_time ON notifications(user_id, created_at DESC);
CREATE INDEX idx_notifs_unread    ON notifications(user_id) WHERE read_at IS NULL;

-- ============================================================================
-- AI SESSION LOGS (for training + replay)
-- ============================================================================
CREATE TABLE ai_sessions (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID REFERENCES users(id),
  mode         VARCHAR(20),                  -- quick, detail, mood, voice, fridge, group
  input        JSONB,
  output_cards JSONB,
  ranker_scores JSONB,
  reason_codes TEXT[],
  latency_ms   INT,
  llm_cost_usd NUMERIC(8,5),
  feedback     JSONB,                         -- {action, food_id}
  created_at   TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_ai_sessions_user ON ai_sessions(user_id, created_at DESC);
CREATE INDEX idx_ai_sessions_mode ON ai_sessions(mode);

-- ============================================================================
-- VIRAL CONTENT (TikTok ingestion)
-- ============================================================================
CREATE TABLE viral_dishes (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  food_id        UUID REFERENCES foods(id),
  dish_label     VARCHAR(180),
  velocity_score NUMERIC(6,2),
  diversity_score NUMERIC(4,2),
  total_views    BIGINT,
  detected_at    TIMESTAMPTZ DEFAULT NOW(),
  peak_at        TIMESTAMPTZ,
  status         VARCHAR(20) DEFAULT 'rising'
);

CREATE TABLE viral_videos (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  viral_dish_id   UUID REFERENCES viral_dishes(id) ON DELETE CASCADE,
  platform        VARCHAR(20),
  external_url    TEXT,
  creator_handle  VARCHAR(120),
  views           BIGINT,
  likes           BIGINT,
  posted_at       TIMESTAMPTZ,
  ingested_at     TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- ANALYTICS (light — heavy goes to ClickHouse via Kafka)
-- ============================================================================
CREATE TABLE events_archive (
  id          BIGSERIAL NOT NULL,
  user_id     UUID,
  session_id  UUID,
  event_name  VARCHAR(80),
  props       JSONB,
  app_version VARCHAR(40),
  platform    VARCHAR(20),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- create initial partition (monthly)
CREATE TABLE events_archive_2026_01 PARTITION OF events_archive
  FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');

-- ============================================================================
-- AUDIT
-- ============================================================================
CREATE TABLE admin_audit_log (
  id          BIGSERIAL PRIMARY KEY,
  admin_id    UUID,
  action      VARCHAR(120),
  target_type VARCHAR(60),
  target_id   UUID,
  before      JSONB,
  after       JSONB,
  ip_inet     INET,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- VIEWS — common aggregates
-- ============================================================================
CREATE MATERIALIZED VIEW mv_restaurant_stats AS
SELECT
  r.id AS restaurant_id,
  COUNT(DISTINCT rv.id)                            AS total_reviews,
  COALESCE(AVG(rv.rating)::numeric(3,2), 0)         AS rating_avg,
  COUNT(DISTINCT ci.id)                            AS total_checkins,
  COUNT(DISTINCT ci.user_id)                       AS unique_visitors
FROM restaurants r
LEFT JOIN reviews rv  ON rv.restaurant_id = r.id
LEFT JOIN check_ins ci ON ci.restaurant_id = r.id
GROUP BY r.id;
CREATE UNIQUE INDEX ON mv_restaurant_stats(restaurant_id);

-- ============================================================================
-- TRIGGERS
-- ============================================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated   BEFORE UPDATE ON users        FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_foods_updated   BEFORE UPDATE ON foods        FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_rest_updated    BEFORE UPDATE ON restaurants  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_reviews_updated BEFORE UPDATE ON reviews      FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_meal_updated    BEFORE UPDATE ON meal_plans   FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Update review count + avg on insert
CREATE OR REPLACE FUNCTION on_review_insert() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.restaurant_id IS NOT NULL THEN
    UPDATE restaurants
       SET rating_count = rating_count + 1,
           rating_avg   = ((rating_avg * rating_count) + NEW.rating)::numeric / (rating_count + 1)
     WHERE id = NEW.restaurant_id;
  END IF;
  IF NEW.food_id IS NOT NULL THEN
    UPDATE foods
       SET rating_count = rating_count + 1,
           rating_avg   = ((rating_avg * rating_count) + NEW.rating)::numeric / (rating_count + 1)
     WHERE id = NEW.food_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_review_aggregate AFTER INSERT ON reviews FOR EACH ROW EXECUTE FUNCTION on_review_insert();

-- Follow count caching is intentionally NOT a trigger here — denormalize via async worker
-- to avoid hot-row contention on heavy followee accounts.

-- ============================================================================
-- ROW-LEVEL SECURITY HOOKS (for admin/B2B isolation, V2)
-- ============================================================================
-- ALTER TABLE restaurants ENABLE ROW LEVEL SECURITY;
-- (policies defined later when admin roles introduced)

-- ============================================================================
-- DONE
-- ============================================================================
