# 03 — Technical Architecture

> **Engineering principles:** *AI-native by design · Realtime by default · Vietnam-first scale · Privacy by construction.*

---

## 1. High-Level Architecture

```
                       ┌─────────────────────────────────────────┐
                       │              CLIENT LAYER                │
                       │                                          │
   ┌─────────┐         │  ┌──────────────┐    ┌───────────────┐  │
   │ Mobile  │◀───────▶│  │  Flutter App │    │  Next.js Web  │  │
   │  Users  │         │  │  (iOS+Android)│   │   (PWA+Web)   │  │
   └─────────┘         │  └──────┬───────┘    └───────┬───────┘  │
                       │         │                    │          │
                       └─────────┼────────────────────┼──────────┘
                                 │                    │
                            ┌────▼────────────────────▼────┐
                            │   Cloudflare CDN + WAF       │
                            └────────────────┬──────────────┘
                                             │
                                  ┌──────────▼──────────┐
                                  │  API Gateway        │
                                  │  (AWS API Gateway   │
                                  │   + Kong)           │
                                  └──┬─────┬─────┬───┬──┘
                                     │     │     │   │
              ┌──────────────────────┘     │     │   └────────────┐
              │                            │     │                │
   ┌──────────▼─────────┐    ┌────────────▼──┐ ┌▼──────────┐ ┌──▼─────────┐
   │   AUTH SERVICE     │    │  CORE API     │ │  AI ORCH  │ │ REALTIME   │
   │  - JWT             │    │  - Node.js    │ │  - Python │ │ - WS/Socket│
   │  - Firebase Auth   │    │  - NestJS     │ │  - FastAPI│ │   .io      │
   │  - OAuth/Phone OTP │    │  - REST+GQL   │ │           │ │ - MQTT     │
   └──────────┬─────────┘    └──────┬────────┘ └────┬──────┘ └─────┬──────┘
              │                     │               │              │
              └────────┬────────────┴───────┬───────┴──────────────┘
                       │                    │
              ┌────────▼─────────┐  ┌───────▼─────────┐
              │   DATA LAYER     │  │   AI/ML LAYER   │
              │                  │  │                 │
              │ ┌──────────────┐ │  │ ┌─────────────┐ │
              │ │ PostgreSQL   │ │  │ │ OpenAI GPT  │ │
              │ │ (relational) │ │  │ │ 4o + Claude │ │
              │ └──────────────┘ │  │ └─────────────┘ │
              │ ┌──────────────┐ │  │ ┌─────────────┐ │
              │ │ MongoDB      │ │  │ │ Custom CV   │ │
              │ │ (social/feed)│ │  │ │ (YOLOv8/SAM)│ │
              │ └──────────────┘ │  │ └─────────────┘ │
              │ ┌──────────────┐ │  │ ┌─────────────┐ │
              │ │ Redis (cache,│ │  │ │ Pinecone    │ │
              │ │ sessions, RT)│ │  │ │ (vector DB) │ │
              │ └──────────────┘ │  │ └─────────────┘ │
              │ ┌──────────────┐ │  │ ┌─────────────┐ │
              │ │ Elasticsearch│ │  │ │ Whisper +   │ │
              │ │ (search)     │ │  │ │ VBee TTS    │ │
              │ └──────────────┘ │  │ └─────────────┘ │
              │ ┌──────────────┐ │  │ ┌─────────────┐ │
              │ │ S3 (media)   │ │  │ │ Recommend   │ │
              │ │              │ │  │ │ Engine (RS) │ │
              │ └──────────────┘ │  │ └─────────────┘ │
              │ ┌──────────────┐ │  │                 │
              │ │ Kafka        │ │  │                 │
              │ │ (events)     │ │  │                 │
              │ └──────────────┘ │  │                 │
              └──────────────────┘  └─────────────────┘
                       │
              ┌────────▼─────────────────────────────────┐
              │       INTEGRATIONS LAYER                  │
              │                                           │
              │  GrabFood  ShopeeFood  beFood  Mapbox     │
              │  Weather   Apple Health  Google Calendar  │
              │  Momo/ZaloPay  Stripe  Firebase  Datadog  │
              └───────────────────────────────────────────┘
```

---

## 2. Tech Stack — Detail

### 2.1 Frontend

| Layer | Tech | Reason |
|-------|------|--------|
| Mobile | **Flutter 3.x (Dart)** | Single codebase, 60 FPS, custom motion easy |
| Web | **Next.js 14 (App Router)** | SSR, SEO, ISR for restaurant pages |
| State | Riverpod (Flutter), Zustand (web) | Lean, testable |
| Routing | go_router (Flutter), Next.js | Type-safe |
| Animation | flutter_animate + Rive, Framer Motion (web) | Designer-friendly |
| Forms | Reactive Forms (Flutter), react-hook-form | Validation |
| Network | Dio + Retrofit (Flutter), tRPC (web) | Typed |
| Realtime | socket.io-client | WS + fallback |
| Maps | Mapbox SDK | custom style + offline |
| Camera | camera + image_picker (Flutter) | Fridge scan |
| Voice | speech_to_text + flutter_tts | Voice UI |
| Offline | Hive + drift (SQLite) | Cache |
| Push | FCM + APNs | Cross-platform |
| Analytics | Mixpanel + Amplitude | Funnel + cohort |
| Crash | Sentry | Frontend errors |

