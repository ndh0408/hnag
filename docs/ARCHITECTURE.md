# HNAG — Architecture

> One-page mental model of the system. Pair with [99-PRODUCTION-READINESS.md](99-PRODUCTION-READINESS.md)
> for the active work tracker.

## High-level shape

```
                   Flutter app          web-marketing         owner-dashboard
                   (Android / iOS)      (Next.js, marketing)  (Next.js, owners)
                          │                    │                      │
                          ▼                    │                      │
                  https://api.tothanhthuy.cloud (Cloudflare Tunnel)
                          │
                          ▼
                   nginx (only on bare-prod path; tunnel can also point direct)
                          │
                  ┌──────────────────────┐
                  │  hnag-backend (×2)   │  ─── horizontal slots, Docker DNS RR
                  │  NestJS monolith     │
                  │  - REST /v1/**       │
                  │  - GraphQL /graphql  │  (admin-only)
                  │  - WebSocket         │  (Redis-adapter fan-out)
                  │  - /health           │
                  │  - /metrics          │  (Prometheus scrape)
                  │  - /admin/**         │  (RBAC + audit-log)
                  └──────────────────────┘
                          │           │
                          ▼           ▼
                  ┌─────────┐    ┌──────────┐
                  │ Redis   │    │PgBouncer │ → Postgres (PostGIS)
                  │ (cache, │    │ (txn pool│
                  │  queues,│    │  1000×30)│
                  │  AOF)   │    └──────────┘
                  └─────────┘
                          │
                          ▼
                  BullMQ workers (in-process, drained from queues)
                  - otp:email     (offload SMTP)
                  - push:fcm      (offload FCM dispatch)
                  - (planned) ai:gen, analytics:ingest, ranking:recompute
```

## Modules (NestJS backend)

