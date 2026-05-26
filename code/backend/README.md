# HNAG Backend (NestJS)

Production-ready scaffolding cho HNAG API — Node.js 20, NestJS 10, PostgreSQL + PostGIS, Redis, Socket.io, Prisma.

## Quick start

```bash
cp .env.example .env
docker-compose up -d postgres redis      # see ../infra/docker-compose.yml
npm install
npx prisma migrate dev                    # or: psql -f ../sql/01_schema.sql
npx prisma db seed                        # or: psql -f ../sql/02_seed_data.sql
npm run start:dev
```

API: http://localhost:4000/v1
Swagger: http://localhost:4000/docs
GraphQL: http://localhost:4000/graphql
Health: http://localhost:4000/health

## Module map

| Module | Path | Responsibility |
|--------|------|----------------|
| Auth | `modules/auth` | Email OTP, Phone OTP, Apple SSO, JWT, refresh tokens |
| Users | `modules/users` | Profile, saves, follows, preferences |
| AI | `modules/ai` | Suggest (public + authed), feedback, mood, fridge-recipes |
| Foods | `modules/foods` | Catalog + trending + detail + restaurants-serving |
| Restaurants | `modules/restaurants` | Nearby (PostGIS), detail, menu, **reviews** |
| Posts | `modules/posts` | TikTok feed, like, **comments (hydrated author)**, stories |
| Groups | `modules/groups` | Group voting + realtime WS (`group.poll.updated`) |
| Orders | `modules/orders` | Partner deeplink intent, history, **status updates with WS broadcast** |
| Couple | `modules/couple` | Invite, accept, shared taste, memory book |
| Challenges | `modules/challenges` | Quests, achievements, leaderboard |
| Notifications | `modules/notifications` | Push + center + preferences |
| Realtime | `modules/realtime` | Socket.io gateway (JWT auth + room helpers) |
| Subscription | `modules/subscription` | HNAG+ checkout (VietQR / promo / SePay webhook with HMAC) |
| Meal | `modules/meal` | Weekly meal plan + grocery export |
| Boost | `modules/boost` | Restaurant boost campaigns |
| Health | `modules/health` | DB + Redis liveness |

## Architecture highlights

- **Envelope interceptor** wraps all REST responses in `{ success, data, error, meta }`
- **Zod pipes** for runtime validation at the API boundary
- **Throttler** global 100 rpm; per-route overrides (auth: 5/min, AI: 30/min)
- **Redis Socket.io adapter** for cross-pod realtime fanout
- **Prisma** as ORM, with raw SQL for PostGIS spatial queries
- **OpenAI** integration via the `LlmReasonService` (batched + cached)
- **GraphQL admin endpoint** at `/graphql` using `code/graphql/admin_schema.graphql`

## Security hardening (2026-05 audit)

| Issue | Status |
|---|---|
| OTP `devCode` leak in response body | **FIXED** — `sendEmail/sendPhone` returns `{}` always, code logged server-side only |
| Brute-force OTP | **FIXED** — 5 attempts/code lock; 5 sends/hour rate limit per email |
| SePay payment webhook forgery | **FIXED** — mandatory `SEPAY_WEBHOOK_TOKEN`, memo matching is subscription-id UUID prefix (collision-proof), amount exact-or-overpay only |
| Refresh-token reuse | **FIXED** — reuse detection revokes whole chain |
| Apple SSO signature verification | ⚠️ Partial — JWT decode only; signature verify against `appleid.apple.com/auth/keys` is next iter |
| Partner webhook handlers (Shopee/Grab/Baemin status updates) | ⚠️ Missing — currently `/v1/orders/:id/status` is dev/QA-only (JWT-guarded, owner-only) |

## Real-data seed (`prisma/seed-social.sql`)

Idempotent. Inserts 8 real `posts` referencing real `foods` + `users`, 6 food `reviews`, 6 restaurant `reviews` — so TikTok feed, comments, Profile Reviews, Restaurant Reviews tabs all show real data. Tagged with `'seeded'` for safe re-run.

```bash
docker exec hnag-postgres psql -U hnag -d hnag -f /tmp/seed-social.sql
```

## AI Suggestion Pipeline

```
/v1/ai/suggest
  → ContextBuilderService (weather, time, prefs, history)
  → CandidateGeneratorService (200 candidates)
  → MoodEngineService (optional bias)
  → RankerService (LightGBM-substitute heuristic, 50+ features)
  → diversify (MMR-lite)
  → LlmReasonService (batched GPT-4o-mini, cached)
  → response + persist ai_sessions row
```

p95 target: < 1.4s.

## Tests

```bash
npm test           # unit
npm run test:e2e   # integration (requires test DB)
```

## Deploy

See `ci/.github/workflows/backend.yml` and `infra/k8s/`.