### 2.2 Backend

| Layer | Tech | Reason |
|-------|------|--------|
| API | **NestJS (Node.js + TypeScript)** | Modular, DI, testable |
| GraphQL | Apollo Server | For complex queries (admin, social graph) |
| Auth | Firebase Auth + custom JWT | Phone OTP friendly |
| Validation | class-validator + Zod | Type-safe boundaries |
| ORM | Prisma | Type-safe SQL |
| Cache | Redis 7 | TTL-based + pub/sub |
| Queue | BullMQ (Redis-backed) | Background jobs |
| Search | Elasticsearch 8 | Vietnamese analyzer + autocomplete |
| Events | Kafka 3.x | Event-sourcing critical flows |
| RPC | gRPC for internal service comm | Fast |
| Realtime | Socket.io + Redis adapter | Group voting, chat |
| Workers | Cloudflare Workers (edge) | Image resize, geolocation |
| Scheduler | Temporal | Meal plan reminders, complex workflows |

### 2.3 AI/ML

| Component | Tech |
|-----------|------|
| LLM (general) | OpenAI GPT-4o + GPT-4o-mini (cost optimization) |
| LLM (deep reasoning) | Anthropic Claude Opus 4.7 |
| Vision (food recognition) | YOLOv8 fine-tuned on 50K Vietnamese food images + Segment Anything for portion estimation |
| Recommendation Engine | Two-tower model (PyTorch) + LightGBM ranker |
| Embeddings | text-embedding-3-small (OpenAI) for items, sentence-transformers for VN text |
| Vector DB | Pinecone (serverless) — for semantic similarity |
| ASR | Whisper large-v3 + VinAI VinBERT for VN postprocess |
| TTS | VBee Vietnamese (natural) + ElevenLabs (multilingual fallback) |
| OCR | Tesseract + LayoutLM (menus) |
| MLOps | Weights & Biases, MLflow, BentoML for serving |
| Feature store | Feast |

### 2.4 Infrastructure

| Component | Tech |
|-----------|------|
| Cloud | AWS (primary) — Singapore + HK regions for VN latency |
| Container | Docker + Kubernetes (EKS) |
| Edge | Cloudflare (CDN, WAF, Workers, R2) |
| Storage | S3 (media), R2 (cold), EBS gp3 (databases) |
| DB hosting | RDS PostgreSQL Multi-AZ, MongoDB Atlas, ElastiCache Redis |
| CDN | Cloudflare + AWS CloudFront |
| Secrets | AWS Secrets Manager, Doppler dev |
| IaC | Terraform + Terragrunt |
| CI/CD | GitHub Actions → ArgoCD |
| Observability | Datadog (APM, logs, traces, RUM) + Grafana for metrics |
| Error tracking | Sentry |
| Feature flags | LaunchDarkly |
| A/B testing | Statsig |

---

## 3. Database Schema

### 3.1 Relational (PostgreSQL — core domain)