| Module | Purpose | Public surface |
|--------|---------|----------------|
| **auth** | OTP (email/phone), Apple SSO, JWT issue + refresh rotation | POST /v1/auth/* |
| **users** | Profile, follow, saves, streak, account deletion | /v1/users/me + /v1/users/:id |
| **restaurants** | Public listing, owner-CRUD, claim flow | /v1/restaurants/** + /v1/owner/** + /v1/claims/** |
| **foods** | Catalog, trending, detail | /v1/foods/** |
| **ai** | Suggest, mood, voice, fridge-scan, feedback | /v1/ai/** (+ /v1/ai-public/**) |
| **orders** | Order intent + status webhook | /v1/orders/** |
| **subscriptions** | VietQR / SePay / promo activation | /v1/subscription/** |
| **groups** | Group voting + polls + members | /v1/groups/** |
| **couple** | Couple mode pairing | /v1/couple/** |
| **posts** | Social feed, comments, stories | /v1/feed + /v1/posts/** |
| **realtime** | Socket.IO gateway (group + restaurant + user rooms) | WebSocket /socket.io |
| **notifications** | In-app + FCM push (queued) | /v1/notifications/** |
| **challenges** | Quests, achievements, leaderboard (materialized view) | /v1/challenges/** |
| **boost** | Owner promo campaigns | /v1/boost/** |
| **meal** | Meal planner | /v1/meal/** |
| **health** | /health (operator monitor) + /metrics (Prometheus scrape) | /health, /metrics |
| **admin** | GraphQL admin schema + observability REST | /graphql, /admin/** |

## Cross-cutting layers (`common/`)

- **prisma** — typed DB client with slow-query middleware (>200ms WARN, >2s ERROR).
- **redis** — IORedis singleton, also drives BullMQ queues + Socket.IO adapter.
- **analytics** — `@Global()` `AnalyticsService` — `track(event)` fire-and-forget into `analytics_events`.
- **config/feature-flags** — `@Global()` `FeatureFlagsService` — Redis → env → default; per-user bucket helper.
- **config/logger** — pino + pino-http, request-id propagation, scrubbing list.
- **config/sentry** — lazy-require Sentry init (fail-open).
- **guards** — `@Premium()` (server-side gate), `@Roles(...)` (RBAC), `@AiCooldown(ms)` (debounce).
- **interceptors** — `@Audit({event, level})` (audit-log to analytics + structured warn).
- **queues** — BullMQ module + workers (otp:email, push:fcm).
- **adapters** — Redis Socket.IO adapter.
- **filters / pipes** — global exception filter, zod validation pipe, validation pipe.
- **decorators** — `@CurrentUser`, `@Roles`, etc.

## Authorization model

| Layer | Mechanism | When |
|-------|-----------|------|
| JWT | `AuthGuard('jwt')` | every `/v1/**` except auth + restaurants public lists |
| Premium | `@Premium()` re-reads `users.is_premium` + `premium_until` | paid features (voice, group voting unlimited) |
| RBAC | `@Roles('admin', 'super_admin')` reads `users.role` live | admin/owner/billing endpoints |
| Ownership | `OwnerService.assertOwner` queries `restaurant_claims` (status=approved) | every /v1/owner/restaurants/:id/** |
| Webhook auth | bearer token + HMAC-SHA256(rawBody) | /v1/subscription/webhook/sepay |
| WebSocket | JWT in handshake.auth.token; UUID + membership re-check per subscribe | every `subscribe:*` event |

## Data flow — `POST /v1/ai/suggest`

```
client ──► AuthGuard ──► AiCooldownGuard (2s/user) ──► ThrottlerGuard (30/min/IP)
   │                                                              │
   ▼                                                              ▼
ai.controller.suggest() ──► orchestrator.suggest(req)
                              │
                              ├─ Free quota check  → 402 if exceeded
                              ├─ Redis cache       → hit returns immediately
                              ├─ ContextBuilder    → enrich weather/hour/mood
                              ├─ Candidate gen     → 50 pool from DB + embeddings
                              ├─ Mood bias         → tag-based reorder
                              ├─ Ranker            → weighted score INCLUDING
                              │                     skip-memory penalty
                              ├─ consumeLlmBudget  → per-user daily cap
                              │                     (Redis counter)
                              ├─ LlmReason.select  → ModelRouter.pick → gpt-4o-mini/gpt-4o
                              │                     PromptRegistry.get('reason.select')
                              │                     costTracker.add(usage.tokens × prices)
                              ├─ Diversify         → MMR-lite, cuisine/category caps
                              ├─ LlmReason.batch   → fill missing captions (cached)
                              ├─ Build cards       → analytics.track('ai:suggest')
                              ├─ Write ai_sessions → llm_cost_usd populated
                              └─ Bump redis spend  → ai:spend:<userId>:<YYYY-MM-DD>
                              ▼
                          { sessionId, cards[], reasonCodes[] }
```

## Persistence map (high-traffic tables)

| Table | What it holds | Hot index |
|-------|---------------|-----------|
| `users` | profile + role + premium flags | (status, email) |
| `restaurants` | 14k OSM scrape + curated | `GIST(location)` partial, `(city, status)` |
| `menu_items` | per-restaurant dishes | `(restaurant_id, position)` |
| `foods` | 86 curated VN dishes | `(slug)`, `(trending_score DESC)` |
| `food_interactions` | every swipe/save/order | `(user_id, action, created_at DESC)` |
| `ai_sessions` | every suggest call | `(user_id, created_at DESC)` + `llm_cost_usd` |
| `orders` | intent → status lifecycle | `(user_id, placed_at DESC)`, `(restaurant_id, status)` |
| `subscriptions` | premium activations | `(provider, status, created_at DESC)` |
| `payment_events` | webhook idempotency | `UNIQUE(provider, external_txn_id)` |
| `follows` | social graph | `(follower_id, created_at)`, `(followee_id)` |
| `analytics_events` | product analytics fire-hose | `(event, occurred_at DESC)`, `(user_id, occurred_at DESC)` |
| `audit_*` | account_deletions, payment_events, ... | varies |
| `leaderboard_weekly` / `_monthly` | materialized views, refreshed every 5 min | `UNIQUE(id)` (for CONCURRENTLY refresh) |

## Architectural rules (enforced via dependency-cruiser CI gate)

1. **Modules talk only via their `*.module.ts` public surface.** No reaching into another module's `services/` or `controllers/`.
2. **No circular deps anywhere.** If A → B → A, pull the shared bit into `common/`.
3. **No test code in prod paths.** `*.spec.ts` and `test/` are imports-prohibited from `src/**` non-spec files.
4. **Domain modules never import infrastructure adapters directly.** Use the injected service.
5. **Cross-cutting concerns live in `@Global()` modules** (analytics, feature-flags) — no per-module imports needed.

Violation = CI fail. See `code/backend/.dependency-cruiser.cjs`.

## Where things go when you add a feature

| You're adding... | Land it under |
|------------------|---------------|
| A new REST route | `src/modules/<domain>/<domain>.controller.ts` |
| A new background job | new BullMQ queue in `src/common/queues/queues.module.ts` + processor |
| A new admin tool | `src/admin/<name>.controller.ts` (or `.resolver.ts` for GraphQL) |
| A new analytics event | call `analytics.track({event: '<domain>:<action>', ...})` — no new file needed |
| A new prompt | append to `src/modules/ai/prompts/prompt-registry.service.ts` with a fresh `version` |
| A new role-gated endpoint | `@Roles('admin', 'moderator')` on the handler — no new guard needed |
| A new audit-worthy admin action | add `@Audit({event: 'admin.<X>', level: 'critical'})` |
| A new env var | document in `code/infra/server/hnag.env.example` AND `hnag.staging.env.example` |
| A new SQL migration | new `code/sql/NN_<name>.sql` AND mirror as Prisma model in `prisma/schema.prisma`; run bootstrap migration script on prod (see `99-PRODUCTION-READINESS.md §7`) |

## Frontend (Flutter)

- **State:** mostly `setState` + `StreamBuilder`; Riverpod is installed but only used at the root `ProviderScope`. Cart state persists via `flutter_secure_storage` (`CartStore`).
- **API:** `HnagApi` (lib/api/hnag_api.dart) with `ResilientClient` for retries + circuit-breaker. Auth via `AuthService` (lib/api/auth_service.dart) with single-flight refresh.
- **Errors:** `ApiException` carries vi-VN messages — UIs do `_error = e.toString()` and surface user-safe copy.
- **Crash reporting:** `CrashReporter` (lib/observability/crash_reporter.dart) — wires Sentry when `sentry_flutter` dep is added.
- **Deep linking:** Android intent-filter on `hnag://` + `https://tothanhthuy.cloud/{r,f,c}/<id>` (App Links).  iOS pending Universal Links file deploy.
- **Design system:** v1 (legacy) + v2 (Hi-Fi). v2 main-flow cut-over still pending UX review — see `99-PRODUCTION-READINESS.md §3 Week 4`.

## Where to learn more

- Live work tracker: [99-PRODUCTION-READINESS.md](99-PRODUCTION-READINESS.md)
- Audit prompts (reusable for fresh reviews): [../scripts/audit-prompts.md](../scripts/audit-prompts.md)
- Per-feature docs: `01-PRODUCT.md` … `13-RESTAURANT-CLAIM.md`
- Deploy commands: [99-PRODUCTION-READINESS.md §7](99-PRODUCTION-READINESS.md)
- Contributing: [CONTRIBUTING.md](../CONTRIBUTING.md)
