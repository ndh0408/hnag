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
| Auth | `modules/auth` | Phone OTP, JWT, refresh tokens |
| Users | `modules/users` | Profile, follows |
| AI | `modules/ai` | Suggest, feedback, mood, viral-link |
| Foods | `modules/foods` | Food catalog |
| Restaurants | `modules/restaurants` | Nearby, detail, menu, claims |
| Groups | `modules/groups` | Group voting (with realtime) |
| Orders | `modules/orders` | Delivery aggregator intent |
| Notifications | `modules/notifications` | Push + center |
| Realtime | `modules/realtime` | Socket.io gateway |
| Subscriptions | `modules/subscriptions` | HNAG+ checkout |
| Health | `modules/health` | DB + Redis liveness |

## Architecture highlights

- **Envelope interceptor** wraps all REST responses in `{ success, data, error, meta }`
- **Zod pipes** for runtime validation at the API boundary
- **Throttler** global 100 rpm; per-route overrides (auth: 5/min, AI: 30/min)
- **Redis Socket.io adapter** for cross-pod realtime fanout
- **Prisma** as ORM, with raw SQL for PostGIS spatial queries
- **OpenAI** integration via the `LlmReasonService` (batched + cached)
- **GraphQL admin endpoint** at `/graphql` using `code/graphql/admin_schema.graphql`

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