```sql
-- USERS
CREATE TABLE users (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone          VARCHAR(20) UNIQUE,
  email          VARCHAR(160) UNIQUE,
  username       VARCHAR(40) UNIQUE,
  display_name   VARCHAR(80),
  avatar_url     TEXT,
  bio            TEXT,
  city           VARCHAR(80),
  district       VARCHAR(80),
  birthdate      DATE,
  gender         VARCHAR(20),
  language       VARCHAR(8) DEFAULT 'vi',
  level          SMALLINT DEFAULT 1,
  xp             INT DEFAULT 0,
  is_verified    BOOLEAN DEFAULT FALSE,
  is_premium     BOOLEAN DEFAULT FALSE,
  premium_until  TIMESTAMPTZ,
  food_dna       JSONB,            -- preferences, embeddings hash
  status         VARCHAR(20) DEFAULT 'active',
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  updated_at     TIMESTAMPTZ DEFAULT NOW(),
  last_seen_at   TIMESTAMPTZ
);
CREATE INDEX idx_users_city ON users(city);
CREATE INDEX idx_users_username_lower ON users(LOWER(username));

-- USER PREFERENCES
CREATE TABLE user_preferences (
  user_id           UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  allergies         TEXT[],           -- ["peanut","shellfish"]
  diet_type         VARCHAR(40),      -- "none","vegetarian","vegan","keto"...
  cuisines_love     TEXT[],
  cuisines_hate     TEXT[],
  spicy_tolerance   SMALLINT,         -- 1–5
  sweet_tolerance   SMALLINT,
  budget_min        INT,
  budget_max        INT,
  cook_skill        VARCHAR(20),      -- "none","basic","intermediate","pro"
  health_goal       VARCHAR(40),      -- "lose","maintain","gain","clean"
  daily_calorie     INT,
  macros_target     JSONB,            -- {p:30,c:50,f:20}
  notification_pref JSONB,
  updated_at        TIMESTAMPTZ DEFAULT NOW()
);

-- FOOD ITEMS (master catalog)
CREATE TABLE foods (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name_vi        VARCHAR(180) NOT NULL,
  name_en        VARCHAR(180),
  slug           VARCHAR(200) UNIQUE,
  description    TEXT,
  primary_image  TEXT,
  images         TEXT[],
  origin_region  VARCHAR(60),         -- "bac","trung","nam","other"
  cuisine        VARCHAR(60),         -- "vietnamese","japanese"...
  category       VARCHAR(60),         -- "noodle","rice","soup","snack"
  meal_type      TEXT[],              -- ["breakfast","lunch"]
  diet_tags      TEXT[],              -- ["vegetarian","gluten_free"]
  flavor_tags    TEXT[],              -- ["spicy","sweet","umami"]
  mood_tags      TEXT[],              -- ["chill","comfort","sad"]
  avg_calories   INT,
  avg_price_vnd  INT,
  cook_time_min  INT,
  difficulty     SMALLINT,            -- 1–5
  ingredients    JSONB,               -- list of {name,qty,unit}
  recipe         JSONB,               -- steps + tips + video
  nutrition      JSONB,               -- macros, vitamins
  popularity     INT DEFAULT 0,
  rating_avg     NUMERIC(3,2),
  rating_count   INT DEFAULT 0,
  embedding_id   UUID,                -- ref to vector
  status         VARCHAR(20) DEFAULT 'active',
  created_at     TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_foods_cuisine ON foods(cuisine);
CREATE INDEX idx_foods_diet ON foods USING gin(diet_tags);
CREATE INDEX idx_foods_mood ON foods USING gin(mood_tags);

-- RESTAURANTS
CREATE TABLE restaurants (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name           VARCHAR(180) NOT NULL,
  slug           VARCHAR(200) UNIQUE,
  description    TEXT,
  cover_image    TEXT,
  images         TEXT[],
  address        TEXT,
  city           VARCHAR(80),
  district       VARCHAR(80),
  ward           VARCHAR(80),
  location       GEOGRAPHY(POINT, 4326),  -- PostGIS
  phone          VARCHAR(30),
  email          VARCHAR(160),
  website        TEXT,
  open_hours     JSONB,              -- per day-of-week
  price_level    SMALLINT,           -- 1–4 ($-$$$$)
  cuisine_tags   TEXT[],
  features       TEXT[],             -- ["wifi","parking","family"]
  rating_avg     NUMERIC(3,2),
  rating_count   INT DEFAULT 0,
  delivery_links JSONB,              -- {grabfood:"url",shopee:"url",be:"url"}
  is_verified    BOOLEAN DEFAULT FALSE,
  is_sponsored   BOOLEAN DEFAULT FALSE,
  status         VARCHAR(20) DEFAULT 'active',
  owner_id       UUID,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_restaurants_location ON restaurants USING gist(location);
CREATE INDEX idx_restaurants_city ON restaurants(city);

-- RESTAURANT MENU
CREATE TABLE menu_items (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE,
  food_id       UUID REFERENCES foods(id) ON DELETE SET NULL,
  name          VARCHAR(180),
  description   TEXT,
  image_url     TEXT,
  price_vnd     INT,
  available     BOOLEAN DEFAULT TRUE,
  position      INT
);

-- USER FOOD INTERACTIONS (implicit + explicit)
CREATE TABLE food_interactions (
  id          BIGSERIAL PRIMARY KEY,
  user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
  food_id     UUID REFERENCES foods(id) ON DELETE CASCADE,
  action      VARCHAR(20),  -- "viewed","saved","skipped","cooked","ordered","ate"
  context     JSONB,        -- {mood,budget,time,weather}
  rating      SMALLINT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_food_interactions_user_time ON food_interactions(user_id, created_at DESC);

-- REVIEWS
CREATE TABLE reviews (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID REFERENCES users(id),
  restaurant_id UUID REFERENCES restaurants(id),
  food_id       UUID REFERENCES foods(id),
  rating        SMALLINT CHECK (rating >= 1 AND rating <= 5),
  content       TEXT,
  images        TEXT[],
  video_url     TEXT,
  helpful_count INT DEFAULT 0,
  reply_count   INT DEFAULT 0,
  is_verified_order BOOLEAN DEFAULT FALSE,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ORDERS (delivery tracking aggregator)
CREATE TABLE orders (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID REFERENCES users(id),
  partner        VARCHAR(40),     -- "grabfood","shopee","be","walkin"
  external_id    VARCHAR(120),
  restaurant_id  UUID,
  items          JSONB,
  total_vnd      INT,
  status         VARCHAR(40),
  placed_at      TIMESTAMPTZ DEFAULT NOW(),
  delivered_at   TIMESTAMPTZ
);

-- FRIDGE INVENTORY
CREATE TABLE fridge_items (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID REFERENCES users(id) ON DELETE CASCADE,
  name         VARCHAR(120),
  quantity     NUMERIC(10,2),
  unit         VARCHAR(20),
  added_at     TIMESTAMPTZ DEFAULT NOW(),
  expires_at   DATE,
  source       VARCHAR(20),       -- "scan","manual","import"
  confidence   NUMERIC(3,2)
);

-- MEAL PLANS
CREATE TABLE meal_plans (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID REFERENCES users(id),
  week_start   DATE,
  plan_json    JSONB,             -- structured 7-day plan
  total_calorie INT,
  total_budget INT,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- GROUPS (voting)
CREATE TABLE groups (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name         VARCHAR(120),
  creator_id   UUID REFERENCES users(id),
  invite_code  VARCHAR(20) UNIQUE,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE group_members (
  group_id   UUID REFERENCES groups(id) ON DELETE CASCADE,
  user_id    UUID REFERENCES users(id) ON DELETE CASCADE,
  role       VARCHAR(20) DEFAULT 'member',
  joined_at  TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (group_id, user_id)
);

CREATE TABLE group_polls (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id     UUID REFERENCES groups(id) ON DELETE CASCADE,
  status       VARCHAR(20),       -- "open","closed"
  options      JSONB,              -- [{food_id,restaurant_id}]
  votes        JSONB,              -- {user_id:[option_idx]}
  closes_at    TIMESTAMPTZ,
  winner       JSONB
);

-- SUBSCRIPTIONS
CREATE TABLE subscriptions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES users(id),
  plan        VARCHAR(20),        -- "monthly","yearly"
  status      VARCHAR(20),
  provider    VARCHAR(20),        -- "apple","google","stripe","momo"
  external_id VARCHAR(120),
  started_at  TIMESTAMPTZ,
  expires_at  TIMESTAMPTZ,
  auto_renew  BOOLEAN DEFAULT TRUE
);

-- GAMIFICATION
CREATE TABLE achievements (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code        VARCHAR(60) UNIQUE,
  name        VARCHAR(120),
  description TEXT,
  icon_url    TEXT,
  xp_reward   INT
);

CREATE TABLE user_achievements (
  user_id        UUID REFERENCES users(id) ON DELETE CASCADE,
  achievement_id UUID REFERENCES achievements(id),
  unlocked_at    TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, achievement_id)
);

CREATE TABLE streaks (
  user_id       UUID REFERENCES users(id) PRIMARY KEY,
  daily_decide  INT DEFAULT 0,
  cook_streak   INT DEFAULT 0,
  last_decide   DATE,
  last_cook     DATE
);

-- FOLLOWS
CREATE TABLE follows (
  follower_id  UUID REFERENCES users(id) ON DELETE CASCADE,
  followee_id  UUID REFERENCES users(id) ON DELETE CASCADE,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (follower_id, followee_id)
);

-- NOTIFICATIONS
CREATE TABLE notifications (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
  type        VARCHAR(40),     -- "ai_suggest","social_like","order_status"...
  title       TEXT,
  body        TEXT,
  data        JSONB,
  read_at     TIMESTAMPTZ,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_notifications_user ON notifications(user_id, created_at DESC);

-- ANALYTICS EVENTS (also pipe to Kafka → ClickHouse)
CREATE TABLE events_archive (
  id          BIGSERIAL PRIMARY KEY,
  user_id     UUID,
  session_id  UUID,
  event_name  VARCHAR(80),
  props       JSONB,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
```

### 3.2 Document (MongoDB — social feed & flexible content)

**Collections:**
- `posts` — short videos, photos, reviews (high-write)
- `comments` — nested up to 2 levels
- `likes` — denormalized per post
- `stories` — TTL 24h
- `chat_messages` — group chats

**Why MongoDB here:** Schemaless content, embedded counters, fast reads with sharding by user_id.

### 3.3 Cache & Realtime (Redis)
- Session store
- Hot keys: trending restaurants per district (TTL 60s)
- Leaderboards (sorted sets)
- AI suggestion cache per user (TTL 5min)
- Pub/Sub for socket.io fanout
- Rate limiting (token bucket)

### 3.4 Vector DB (Pinecone)
- Index: `foods_vi` — 1536-dim embeddings of food name + description + tags
- Index: `restaurants_vi` — restaurant embeddings
- Index: `users_taste` — user food-DNA embeddings
- Use: semantic search, similar items, "users like you"

### 3.5 Search (Elasticsearch)
- Vietnamese analyzer custom (vi_analyzer with synonyms file: "phở" = "pho")
- Indexes: foods, restaurants, users, posts
- Auto-suggest, fuzzy, geo-distance sort

### 3.6 Event Store (Kafka)
**Topics:**
- `user.events` — signup, login, profile-update
- `interaction.events` — viewed/saved/skipped
- `order.events`
- `notification.events`
- `ai.queries` (sampled for training)

Consumers: Recommendation training, analytics → ClickHouse, fraud detection.

---

## 4. API Specification

### 4.1 Style
- REST + GraphQL hybrid
- REST for resource CRUD (foods, restaurants, users)
- GraphQL for complex queries (social feed, profile aggregates)
- WebSocket for realtime
- All responses: `{ success, data, error, meta }`

### 4.2 Authentication
- JWT access token (15 min) + refresh token (30 days)
- Phone OTP via Twilio + local provider (eSMS)
- Apple/Google sign-in via Firebase Auth
- Device binding for sensitive ops (delete account, change phone)

### 4.3 Core REST Endpoints

```
AUTH
POST   /v1/auth/otp/send                 { phone }
POST   /v1/auth/otp/verify               { phone, code } → tokens
POST   /v1/auth/oauth/{provider}         { idToken } → tokens
POST   /v1/auth/refresh                  { refreshToken } → tokens
POST   /v1/auth/logout

USERS
GET    /v1/users/me
PATCH  /v1/users/me                      profile + preferences
DELETE /v1/users/me
GET    /v1/users/{id}                    public profile
GET    /v1/users/{id}/followers
GET    /v1/users/{id}/following
POST   /v1/users/{id}/follow
DELETE /v1/users/{id}/follow

ONBOARDING
POST   /v1/onboarding/food-dna           initial preferences
GET    /v1/onboarding/foods/grid         60 foods for love/hate picker

AI — SUGGESTIONS (cornerstone)
POST   /v1/ai/suggest                    body: { mode, context }
  body: {
    mode: "quick" | "detail" | "mood" | "voice" | "fridge" | "group",
    context: {
      hunger: 1-10,
      budget: { min, max },
      time_min: number,
      mood: string,
      location: { lat, lng },
      diet: string,
      cuisine_pref: string[],
      with: "solo" | "couple" | "friends" | "family"
    },
    limit: 5
  }
  response: {
    cards: [
      {
        id, food_id, name, image, price, calories, time,
        reason: "AI explanation in VN",
        actions: ["cook","order","dine"],
        recipe: {...}, restaurants_nearby: [...]
      }
    ],
    session_id: "..."
  }

POST   /v1/ai/feedback                   { session_id, food_id, action }
POST   /v1/ai/refresh                    re-roll same context
POST   /v1/ai/voice                      multipart audio → text → suggest

AI — FRIDGE
POST   /v1/ai/fridge/scan                multipart image → { ingredients[] }
POST   /v1/ai/fridge/recipes             { ingredient_ids[] } → recipes[]

AI — MOOD
POST   /v1/ai/mood                       { mood } → cards[]

FOODS
GET    /v1/foods                          ?cuisine&diet&q&page
GET    /v1/foods/{id}
GET    /v1/foods/{id}/recipe
GET    /v1/foods/{id}/restaurants        nearby
GET    /v1/foods/trending                ?city&period

RESTAURANTS
GET    /v1/restaurants/nearby            ?lat&lng&radius&filters
GET    /v1/restaurants/{id}
GET    /v1/restaurants/{id}/menu
GET    /v1/restaurants/{id}/reviews

REVIEWS
POST   /v1/reviews
PATCH  /v1/reviews/{id}
DELETE /v1/reviews/{id}
POST   /v1/reviews/{id}/helpful

FRIDGE
GET    /v1/fridge
POST   /v1/fridge
PATCH  /v1/fridge/{id}
DELETE /v1/fridge/{id}
POST   /v1/fridge/bulk-add               from scan

MEAL PLAN
GET    /v1/meal-plan?week=YYYY-MM-DD
PUT    /v1/meal-plan
POST   /v1/meal-plan/generate            AI auto-plan
GET    /v1/meal-plan/grocery-list

GROUPS / VOTING
POST   /v1/groups                        create
POST   /v1/groups/{id}/members           join with code
POST   /v1/groups/{id}/polls             new poll
POST   /v1/groups/{id}/polls/{pid}/vote
GET    /v1/groups/{id}/polls/{pid}/result

SOCIAL
GET    /v1/feed?tab=for-you|following|nearby
POST   /v1/posts                         { type, media, caption, tags }
GET    /v1/posts/{id}
POST   /v1/posts/{id}/like
POST   /v1/posts/{id}/comment
GET    /v1/stories/feed

ORDERS (aggregator)
POST   /v1/orders/intent                 → deeplink to partner
GET    /v1/orders/me?status

SUBSCRIPTION
GET    /v1/subscription/plans
POST   /v1/subscription/checkout         { plan, provider }
POST   /v1/subscription/webhook/{provider} (server-to-server)

NOTIFICATIONS
GET    /v1/notifications
POST   /v1/notifications/read            { ids[] }
PUT    /v1/notifications/prefs

SEARCH
GET    /v1/search?q&type=all|foods|restaurants|users
POST   /v1/search/visual                 multipart image

GEO
GET    /v1/geo/reverse?lat&lng
GET    /v1/geo/weather?lat&lng           (proxied + cached)
```

### 4.4 GraphQL — example query

```graphql
query HomeFeed($cityCode: String!) {
  me {
    id
    displayName
    level
    streak { dailyDecide cookStreak }
  }
  aiSuggestions(mode: QUICK, limit: 5) {
    cards { id name image price reason actions }
    sessionId
  }
  trendingRestaurants(city: $cityCode, limit: 10) {
    edges { node { id name distance rating priceLevel images } }
  }
  friendsFeed(limit: 20) {
    edges { node { id type media user { id avatar } food { name } } }
  }
}
```

### 4.5 WebSocket events

```
ws://api.tothanhthuy.cloud/realtime

CLIENT → SERVER
- subscribe:group:{id}
- vote:poll {pollId, optionIdx}
- typing:group {groupId}

SERVER → CLIENT
- group.poll.updated     { pollId, tally }
- group.poll.closed      { pollId, winner }
- notification.new
- order.status.changed
- streak.bump
- ai.suggestion.ready    (async generation)
```

### 4.6 Rate limits
- 100 req/min per user (anonymous: 20/min)
- AI suggest endpoint: 10/min free user, unlimited premium
- Visual search: 30/day free, unlimited premium
- Token-bucket via Redis

---

## 5. AI Workflows

### 5.1 Food Recommendation Pipeline

```
┌─────────────────────────────────────────────────────────────┐
│  USER REQUEST  /v1/ai/suggest                                │
└────────────────────────────┬─────────────────────────────────┘
                             ↓
                ┌────────────────────────┐
                │ 1. CONTEXT ENRICHMENT  │
                │  - Weather API         │
                │  - Time of day         │
                │  - User history (last  │
                │    7 meals)            │
                │  - Active streaks      │
                │  - Calendar events     │
                └─────────┬──────────────┘
                          ↓
                ┌────────────────────────┐
                │ 2. CANDIDATE GENERATION│
                │  Sources:              │
                │  - Vector similarity   │
                │    (Pinecone)          │
                │  - Collaborative filt. │
                │    (two-tower model)   │
                │  - Trending feed       │
                │  - Constraint filter   │
                │    (allergies HARD)    │
                │  Output: ~200 items    │
                └─────────┬──────────────┘
                          ↓
                ┌────────────────────────┐
                │ 3. RANKING (LightGBM)  │
                │  Features (50+):       │
                │  - user-item dot prod  │
                │  - price match score   │
                │  - time match score    │
                │  - mood match          │
                │  - recency penalty     │
                │  - diversity bonus     │
                │  - weather affinity    │
                │  Output: top 30        │
                └─────────┬──────────────┘
                          ↓
                ┌────────────────────────┐
                │ 4. DIVERSITY SHUFFLE   │
                │  - Avoid >2 same       │
                │    cuisine in top 5    │
                │  - Mix price tiers     │
                │  - Mix actions         │
                │    (cook/order/dine)   │
                └─────────┬──────────────┘
                          ↓
                ┌────────────────────────┐
                │ 5. LLM EXPLANATION     │
                │  GPT-4o-mini call:     │
                │  Generate VN reason    │
                │  per top 5 in 1 batch  │
                │  (cost: ~$0.001/req)   │
                └─────────┬──────────────┘
                          ↓
                ┌────────────────────────┐
                │ 6. CONTEXT ATTACH      │
                │  - Restaurants nearby  │
                │  - Recipe link         │
                │  - TikTok videos       │
                │    (cached)            │
                └─────────┬──────────────┘
                          ↓
                ┌────────────────────────┐
                │ 7. CACHE & RESPOND     │
                │  - Cache 5min keyed by │
                │    (user, context hash)│
                │  - Log event for       │
                │    training            │
                └────────────────────────┘
```

**Latency budget:** p50 < 800ms, p95 < 1.8s.

### 5.2 LLM Prompt Flow (Suggestion Reason)

**System prompt:**
```
Bạn là Hà — trợ lý ẩm thực Việt Nam. Nói chuyện thân thiện như đứa bạn,
ngắn gọn (1 câu, ≤25 từ). Giải thích lý do gợi ý món dựa trên CONTEXT.
Không tâng bốc. Không xài Anh ngữ. Có thể dí dỏm nhưng không kệch cỡm.
```

**User prompt (templated):**
```
CONTEXT:
- Người dùng: tên={name}, thích={loves}, ghét={hates}, đang ăn kiêng={diet}
- Hiện tại: thời tiết={weather}, giờ={hour}, mood={mood}
- Ràng buộc: ngân sách={budget}đ, thời gian={time}phút

MÓN GỢI Ý:
- {food_name} ({cuisine}, {tags})

Viết 1 câu giải thích vì sao món này hợp.
```

**Example output:**
> "Trời mưa Hà Nội + đói cồn cào → tô bún bò ấm bụng đỡ ghê 🌧"

### 5.3 Fridge Vision Workflow

```
[Image upload] → S3 (intermediate)
       ↓
[YOLOv8 fine-tuned VN ingredients]
       ↓ bounding boxes + class
[Confidence filter ≥0.7]
       ↓
[SAM segment → portion estimation]
       ↓
[Map to ingredient master DB]
       ↓
[Return list with confidence]
       ↓ user confirms/edits
[Pass to recipe generator]
       ↓
[Hybrid: rule-based + LLM]
       ↓
[Top 5 recipes with completeness scores]
```

**Model:** YOLOv8-m fine-tuned on **HNAG-Food-50K** dataset (proprietary, growing).
**Classes:** 187 Vietnamese ingredients (rau muống, thịt ba chỉ, măng tươi...).
**Edge inference:** TFLite quantized model on device for offline scan (V2).

### 5.4 Voice Assistant Pipeline

```
[Mic capture, 16kHz mono] → Wake word detector (on-device)
         ↓
   ["Hey Hà" detected]
         ↓
[Stream chunks → Whisper large-v3 server]
         ↓ Vietnamese transcript
[VinBERT NLU → intent + entities]
         ↓
   Routes:
   - "suggest" → ai/suggest pipeline
   - "order" → order intent → partner deeplink
   - "navigate" → maps deeplink
   - "remind" → meal plan reminder
   - "general" → GPT-4o conversation
         ↓
[Response text] → VBee TTS Vietnamese → audio stream
         ↓
[Play + show transcript bubble]
```

**Personality dimensions:**
- Accent: Bắc / Trung / Nam (user pick)
- Tone: bạn thân (default) / lễ phép / dí dỏm

### 5.5 Embedding Strategy

**Item embeddings** (foods, restaurants):
- Concatenate: name + cuisine + tags + description
- Use `text-embedding-3-small` (1536-dim)
- Stored in Pinecone, refreshed weekly

**User embeddings:**
- Two-tower model trained on interactions
- Updated nightly
- Used for: "users like you" + cold-start (with food-DNA from onboarding)

### 5.6 Cold Start
- New user, no history → use food-DNA from onboarding + city-trending
- New food → use embedding similarity + manual editorial boost

### 5.7 AI Cost Optimization

| Strategy | Saving |
|----------|--------|
| Cache LLM responses per (user, context-hash) for 5min | 60% |
| Batch LLM calls (5 items at once) | 40% |
| GPT-4o-mini for explanations, GPT-4o for complex flows | 70% |
| Embedding cache (item embeddings only change weekly) | 95% |
| Self-host Whisper (vs OpenAI Whisper API) at scale | 50% |
| Edge inference for vision (V2) | 80% |

**Target unit cost:** < $0.018 per active user/day at 1M MAU.

---

## 6. Realtime System

### 6.1 Architecture
- Socket.io cluster behind ALB sticky sessions
- Redis pub/sub adapter for cross-node fanout
- Heartbeat 25s, reconnect with exponential backoff

### 6.2 Use cases
- Group voting (live tally)
- Order status updates
- Notification push
- Cooking timer co-watching ("My partner watching me cook")
- Live activity (iOS 16.1+)

### 6.3 Scaling
- Horizontal: sticky LB + Redis adapter
- Per pod: 10K concurrent connections
- Year 3 target: 50 pods → 500K concurrent

---

## 7. Admin Dashboard

Stack: Next.js + shadcn/ui + Recharts + tRPC.

### 7.1 Modules
- **Operations:** order monitoring, partner SLA, refunds
- **Content:** food catalog CRUD, restaurant verification, image moderation
- **AI Ops:** suggestion quality metrics, click-through, override rules
- **Users:** search, ban, refund, support tickets
- **Growth:** funnel, retention cohorts, A/B tests, referral graph
- **Finance:** GMV, take rate, subscription MRR/churn, partner payouts
- **Safety:** report queue, AI flags (spam reviews, fake images)

### 7.2 Permissions (RBAC)
- Super Admin / Ops / Content Moderator / BD / Finance / Read-only

### 7.3 Audit log
All admin actions logged to immutable table.

---

## 8. Security

### 8.1 Identity
- Phone OTP w/ rate limit (5/hour per phone, 100/day per IP)
- OTP TTL 5 min, single-use
- 2FA option (TOTP) for premium accounts
- Device binding via Firebase Installation ID
- Session revoke endpoint, logout-all-devices

### 8.2 Data protection
- TLS 1.3 everywhere
- DB encryption at rest (KMS)
- PII fields encrypted column-level (phone hash + ciphertext)
- Sensitive logs scrubbed (no phone/email in logs)
- VN PII compliance: locally-stored data option

### 8.3 API
- WAF (Cloudflare) + Bot Mgmt
- Schema validation (Zod) on every input
- Rate limit per user + per IP + global
- CSRF tokens for cookie-auth web

### 8.4 AI safety
- Prompt injection guard (system prompt vs. user-controlled fields separated)
- Output validation (no leakage of system prompts)
- Allergy = HARD constraint, never relaxed by AI
- Toxicity filter on user-generated content (Perspective API + custom VN classifier)

### 8.5 Privacy
- Default-private: location only used for recs, never shown publicly without consent
- Granular data permissions
- Right to download / delete (GDPR-ish — VN Decree 13)
- Data Processor Agreement with partners

### 8.6 Compliance
- VN Decree 13 (Personal Data Protection 2023)
- VN Cybersecurity Law (2018)
- PCI-DSS via Stripe/Momo (we don't store card)
- SOC 2 Type 1 (Year 2 target)

---

## 9. Scaling Architecture

### 9.1 Phase 1 — Launch (0–100K MAU)
- Single AWS region (Singapore)
- 1 PostgreSQL primary + 1 read replica
- MongoDB 3-node replica set
- Redis cluster 3 shards
- 6 API pods
- Cost: ~$8K/month infra

### 9.2 Phase 2 — Growth (100K–2M MAU)
- + AWS Hong Kong region (read replica + edge cache)
- DB read/write split, partitioning (events by user_id)
- MongoDB sharded
- ElasticCache Redis cluster mode
- 20+ API pods auto-scale
- ClickHouse for analytics warehouse
- Cost: ~$60K/month

### 9.3 Phase 3 — Scale (2M–10M MAU)
- Multi-region active-active
- Database sharding by city/region
- CDN-cached restaurant pages (ISR)
- Edge AI for fridge scan (Cloudflare Workers + WASM model)
- Cost: ~$280K/month → 14% of revenue

### 9.4 Database scaling tactics
- Hot/cold separation (events archived to S3 + ClickHouse after 90 days)
- Materialized views for leaderboards
- Connection pooling (PgBouncer)
- Vacuum/analyze automation

### 9.5 AI cost ceiling
- At 10M MAU, AI cost target ≤ 8% of revenue
- Mitigations: open-source model fine-tunes (Llama 3, Qwen) for non-critical paths

---

## 10. Observability & Reliability

### 10.1 SLOs

| Service | SLI | SLO (monthly) |
|---------|-----|---------------|
| API availability | 200 / total | 99.9% |
| AI suggest p95 | latency | < 1.8s |
| Order tracking | success | 99.5% |
| Push notif delivery | rate | 95% |

### 10.2 Monitoring
- Datadog APM (traces), Datadog Logs, Datadog RUM
- Custom dashboards per service + per business metric
- Synthetic checks (Datadog Synthetics) every 1 min from VN, SG, HK

### 10.3 Alerting
- PagerDuty integration
- Tiered: P0 (paged), P1 (Slack ping), P2 (ticket)
- Runbooks per alert

### 10.4 Incident management
- Postmortem within 48h
- Blameless culture, root cause + action items tracked
- Status page (status.tothanhthuy.cloud) auto-updated

---

## 11. CI/CD

```
Developer pushes → GitHub
        ↓
GitHub Actions:
  - Lint (eslint, dart format)
  - Type check (TS, Dart)
  - Unit tests (≥80% coverage gate)
  - E2E (Playwright + Detox)
  - Build artifacts (Docker, .ipa, .apk)
        ↓
ArgoCD GitOps deploy:
  - Dev → Staging → Canary 5% → Full
        ↓
Health checks + auto rollback (Argo Rollouts)
```

**Mobile release cadence:**
- Bi-weekly app store release
- OTA hotfix via Flutter shorebird (controversial — discuss)

---

## 12. Testing Strategy

| Layer | Type | Tool |
|-------|------|------|
| Unit | Pure logic | Jest, Dart test |
| Integration | API + DB | Vitest + Testcontainers |
| Contract | API ↔ client | Pact |
| E2E web | Browser | Playwright |
| E2E mobile | Device | Maestro / Detox |
| Load | API | k6 |
| Chaos | Pod kill | Litmus |
| AI eval | LLM responses | LangSmith + custom eval |

**Coverage target:** core ≥80%, AI prompts have golden set (200 examples reviewed weekly).

---

## 13. Data Pipeline

```
Mobile/Web → API → Kafka → ┬→ Postgres (live)
                          ├→ MongoDB
                          ├→ ClickHouse (analytics)
                          ├→ S3 (raw)
                          └→ ML Feature Store (Feast)

ClickHouse → dbt → Metabase/Looker
S3 raw → Airflow → ML training pipelines → MLflow → BentoML serving
```

---

## 14. Internationalization (Future)

- All strings via i18next (web) + intl (Flutter)
- Right-to-left tested (not needed for VN, but Arabic/Hebrew for SEA later)
- Currency localization (multi-currency Phase 4)
- Locale-aware date/time
- AI prompts auto-translated + reviewed

---

## 15. Open Questions & Decisions Log

| Question | Decision | Date |
|----------|----------|------|
| Flutter vs RN? | Flutter — better motion, single codebase | 2026-Q2 |
| Own AI vs API? | Hybrid — GPT-4o for LLM, own vision | 2026-Q2 |
| GraphQL or REST? | Both; REST first, GraphQL for complex social | 2026-Q3 |
| Mongo vs all-Postgres? | Mongo for social feed (write-heavy) | 2026-Q3 |
| Edge AI vs cloud? | Cloud V1, edge for fridge V2 | 2027-Q1 |

---
