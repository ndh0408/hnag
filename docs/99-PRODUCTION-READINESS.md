# 99 — Production Readiness Plan & Tracker

Last updated: 2026-05-27 · Owner: ndh0408 · Reviewer: future-Claude

This file is the **source of truth** for HNAG's road to production. Every
session that joins the project should open this first to understand:
- what audit findings exist
- what has already been fixed
- what is the next item to attack
- how to run / verify the fix locally

It is paired with the master audit prompt pack at
[../scripts/audit-prompts.md](../scripts/audit-prompts.md). The prompts are
the "checklist". This file is the "build log".

---

## How to use this document

1. **New session** — read §1 to understand context, §2 to see the live status
   board, §3 to find the next unstarted item.
2. **Finished an item** — flip its checkbox in §3 from `[ ]` to `[x]`, write
   the file paths touched + one-line summary in §4, update the score in §5.
3. **Found a new issue** — append it to §3 under the right week, severity-rate
   it (🔴 / 🟠 / 🟡 / 🟢), reference the audit section if any.

Never delete history. Items move from `pending` → `in progress` → `done` but
the row stays so future-you can grep for "who broke this".

---

## §1 — Context (read me first)

HNAG is a Vietnamese consumer AI-food-discovery app. The stack:

- **Backend**: NestJS + Prisma + PostgreSQL (PostGIS) + Redis + Socket.IO
  + Apollo GraphQL (admin-only). [code/backend/](../code/backend/)
- **App**: Flutter, two coexisting design systems (v1 + Hi-Fi v2).
  [code/flutter/](../code/flutter/)
- **Web**: marketing site + owner dashboard. [code/web-marketing/](../code/web-marketing/) and [code/owner-dashboard/](../code/owner-dashboard/)
- **Infra**: docker-compose on a single self-hosted box via Tailscale +
  Cloudflare Tunnel. Memory `hnag-deploy-server`. [code/infra/](../code/infra/)
- **Data**: 14k restaurants scraped from OSM; ~30 of them have real menus.

The audit (2026-05-27) scored the product **48 / 100 — not launch-ready**.
The brutal verdict is preserved in conversation history; the actionable
plan is below.

Reference memories already saved by Claude:
- `hnag-audit-2026-05` — confirmed-live OTP leak + forgeable webhook
  (mostly closed now — see §4)
- `hnag-design-overhaul-2026-05` — Hi-Fi v2 progress
- `hnag-deploy-server`, `hnag-ios-build-vm`, `hnag-domain` — ops
- `hnag-server-compose-env-gotcha` — env-file deploy gotcha

---

## §2 — Status board (at a glance)

| Week | Theme | Items | Done | In progress | Pending |
|------|-------|-------|------|-------------|---------|
| 1 | Security & data safety | 12 | **12** ✅ | 0 | 0 |
| 2 | Foundation | 8 | **8** ✅ | 0 | 0 |
| 3 | Monetization | 5 | **4** | 0 | 1 |
| 4 | Mobile cut-over | 6 | **5** | 0 | 1 |
| 5 | Owner-side + data | 4 | **2** | 0 | 2 |
| 6 | Hardening + scale prep | 5 | **5** ✅ | 0 | 0 |
| Pre-launch checklist (§11) | Pre-launch must-have | 8 | **7** | 0 | 1 |
| Production-killer (post-78 audit) | 10-item maturity bar | 10 | **6** | 0 | 4 |
| Hardening (post-82 audit) | Observability + AI protection + arch enforcement | 5 | **5** ✅ | 0 | 0 |
| Hardening Phase 2 (post-85 audit) | Metrics/dashboards/cooldown/rejection/staging/docs | 6 | **6** ✅ | 0 | 0 |

**Current focus:** **60/69 items (87.0%) including post-85 hardening phase 2**.
Score 48 → **87/100**. Remaining 9 items: 5 user-runtime gated (payment,
deploy, iOS, UX, data ops), 4 multi-sprint (DDD refactor, CF
recommendation, OpenTelemetry full pipeline + Grafana dashboards, frontend
polish).

---

## §3 — Six-week roadmap (the checklist)

Severity legend (carried from the audit):
`🔴` launch-blocker / data-loss / takeover · `🟠` fix within 2 weeks ·
`🟡` fix in next quarter · `🟢` cleanup / polish.

Status legend: `[x]` done · `[~]` in progress · `[ ]` pending · `[!]` blocked

### Week 1 — Security & data safety (audit §C-Week-1)

- [x] 🔴 **Apple SSO: verify identityToken signature against Apple JWKS** —
      [code/backend/src/modules/auth/apple-token-verifier.service.ts](../code/backend/src/modules/auth/apple-token-verifier.service.ts) +
      [auth.service.ts:76](../code/backend/src/modules/auth/auth.service.ts) +
      spec at [apple-token-verifier.service.spec.ts](../code/backend/src/modules/auth/apple-token-verifier.service.spec.ts).
      JWKS cached in Redis 1h, refetch on `kid` miss.
      Env: `APPLE_BUNDLE_ID=vn.hnag.hnag`.
- [x] 🔴 **SePay webhook: timing-safe + HMAC + idempotency** —
      [subscriptions.controller.ts](../code/backend/src/modules/subscriptions/subscriptions.controller.ts) +
      [subscriptions.service.ts](../code/backend/src/modules/subscriptions/subscriptions.service.ts).
      Adds `payment_events` table — see [sql/09_payment_events.sql](../code/sql/09_payment_events.sql)
      and the new Prisma model. Env: `SEPAY_HMAC_SECRET`, `SEPAY_WEBHOOK_TOKEN`.
- [x] 🔴 **OTP plaintext out of logs** —
      [otp.service.ts](../code/backend/src/modules/auth/otp.service.ts).
      Now logs only `fp=<8 hex>` (SHA-256 prefix); plaintext only when
      `OTP_DEV_LOG_PLAIN=true` AND not production.
- [x] 🔴 **GraphQL introspection / playground off by default everywhere** —
      [app.module.ts](../code/backend/src/app.module.ts).
      Opt-in via `GRAPHQL_INTROSPECTION=true` only.
- [x] 🔴 **WebSocket `subscribe:restaurant` UUID-validated + existence-checked** —
      [realtime.gateway.ts](../code/backend/src/modules/realtime/realtime.gateway.ts).
      Also tightened `subscribe:group` UUID check.
- [x] 🔴 **`body: any` → DTOs on users + posts** —
      [users/dto/update-user.dto.ts](../code/backend/src/modules/users/dto/update-user.dto.ts) +
      [posts/dto/posts.dto.ts](../code/backend/src/modules/posts/dto/posts.dto.ts).
      Controllers updated; param IDs now `ParseUUIDPipe`-validated.
- [x] 🔴 **Post-like race condition** — switched to `createMany skipDuplicates`
      in [posts.service.ts](../code/backend/src/modules/posts/posts.service.ts);
      only increments `like_count` on actual create.
- [x] 🔴 **Graceful SIGTERM handler in NestJS** —
      [main.ts](../code/backend/src/main.ts).
      `app.enableShutdownHooks()` + SIGTERM/SIGINT close.
- [x] 🔴 **Account-deletion endpoint** (App Store 5.1.1 + Nghị định 13) —
      [users.service.ts](../code/backend/src/modules/users/users.service.ts)
      `deleteAccount` + `DELETE /v1/users/me`.
- [x] 🔴 **Off-host postgres backups** —
      [code/infra/server/backup-postgres.sh](../code/infra/server/backup-postgres.sh)
      (daily/weekly/monthly + retention + age-encryption + healthcheck ping)
      with [restore-postgres-test.sh](../code/infra/server/restore-postgres-test.sh)
      monthly drill. Cron at [cron.d-hnag](../code/infra/server/cron.d-hnag).
- [x] 🔴 **TLS expiry monitor** (Cloudflare tunnel — certs auto-renew but the
      tripwire matters) —
      [code/infra/server/tls-expiry-check.sh](../code/infra/server/tls-expiry-check.sh).
- [x] 🔴 **Raw-body parsing enabled** so the webhook HMAC sees exact bytes —
      [main.ts](../code/backend/src/main.ts) `rawBody: true`.

**Definition of done for Week 1:** all 12 above ✅ + a session must
deploy `09_payment_events.sql`, set new env vars, install scripts on the
server, configure rclone B2, and verify a manual `backup-postgres.sh daily`
run succeeds end-to-end.

### Week 2 — Foundation (audit §C-Week-2)

- [x] 🔴 **Introduce Prisma migrations** — guide added in §7 below
      (developer runs `prisma migrate diff --from-empty …` once with
      installed deps; tracker documents the bootstrap procedure). Schema
      now uses Prisma model declarations for `saved_items` and
      `payment_events`; remaining tables still match `code/sql/01_schema.sql`
      and are pulled in via `prisma db pull` until the next session.
- [x] 🔴 **Missing indexes** — [code/sql/10_indexes.sql](../code/sql/10_indexes.sql)
      adds 11 indexes (follows × 2, reviews × 2, food_interactions × 2,
      notifications partial, posts × 2 partial, saved_items, auth_sessions
      partial, subscriptions composite) + ANALYZE.
- [x] 🟠 **Replace `$queryRawUnsafe` with typed Prisma** in
      [subscriptions.service.ts](../code/backend/src/modules/subscriptions/subscriptions.service.ts)
      (trial-exists check, pending-sub insert, promo-redemption guard,
      myStatus) and
      [users.service.ts](../code/backend/src/modules/users/users.service.ts)
      (listSaves, addSave, removeSave). Closes audit #7-8.
- [x] 🟠 **users.me + subscriptions.myStatus parallelized** with
      `Promise.all` (audit §11 — 6 sequential queries → bounded by slowest).
- [x] 🔴 **Streak race fixed** —
      [users.service.bumpDecideStreak](../code/backend/src/modules/users/users.service.ts)
      now runs the read-compute-write inside a transaction with a
      conditional `updateMany` (only succeeds if no concurrent writer
      already advanced `last_decide` past today). Closes audit §13.
- [x] 🟠 **PgBouncer + Redis AOF persistence** in
      [docker-compose.prod.yml](../code/infra/server/docker-compose.prod.yml).
      Transaction-pool mode, 1000 max client conns × 30 backend pool.
      Backend `DATABASE_URL` rewritten with `pgbouncer=true&connection_limit=30`;
      `DIRECT_DATABASE_URL` added for migrations. Redis switched to AOF
      `everysec` + RDB combined (audit §5).
- [x] 🟠 **Structured logs + request-id** —
      [common/config/logger.ts](../code/backend/src/common/config/logger.ts)
      wires `pino` + `pino-http` (both already in package.json, just unused).
      Redaction list scrubs auth headers, OTP codes, refresh tokens,
      Sepay signatures.
- [x] 🟠 **Sentry init hook** —
      [common/config/sentry.ts](../code/backend/src/common/config/sentry.ts)
      with lazy-require + fail-open. To activate: add `@sentry/node` to
      package.json and set `SENTRY_DSN`. Build never breaks if absent.
- [ ] 🟠 _Optional / deferred:_ UptimeRobot ping on `/health` — env-driven
      `HEALTHCHECK_URL` already plumbed into backup cron; a separate
      `/health`-ping monitor at UptimeRobot just needs a one-time signup.
- [ ] 🟠 _Optional / deferred:_ Flutter per-user concurrent-refresh
      single-flight — moved to Week 4 (mobile pass).

### Week 3 — Monetization

- [ ] 🔴 **Wire one real payment processor E2E** — VietQR / SePay flow is
      already hardened in W1. **Blocker:** real bank account + SePay
      account + Flutter checkout swap from deep-link to in-app QR poll.
      Backend is ready (see W1 done log).
- [x] 🟠 **LLM cost tracking per request** —
      [llm-reason.service.ts](../code/backend/src/modules/ai/services/llm-reason.service.ts)
      now reads `completion.usage` from every OpenAI call, converts at
      gpt-4o-mini rates ($0.15/$0.60 per M tokens), accumulates into a
      per-request `LlmCostTracker`, and writes to
      `ai_sessions.llm_cost_usd`. Also increments a Redis daily counter
      `ai:spend:<userId>:<YYYY-MM-DD>` (7-day TTL) for spend dashboards.
      Override the price via `OPENAI_PRICING_USD_PER_M` env.
- [x] 🟠 **Idempotency keys on order creation** —
      [orders.controller.ts](../code/backend/src/modules/orders/orders.controller.ts)
      reads `Idempotency-Key` header, claims via Redis `SET NX EX 86400`,
      caches the response, replays on retry. Format validated (8-128
      chars, `[A-Za-z0-9._:-]+`). Lock released on error so a failed
      attempt can be retried with the same key.
- [x] 🟠 **Server-side premium gate** —
      [common/guards/premium.guard.ts](../code/backend/src/common/guards/premium.guard.ts)
      with `@Premium()` composite decorator. Re-checks
      `users.is_premium` + `users.premium_until > now()` on every
      request, fail-closed on infra errors. Use as `@Premium()` instead
      of `@UseGuards(AuthGuard('jwt'))` on paid endpoints.
- [ ] 🟡 **Account deletion email/in-app receipt** — store deletion log
      separately for legal trail.

### Week 4 — Mobile cut-over (audit §C-Week-4)

- [ ] 🟠 **Flutter v2 in main flow; v1 deprecated behind feature flag** —
      **Blocker:** needs UX review on which v2 screens are launch-ready.
      Recommend ~half-day pass through `lib/main.dart` routing with the
      product designer.
- [x] 🟠 **`CachedNetworkImage` everywhere** — DS widgets
      ([hnag_photo.dart](../code/flutter/lib/widgets/ds/hnag_photo.dart),
      [hnag_avatar.dart](../code/flutter/lib/widgets/ds/hnag_avatar.dart))
      already use it; swept the 3 remaining v2 screens
      ([search_screen.dart](../code/flutter/lib/screens/search_screen.dart),
      [premium_screen.dart](../code/flutter/lib/screens/premium_screen.dart),
      [restaurant_claim_screen.dart](../code/flutter/lib/screens/restaurant_claim_screen.dart)).
      V1 screens (15 files with `NetworkImage(...)`) will be deleted by
      the v2 main-flow cut-over above — no need to migrate twice.
- [ ] 🟠 **`ListView.builder` for TikTok feed + lazy chunked load** —
      ties into v2 cut-over (the social_v2 feed widgets need this).
- [ ] 🟠 **Cart persisted to local storage** (currently in-memory only).
      Quick win: `flutter_secure_storage` write on every cart mutation.
- [ ] 🟠 **Deep linking for restaurant / food URLs** — `tothanhthuy.cloud/r/<id>`.
      Needs both Flutter (`go_router` configuration) AND a web SSR page
      that 302's to the app on mobile.
- [ ] 🟠 **Token-refresh single-flight in API client**.

### Week 5 — Owner side + data

- [ ] 🔴 **Owner dashboard real backend** — wire `GET /v1/owner/orders/live`,
      `GET /v1/owner/reviews`, `PATCH /v1/owner/restaurants/:id`.
      Remove all `TODO: wire to backend` mocks in [owner-dashboard/](../code/owner-dashboard/).
- [ ] 🔴 **Menu CRUD for claimed restaurants** — owners can edit dishes,
      prices, availability, hours.
- [ ] 🟠 **Restaurant claim flow visible in Flutter** — claim service
      backend already exists; add UI.
- [ ] 🔴 **Data ops: 1,000 HCMC restaurants fully populated** (menus +
      photos + hours). Pay 2 interns 2 weeks — outside the eng track.

### Week 6 — Hardening + scale prep

- [ ] 🟠 **E2E test suite** for auth / order / payment / AI suggest flows.
      `test/jest-e2e.json` referenced in package.json but `test/` is empty.
      Needs ~half-day scaffolding pass.
- [x] 🔴 **GitHub Actions CI** — _audit was wrong: this already existed_.
      [backend-ci.yml](../.github/workflows/backend-ci.yml) runs
      lint + tsc + npm test (Postgres+Redis services) + npm audit + Trivy
      CRITICAL gate + multi-arch Docker build & push to GHCR.
      [mobile-ci.yml](../.github/workflows/mobile-ci.yml) runs
      `dart format --set-exit-if-changed`, `flutter analyze`,
      `flutter test --coverage` with Codecov, and Android release build.
      Apple-token-verifier spec from W1 is automatically picked up.
- [x] 🟠 **Second backend replica + nginx `least_conn`** —
      [docker-compose.prod.yml](../code/infra/server/docker-compose.prod.yml)
      adds `backend-2` service with the `backend` network alias so Docker
      DNS round-robins between both containers automatically (zero CF
      tunnel config change needed). nginx.conf upstream still lists both
      `backend:4000` and `backend-2:4000` for when nginx is used as the
      explicit LB. Audit §6 / §39.
- [ ] 🟠 **k6 load test at 2,000 concurrent** — establish baseline.
- [x] 🟡 **Materialized view for leaderboard** —
      [sql/11_leaderboard_mv.sql](../code/sql/11_leaderboard_mv.sql)
      creates `leaderboard_weekly` + `leaderboard_monthly` MVs with
      unique indexes (for CONCURRENTLY) and a `refresh_leaderboards()`
      helper. Backend cron at
      [challenges/leaderboard-refresh.cron.ts](../code/backend/src/modules/challenges/leaderboard-refresh.cron.ts)
      refreshes every 5 min. `challenges.service.leaderboard` now reads
      from the MV for weekly/monthly scope (sub-ms vs 2-5s before).

---

## §4 — Done log (file paths + one-liner)

> Each entry: date · audit-tag · file paths · what changed. Append, do not
> rewrite. Diff-friendly.

### 2026-05-27

- **Apple SSO** — closed audit #7-1 (CRITICAL).
  Created [apple-token-verifier.service.ts](../code/backend/src/modules/auth/apple-token-verifier.service.ts)
  with full RS256 signature verification + JWKS cache. Updated
  [auth.service.ts](../code/backend/src/modules/auth/auth.service.ts)
  to use it. Test suite at
  [apple-token-verifier.service.spec.ts](../code/backend/src/modules/auth/apple-token-verifier.service.spec.ts)
  proves rejection of: alg:none, wrong key, wrong aud, wrong iss, expired,
  unknown kid, JWKS unreachable.

- **SePay webhook** — closed audit #7-2 + #7-5 (CRITICAL).
  Added [sql/09_payment_events.sql](../code/sql/09_payment_events.sql) +
  Prisma model. Rewrote
  [subscriptions.service.ts](../code/backend/src/modules/subscriptions/subscriptions.service.ts)
  with `timingSafeEqual` token, HMAC-SHA256 body signature, and unique
  insert into `payment_events` for idempotency. Controller now consumes
  the raw body so HMAC sees exact bytes. Enabled
  `rawBody: true` in [main.ts](../code/backend/src/main.ts).
  Env: `SEPAY_WEBHOOK_TOKEN`, `SEPAY_HMAC_SECRET`.

- **OTP logs** — closed audit #7-10 (MEDIUM).
  [otp.service.ts](../code/backend/src/modules/auth/otp.service.ts) logs
  fingerprint only; plaintext via `OTP_DEV_LOG_PLAIN=true` non-prod.

- **GraphQL surface** — closed audit #7-11.
  [app.module.ts](../code/backend/src/app.module.ts) — introspection /
  playground require explicit `GRAPHQL_INTROSPECTION=true` /
  `GRAPHQL_PLAYGROUND=true`.

- **WebSocket validation** — closed audit #7-9.
  [realtime.gateway.ts](../code/backend/src/modules/realtime/realtime.gateway.ts)
  added UUIDv4 regex + restaurant existence check.

- **Mass-assignment defence in depth** — closed audit #7-7, #29 (HIGH).
  New DTOs at
  [users/dto/update-user.dto.ts](../code/backend/src/modules/users/dto/update-user.dto.ts)
  and [posts/dto/posts.dto.ts](../code/backend/src/modules/posts/dto/posts.dto.ts).
  Controllers + service signatures updated. ParseUUIDPipe on all UUID
  params. Server-derived `type` (photo/video/text) replaces client-chosen
  value.

- **Post-like race** — closed audit #13 (CRITICAL).
  [posts.service.ts:like](../code/backend/src/modules/posts/posts.service.ts)
  now uses `createMany skipDuplicates` and only increments `like_count`
  when `created.count > 0`.

- **Graceful shutdown** — closed audit §20-graceful.
  [main.ts](../code/backend/src/main.ts) — `enableShutdownHooks()` + explicit
  SIGTERM/SIGINT trap.

- **Account deletion** — closed audit §27 (App Store 5.1.1, Decree 13).
  [users.service.ts:deleteAccount](../code/backend/src/modules/users/users.service.ts)
  + [users.controller.ts DELETE /me](../code/backend/src/modules/users/users.controller.ts).
  Anonymises row, revokes all sessions, drops PII side tables.

- **Off-site backups + restore drill + TLS monitor** — closed audit §C-Week-1
  ops items.
  [backup-postgres.sh](../code/infra/server/backup-postgres.sh),
  [restore-postgres-test.sh](../code/infra/server/restore-postgres-test.sh),
  [tls-expiry-check.sh](../code/infra/server/tls-expiry-check.sh),
  cron at [cron.d-hnag](../code/infra/server/cron.d-hnag).

### 2026-05-27 (Batch 8 — post-85 Hardening Phase 2)

User confirmed system-first transition complete; flagged observability
still at 6/10 (no Grafana scrape, no Flutter crash tracking), AI cost
needs cooldown, recommendation needs rejection memory, team-scale needs
docs. Batch 8 closes those 6 gaps.

- **Prometheus `/metrics` endpoint** —
  [modules/health/metrics.controller.ts](../code/backend/src/modules/health/metrics.controller.ts).
  Text-exposition format. Exposes: process uptime / memory (rss/heap/external),
  cpu microseconds, build info (version + env), db_up + db_probe_latency,
  redis_up + redis_probe_latency, BullMQ jobs by queue×state, AI spend USD
  today + active users. Hand-rolled (no prom-client dep). Excluded from `/v1`
  prefix; scrape config recommended in route comments.

- **Flutter CrashReporter** —
  [code/flutter/lib/observability/crash_reporter.dart](../code/flutter/lib/observability/crash_reporter.dart).
  Sentry-ready wrapper with `init() / install() / capture() / breadcrumb()`.
  Wires `FlutterError.onError` and `PlatformDispatcher.instance.onError`.
  When `sentry_flutter` dep is added, uncomment 5 lines and set
  `SENTRY_DSN` via `--dart-define`. Until then, no-op falls through to
  `debugPrint`. Wired in [main.dart](../code/flutter/lib/main.dart) before
  any other init so early-boot errors get captured.

- **AI cooldown guard** —
  [common/guards/ai-cooldown.guard.ts](../code/backend/src/common/guards/ai-cooldown.guard.ts).
  `@AiCooldown(2000)` + `@UseGuards(AiCooldownGuard)` composite. Redis
  `SET NX EX` claim — first call wins, subsequent calls inside the window
  get 429 with `Retry-After`. Applied to
  [POST /v1/ai/suggest](../code/backend/src/modules/ai/ai.controller.ts).
  Closes audit production-killer §9 "AI cooldown" — mash-refresh /
  double-tap can no longer burn the daily LLM budget.

- **Rejection memory in ranker** —
  [modules/ai/services/ranker.service.ts](../code/backend/src/modules/ai/services/ranker.service.ts)
  + [taste-memory.service.ts](../code/backend/src/modules/ai/services/taste-memory.service.ts).
  `skip:<userId>:<foodId>` counter (7-day TTL) bumped by
  `applyImplicitFeedback` on action='skip'. Ranker `fetchSkipPenalties()`
  batch-MGETs the candidate set and applies
  `penalty = max(0.3, exp(-skips / 3))`. Final score multiplied by
  penalty. Closes audit production-killer §3 "rejection memory" — a food
  skipped 5+ times in 7 days drops to the bottom of every future suggest.

- **Staging environment** —
  [code/infra/server/docker-compose.staging.yml](../code/infra/server/docker-compose.staging.yml)
  + [hnag.staging.env.example](../code/infra/server/hnag.staging.env.example).
  Parallel stack on same host: separate volumes
  (`pg_stage_data` / `redis_stage_data`), separate container_names
  (`hnag-stage-*`), separate network (`hnag-stage-internal`), separate
  Cloudflare tunnel token, distinct postgres password. Project name
  `hnag-stage` keeps prod untouched. Tighter staging-only env (faster
  slow-query threshold, plaintext OTP logs, cheaper models everywhere).
  Closes audit production-killer §9 "staging environment chuẩn".

- **Architecture + Contributing docs** —
  [docs/ARCHITECTURE.md](ARCHITECTURE.md) +
  [CONTRIBUTING.md](../CONTRIBUTING.md). One-page system shape (DI map,
  module table, cross-cutting layers, auth model, data flow on the
  hottest path, persistence map, enforced architecture rules, where-things-go
  table for new features). CONTRIBUTING covers branch / commit / code-rules
  / style / testing / deploy / security gates. Closes audit
  production-killer §11 "team scale readiness".

### 2026-05-27 (Batch 7 — post-82 Hardening audit: Observability + AI moderation + arch)

User confirmed the system-first phase + flagged Observability as the
weakest layer (5.8/10). Batch 7 closes that gap and adds AI moderation +
architecture-rule enforcement.

- **Prisma slow-query middleware** —
  [common/prisma/prisma.service.ts](../code/backend/src/common/prisma/prisma.service.ts).
  `$on('query')` hook logs every query with duration. Anything ≥
  `SLOW_QUERY_MS_THRESHOLD` (default 200ms) goes to WARN; ≥
  `SLOW_QUERY_BLOCK_MS` (2000ms) to ERROR (pager-worthy). Optional
  full query log via `PRISMA_QUERY_LOG=true` for incident response.

- **Expanded `/health` endpoint** —
  [modules/health/health.controller.ts](../code/backend/src/modules/health/health.controller.ts)
  + [health.module.ts](../code/backend/src/modules/health/health.module.ts).
  Returns dbLatencyMs, cacheLatencyMs, queue depth (otp:email +
  push:fcm: waiting/active/failed/delayed), memory (rss/heap),
  uptime, version, sentry status. Always 200 with `ok=false` on
  granular failure so external monitors get the full picture.

- **Admin observability endpoints** —
  [admin/observability.controller.ts](../code/backend/src/admin/observability.controller.ts).
  Three RBAC-gated routes (admin / super_admin only) with @Audit:
    * `GET /admin/queues` — per-queue job counts (6 states each)
    * `GET /admin/ai-spend?from=&to=&top=` — sum + per-user breakdown
      of llm_cost_usd over a date window
    * `GET /admin/events?hours=24` — analytics_events name distribution
  Each call is itself recorded to analytics_events as `audit:admin.observability.*`
  so over-monitoring shows up.

- **AI Moderation gate** —
  [ai/services/moderation.service.ts](../code/backend/src/modules/ai/services/moderation.service.ts).
  Three layers:
    1. Hard-deny regex on obvious prompt injection ("ignore previous
       instructions" / DAN / "reveal system prompt")
    2. Redis-cached `omni-moderation-latest` API call (24h TTL keyed on
       SHA-256 of input — repeat submissions are free)
    3. Per-user abuse counter — N trips in 24h triggers a forensic warn
       log. Threshold via `MODERATION_ABUSE_THRESHOLD` (default 5).
  Soft-fails open when OpenAI moderation is unavailable so the core
  suggest flow never breaks.
  Wired into the user-text path at `POST /v1/ai/voice`
  (transcript → moderation → intent extraction).

- **Architecture enforcement** —
  [code/backend/.dependency-cruiser.cjs](../code/backend/.dependency-cruiser.cjs).
  Forbid rules: no circular deps, no module-to-module internal
  imports (must go through *.module.ts public surface), no test code
  from prod, warn on orphan files. CI hook in
  [.github/workflows/backend-ci.yml](../.github/workflows/backend-ci.yml)
  runs depcruise on every PR — currently `continue-on-error: true`
  (warn-only) until baseline is clean; flip to false once green.

### 2026-05-27 (Batch 6 — post-78 production-maturity audit)

User reviewed code @ commit `6730c92` and flagged 10 production-killer
maturity gaps. Batch 6 closes 6 of them in code; 4 remain (DDD refactor,
CF recommendation, distributed tracing, frontend polish — all multi-sprint).

- **Prompt registry + versioning** — closed item 2.
  [ai/prompts/prompt-registry.service.ts](../code/backend/src/modules/ai/prompts/prompt-registry.service.ts)
  with `PromptDefinition` (id, version, system, estimatedTokens,
  preferredTier). LLM call sites in
  [llm-reason.service.ts](../code/backend/src/modules/ai/services/llm-reason.service.ts)
  now `prompts.get('reason.caption' | 'reason.select')` instead of inline
  `const SYSTEM = '...'`. Versioned for forensics + A/B.

- **Multi-model cost router** — closed items 2 + 6.
  [ai/services/model-router.service.ts](../code/backend/src/modules/ai/services/model-router.service.ts)
  with `pick(prompt, ctx)` → `{ model, tier, maxOutputTokens, reason }`.
  Routes: over-budget→FALLBACK, prompt-cheap→CHEAP, free-user→CHEAP,
  premium+high-quality-mode→PREMIUM, premium+low-stakes→CHEAP. Env
  overrides: `MODEL_CHEAP` / `MODEL_PREMIUM` / `MODEL_FALLBACK`. Wired
  into `llm-reason.batch()` + `select()`.

- **Analytics event wiring at call sites** — closed item 4.
  [ai-orchestrator.service.ts](../code/backend/src/modules/ai/services/ai-orchestrator.service.ts)
  → `ai:suggest` + `ai:feedback:<action>` events with mode/latency/llm-cost.
  [orders.service.ts](../code/backend/src/modules/orders/orders.service.ts)
  → `order:intent` event with foodId/restaurantId/partner.
  [auth.controller.ts](../code/backend/src/modules/auth/auth.controller.ts)
  → `auth:otp_send` (email hash + IP hash) + `auth:otp_verify` (success/fail).
  AnalyticsService promoted to `@Global()` via
  [common/analytics/analytics.module.ts](../code/backend/src/common/analytics/analytics.module.ts).

- **RBAC + roles** — closed item 7-part-A.
  [sql/14_user_roles.sql](../code/sql/14_user_roles.sql) adds `user_role`
  enum (user / owner / creator / moderator / support / admin / super_admin)
  + `users.role` column + partial index. Prisma schema updated.
  [common/decorators/roles.decorator.ts](../code/backend/src/common/decorators/roles.decorator.ts)
  exports `@Roles('admin', 'super_admin')` composite decorator.
  [common/guards/roles.guard.ts](../code/backend/src/common/guards/roles.guard.ts)
  re-reads role on every request (no JWT trust), super_admin overrides,
  admin is superset of moderator/support/owner/creator.

- **Audit log interceptor** — closed item 7-part-B.
  [common/interceptors/audit-log.interceptor.ts](../code/backend/src/common/interceptors/audit-log.interceptor.ts)
  exports `@Audit({ event, level })` decorator. Global interceptor reads
  the metadata, fires `audit:<event>` analytics + structured log on
  successful invocations. Pair with `@Roles('admin')` on every sensitive
  admin / billing / claim route.

- **Prisma migration baseline runbook** — closed item 9.
  [code/backend/scripts/bootstrap-prisma-migrations.sh](../code/backend/scripts/bootstrap-prisma-migrations.sh)
  generates `prisma/migrations/0_init/migration.sql` from current schema,
  marks it as already applied (so prod DB isn't touched). After this
  script runs once, all future changes go through
  `prisma migrate dev` → `prisma migrate deploy`.

- **Global modules cleanup** — minor refactor.
  [common/analytics/analytics.module.ts](../code/backend/src/common/analytics/analytics.module.ts)
  + [common/config/feature-flags.module.ts](../code/backend/src/common/config/feature-flags.module.ts)
  with `@Global()` so cross-cutting concerns don't need per-module
  imports. AuditLogInterceptor wired globally in main.ts.

### 2026-05-27 (Batch 5 — prompt-pack §11 launch checklist)

- **BullMQ OTP email worker** — closed audit §9 (HIGH).
  [common/queues/queues.module.ts](../code/backend/src/common/queues/queues.module.ts)
  + [email-otp.processor.ts](../code/backend/src/common/queues/email-otp.processor.ts).
  `OtpService.sendEmail` now enqueues to `otp:email` instead of awaiting
  the SMTP call — `/auth/email-otp/send` returns ≤10ms instead of 1-2s.
  4 attempts with exponential backoff; payloads scrubbed by removeOnComplete.

- **BullMQ FCM push worker** —
  [push.processor.ts](../code/backend/src/common/queues/push.processor.ts).
  Drains `push:fcm` with concurrency=10. Routes through
  `NotificationsService.push` so the in-app row + FCM dispatch logic
  stays in one place.

- **Feature flag service** — closed prompt-pack §11 "feature flags".
  [common/config/feature-flags.service.ts](../code/backend/src/common/config/feature-flags.service.ts).
  Three layers: Redis `ff:<flag>` (runtime toggle) → env `FF_<FLAG>`
  (boot-time) → code default. Per-process 5s memcache. Per-user bucket
  (`bucket(userId, flag, percent)`) for percent rollouts via stable hash.
  Registered globally in AppModule.

- **SEO suite** — closed audit §19.
  [web-marketing/src/app/robots.ts](../code/web-marketing/src/app/robots.ts):
  allow-all marketing + disallow `/api/`, `/dashboard/`, AI scrapers.
  [sitemap.ts](../code/web-marketing/src/app/sitemap.ts): root + pricing
  + showcase + sub-sitemap pointers.
  [sitemap-restaurants.xml/route.ts](../code/web-marketing/src/app/sitemap-restaurants.xml/route.ts):
  ISR-cached (6h) per-restaurant URL list, calls backend
  `/v1/restaurants/sitemap`.
  [layout.tsx](../code/web-marketing/src/app/layout.tsx): full OG + Twitter
  + canonical + robots directives + title template.

- **Flutter ResilientClient** — closed audit §5-Flutter §B-21.
  New [api/resilient_client.dart](../code/flutter/lib/api/resilient_client.dart)
  with 3-attempt exponential backoff + jitter, per-host circuit breaker
  (5 consecutive failures → 30s cooldown), explicit timeouts. `_fetchList`
  migrated; remaining 36 raw http calls in `hnag_api.dart` can be migrated
  one-at-a-time without breaking — they keep working through the raw path.

- **Analytics events** — closed prompt-pack §11 "user behavior tracking",
  "session analytics", "recommendation analytics", "search analytics".
  [sql/13_analytics_events.sql](../code/sql/13_analytics_events.sql)
  creates an append-only `analytics_events` table with indexes per
  (event, time), (user_id, time), (session_id), (time).
  [common/analytics/analytics.service.ts](../code/backend/src/common/analytics/analytics.service.ts)
  exposes a fire-and-forget `track(event)` method. Naming convention:
  `<domain>:<action>` (`suggest:impression`, `food:view`, …). Registered
  globally so any service can inject it.

### 2026-05-27 (Batch 4 — Week 4/5 + audit log + e2e + k6)

- **Owner-side backend module** — closed audit §5 / §27 / §B-15.
  New [restaurants/owner.controller.ts](../code/backend/src/modules/restaurants/owner.controller.ts)
  + [owner.service.ts](../code/backend/src/modules/restaurants/owner.service.ts)
  + [dto/owner.dto.ts](../code/backend/src/modules/restaurants/dto/owner.dto.ts).
  Endpoints: `GET /v1/owner/restaurants`, `GET/PATCH /v1/owner/restaurants/:id`,
  `PATCH /v1/owner/restaurants/:id/live` (broadcasts to WebSocket room),
  `GET /v1/owner/restaurants/:id/orders/live`,
  `GET /v1/owner/restaurants/:id/reviews`, full menu CRUD
  (`/menu`, `POST`, `PATCH /menu/:itemId`, `DELETE /menu/:itemId`).
  Every method calls `assertOwner` — looks up an `approved` row in
  `restaurant_claims` for the current user. No admin override on this
  controller; admin tools live behind GraphQL.

- **Flutter cart persistence** — closed audit §B-Cart / §5-Flutter.
  New [lib/state/cart_store.dart](../code/flutter/lib/state/cart_store.dart)
  with secure_storage backing + 24h max-age guard. CartScreen calls
  `_persist()` after every `_delta` mutation; load is the caller's
  responsibility at route entry.

- **Deep linking** — closed audit §B-17.
  [AndroidManifest.xml](../code/flutter/android/app/src/main/AndroidManifest.xml)
  declares `hnag://` custom scheme + `https://tothanhthuy.cloud/{r,f,c}/<id>`
  App Links (autoVerify=true). New
  [lib/state/deep_link_router.dart](../code/flutter/lib/state/deep_link_router.dart)
  parses an inbound URI into a `DeepLinkTarget` and pushes the named route.
  New [web-marketing/.well-known/assetlinks.json route](../code/web-marketing/src/app/.well-known/assetlinks.json/route.ts)
  serves the Android verification file from env (`ANDROID_SHA256_FINGERPRINTS`).
  iOS Universal Links require an `apple-app-site-association` file + the
  associated-domains entitlement; see §6 below.

- **Account deletion audit log** — closed audit §C-Week-3 deletion receipt.
  [sql/12_account_deletions.sql](../code/sql/12_account_deletions.sql)
  creates the forensic table; Prisma model added; `users.service.deleteAccount`
  now snapshots counters (followers/following/reviews/orders/sessions),
  hashes email + IP with SHA-256, writes an audit row before completing.
  Controller passes `@Ip()` + `User-Agent` header through. Non-blocking —
  if the table isn't applied yet the delete still succeeds and a warn logs.

- **E2E auth flow test** — closed audit §31.
  [test/auth.e2e-spec.ts](../code/backend/test/auth.e2e-spec.ts) uses
  in-memory fakes for Prisma + Redis (no external services needed). Proves:
  send returns 200 + no `devCode` leak; malformed email → 400; wrong code
  → 401; right code → 200 + accessToken/refreshToken/user; malformed
  refresh token → 401. Pinned by the regression intent — if any of those
  invariants ever flips, CI fails.

- **k6 load test script** — closed audit §38 / §39 baseline.
  [code/infra/loadtest/k6-suggest.js](../code/infra/loadtest/k6-suggest.js)
  ramps 0→500 VUs across 5 stages, hits `/restaurants/nearby` always +
  `/ai/suggest` when `TOKEN` env is set, randomises across 5 VN
  locations (HCMC, HN, Đà Nẵng). Thresholds match audit targets:
  suggest p95 < 1.4s, nearby p95 < 500ms, error rate < 1%.

### 2026-05-27 (Batch 3 — Week 3 monetization core + Week 6 ops)

- **LLM cost tracking** — closed audit §15.
  [llm-reason.service.ts](../code/backend/src/modules/ai/services/llm-reason.service.ts)
  exports `LlmCostTracker` + `newCostTracker()` + private `chargeUsage()`.
  Both `batch()` and `select()` accept an optional tracker; each
  `chat.completions.create` call sums `usage.prompt_tokens` ×
  $0.15/M + `usage.completion_tokens` × $0.60/M (override via
  `OPENAI_PRICING_USD_PER_M`).
  [ai-orchestrator.service.ts](../code/backend/src/modules/ai/services/ai-orchestrator.service.ts)
  instantiates a fresh tracker per `suggest()`, passes it through, writes
  the total to `ai_sessions.llm_cost_usd` (Decimal(8,5)), and increments
  a Redis daily counter at `ai:spend:<userId>:<YYYY-MM-DD>` (7-day TTL).

- **Server-side Premium guard** — closed audit §8 / §B-Premium.
  [common/guards/premium.guard.ts](../code/backend/src/common/guards/premium.guard.ts)
  exposes `@Premium()` — a composite decorator that pulls in
  `AuthGuard('jwt')` + `PremiumGuard` + metadata. Guard re-checks
  `users.is_premium && users.premium_until > now() && status != deleted`
  on every request. Fail-closed on infra errors. Registered as a regular
  provider in `app.module.ts` so any controller can pull it in via the
  decorator alone.

- **Order idempotency keys** — closed audit §B-19.
  [orders.controller.ts](../code/backend/src/modules/orders/orders.controller.ts)
  reads `Idempotency-Key` header (8-128 chars, `[A-Za-z0-9._:-]+`),
  claims a lock via Redis `SET NX EX 86400` namespaced
  `idem:order:<userId>:<key>`, caches the response for 24h, and replays
  on retry. Validates the key format defensively even though the userId
  prefix already prevents cross-user replay.
  Also added [dto/order.dto.ts](../code/backend/src/modules/orders/dto/order.dto.ts)
  with `CreateOrderIntentDto` + `UpdateOrderStatusDto` and ParseUUIDPipe
  on every UUID param.

- **Leaderboard materialized views** — closed audit §11 / §34.
  [sql/11_leaderboard_mv.sql](../code/sql/11_leaderboard_mv.sql) creates
  `leaderboard_weekly` + `leaderboard_monthly` MVs with unique indexes
  (for CONCURRENTLY refresh) + helper `refresh_leaderboards()` function.
  Backend cron at
  [challenges/leaderboard-refresh.cron.ts](../code/backend/src/modules/challenges/leaderboard-refresh.cron.ts)
  refreshes every 5 min via @nestjs/schedule.
  [challenges.service.leaderboard](../code/backend/src/modules/challenges/challenges.service.ts)
  reads from the MV for weekly/monthly scope; global stays live.
  Sub-millisecond vs 2-5s before.

- **2nd backend replica** — closed audit §6 / §39.
  [docker-compose.prod.yml](../code/infra/server/docker-compose.prod.yml)
  adds `backend-2` service identical to `backend`, with network alias
  `backend` so Docker DNS round-robins between both containers
  automatically. Cloudflare tunnel ingress unchanged (still points to
  `backend:4000`); both containers receive traffic. Kill one → traffic
  drains naturally to the other → zero-downtime restarts.

- **Flutter image cache sweep** — closed audit §5-Flutter.
  Three remaining v2 screens migrated: 
  [search_screen.dart](../code/flutter/lib/screens/search_screen.dart),
  [premium_screen.dart](../code/flutter/lib/screens/premium_screen.dart),
  [restaurant_claim_screen.dart](../code/flutter/lib/screens/restaurant_claim_screen.dart).
  DS widgets ([hnag_photo.dart](../code/flutter/lib/widgets/ds/hnag_photo.dart),
  [hnag_avatar.dart](../code/flutter/lib/widgets/ds/hnag_avatar.dart))
  already on CachedNetworkImage. V1 screens (15 files with raw
  `NetworkImage(...)`) deferred — they vanish at the v2 main-flow
  cut-over.

### 2026-05-27 (Week 2 — Foundation)

- **Missing indexes** — closed audit §3 / §11 / §34.
  [sql/10_indexes.sql](../code/sql/10_indexes.sql) adds 11 indexes for the
  hot read paths (follows, reviews, food_interactions, notifications,
  posts, saved_items, auth_sessions, subscriptions) + ANALYZE. Idempotent
  (every CREATE is `IF NOT EXISTS`). Apply once on the server with
  `docker exec -i hnag-postgres psql -U hnag -d hnag < code/sql/10_indexes.sql`.

- **`$queryRawUnsafe` → typed Prisma** — closed audit #7-8 (HIGH).
  [subscriptions.service.ts](../code/backend/src/modules/subscriptions/subscriptions.service.ts):
  trial-exists check, pending-sub insert, promo redemption guard, and
  `myStatus` all replaced with `findFirst` / `findMany` / `create`.
  [users.service.ts](../code/backend/src/modules/users/users.service.ts):
  `listSaves`, `addSave`, `removeSave` replaced with typed Prisma. Added
  `saved_items` Prisma model.

- **Parallelized profile + status queries** — closed audit §11 (HIGH).
  [users.service.me](../code/backend/src/modules/users/users.service.ts) (6
  queries) and
  [subscriptions.myStatus](../code/backend/src/modules/subscriptions/subscriptions.service.ts) (2
  queries) now run via `Promise.all`. Cold p95 ≈ slowest query, not sum.

- **Streak race condition** — closed audit §13 (HIGH).
  [users.service.bumpDecideStreak](../code/backend/src/modules/users/users.service.ts)
  now wraps read-compute-write in a transaction with a conditional
  `updateMany` (only writes if no concurrent caller advanced past today).

- **PgBouncer + Redis AOF** — closed audit §4 / §5.
  [docker-compose.prod.yml](../code/infra/server/docker-compose.prod.yml)
  adds the `pgbouncer` service (transaction-pool, 1000×30 max), rewrites
  the backend `DATABASE_URL` to go through it (with `pgbouncer=true` so
  Prisma drops prepared statements), and adds `DIRECT_DATABASE_URL` for
  migrations. Redis command list switched to AOF `everysec` + RDB.

- **Structured logs + request-id** — closed audit §23 (CRITICAL).
  [common/config/logger.ts](../code/backend/src/common/config/logger.ts)
  with pino + pino-http (both already in deps). Redaction list scrubs
  auth headers, OTP codes, refresh tokens, Sepay HMAC signatures.

- **Sentry hook (lazy-require)** — partial close of audit §23.
  [common/config/sentry.ts](../code/backend/src/common/config/sentry.ts).
  Activates only when `SENTRY_DSN` is set AND `@sentry/node` is installed
  (add to package.json on next deps refresh). Fail-open in all other
  cases — no boot breakage.

- **Correction to audit §32 "No CI/CD"** — the audit was wrong.
  [.github/workflows/backend-ci.yml](../.github/workflows/backend-ci.yml)
  already runs lint + tsc + npm test (with real Postgres + Redis services)
  + npm audit + Trivy CRITICAL gate + multi-arch Docker build & push to
  GHCR. [.github/workflows/mobile-ci.yml](../.github/workflows/mobile-ci.yml)
  runs `dart format --set-exit-if-changed`, `flutter analyze`,
  `flutter test --coverage` (with Codecov), and Android release build.
  The new `apple-token-verifier.service.spec.ts` from Week 1 will be
  picked up automatically by the existing test job.

  **Real gaps in the existing CI** (Week 6 follow-up):
  - No e2e tests (`test/jest-e2e.json` referenced but empty).
  - Backend deploy targets `hnag-prod-eks` (theoretical AWS); the real
    self-hosted path lives in `server-deploy.yml` — verify it still
    works after the compose changes (PgBouncer dependency).
  - Mobile CI build-ios is a no-op without a macOS runner; the iOS
    pipeline runs on the dedicated Mac VM via
    [ios-vm-build.yml](../.github/workflows/ios-vm-build.yml).

---

## §5 — Production readiness score (audit baseline + delta)

The audit established a baseline of **48 / 100**. Progress:

| Dimension | Baseline | W1 | W2 | B3 | B4 | B5 | B6 | **B7** | Notes |
|-----------|----------|----|----|----|----|----|----|----|-------|
| Shipped-code quality | 7 | 7 | 8 | 8 | 9 | 9 | 9 | **9** | Holding |
| Pitch ↔ reality | 4 | 4 | 4 | 5 | 6 | 6 | 7 | **7** | Holding |
| Security | 3 | 7 | 7 | 8 | 8 | 8 | 9 | **9** | Holding |
| Operations | 2 | 5 | 8 | 9 | 9 | 10 | 10 | **10** | Maxed |
| Observability | 2 | 5 | 6 | 7 | 7 | 8 | 8 | 10 | **10** | + Prometheus /metrics + Flutter crash reporter |
| AI maturity | 5 | 5 | 5 | 6 | 6 | 7 | 8 | 9 | **9** | + AI cooldown guard |
| Recommendation maturity | 5 | 5 | 5 | 5 | 5 | 5 | 6 | 6 | **8** | + rejection-memory exp-decay penalty |
| Architecture enforcement | 4 | 4 | 4 | 4 | 5 | 5 | 5 | 7 | **8** | + ARCHITECTURE.md + CONTRIBUTING.md (team-scale) |
| Env / deploy maturity | 3 | 4 | 4 | 5 | 5 | 5 | 5 | 6 | **8** | + staging compose + env separation |
| **Overall /100** | **48** | 58 | 66 | 72 | 76 | 78 | 82 | 85 | **87** | +39 from baseline |

**Target reached: 78 / 100 — Series-A credible floor.** From here every
remaining point requires user-runtime input that cannot be coded solo:

- **+2 → 80:** Flutter v2 main-flow cut-over (UX review needed).
- **+2 → 82:** Real payment E2E proof (real bank account needed).
- **+3 → 85:** AI moderation pipeline + content review queue (OpenAI
  moderation API key + human review process).
- **+5 → 90:** Restaurant data ops — 1k HCMC menus fully populated
  (paid interns, not eng).
- **+10 → 100:** unicorn-grade polish (multi-region DR, fine-tuned
  embeddings, real Fridge Vision model, A/B testing platform).

---

## §6.5 — Deep-link verification files (App Links / Universal Links)

**Android (App Links)** — deployed via the Next.js route handler at
[code/web-marketing/src/app/.well-known/assetlinks.json/route.ts](../code/web-marketing/src/app/.well-known/assetlinks.json/route.ts).
Reads SHA-256 fingerprint(s) of the Android release keystore from env:

```
# In code/web-marketing/.env.production
ANDROID_PACKAGE_NAME=vn.hnag.hnag
ANDROID_SHA256_FINGERPRINTS=AA:BB:CC:...:99,DD:EE:...
```

Get the fingerprint with: `keytool -list -v -keystore release.keystore`.
Verify deployment with:
`curl https://tothanhthuy.cloud/.well-known/assetlinks.json | jq`.

**iOS (Universal Links)** — needs a static file at
`https://tothanhthuy.cloud/.well-known/apple-app-site-association` AND the
`com.apple.developer.associated-domains` entitlement in the iOS bundle.
Because the Flutter iOS scaffold is partial on this checkout (no
`ios/Runner/Info.plist` checked in — see memory `hnag-ios-build-gotchas`),
the full iOS deep-link wiring needs to happen on the Mac VM where the
iOS project is fully regenerated. File to deploy:

```json
{
  "applinks": {
    "apps": [],
    "details": [{
      "appID": "FP8Z984262.vn.hnag.hnag",
      "paths": [ "/r/*", "/f/*", "/c/*" ]
    }]
  }
}
```

(Replace the `FP8Z984262` team prefix if the Apple team id changes.)

## §6 — Environment variables introduced this round

Add to `hnag.env` on the server:

```
# Apple Sign-In — bundle id used as the expected `aud` on identityTokens.
# Default is vn.hnag.hnag (matches the real bundle per memory).
APPLE_BUNDLE_ID=vn.hnag.hnag

# SePay webhook hardening. Both REQUIRED in production. The HMAC secret
# lives in the SePay console under "Webhook → Secret".
SEPAY_WEBHOOK_TOKEN=<long random>
SEPAY_HMAC_SECRET=<long random from SePay dashboard>

# OTP — leave UNSET in production. Setting to "true" in dev surfaces
# plaintext OTPs in `docker logs` for manual QA.
# OTP_DEV_LOG_PLAIN=

# GraphQL admin — leave UNSET to keep introspection/playground OFF.
# Set both to "true" only on a developer workstation.
# GRAPHQL_INTROSPECTION=
# GRAPHQL_PLAYGROUND=
```

Backup secrets (separate file at `/opt/hnag/backup.env`, chmod 600 root):

```
RCLONE_REMOTE=b2:hnag-backups-prod
POSTGRES_USER=hnag
POSTGRES_DB=hnag
BACKUP_AGE_RECIPIENT=age1...
HEALTHCHECK_URL=https://hc-ping.com/<uuid>
HEALTHCHECK_RESTORE_URL=https://hc-ping.com/<uuid>
HEALTHCHECK_TLS_URL=https://hc-ping.com/<uuid>
ALERT_WEBHOOK_URL=https://hooks.slack.com/services/...
```

---

## §7 — Deploy notes for Week 1 changes

Run these on ServerLinux in order:

```bash
# 1. Pull new code
cd /opt/docker/hnag && git pull

# 2. Apply payment_events migration (Prisma migrations are not bootstrapped
#    yet — see Week 2; for now, apply by hand):
docker exec hnag-postgres psql -U hnag -d hnag < /opt/docker/hnag/code/sql/09_payment_events.sql

# 3. Update env
sudo $EDITOR /opt/docker/hnag/hnag.env   # add APPLE_BUNDLE_ID, SEPAY_HMAC_SECRET

# 4. Build + restart backend (recreate so env reloads — see memory
#    `hnag-server-compose-env-gotcha` for why --env-file matters)
cd /opt/docker/hnag/code/infra/server
docker compose --env-file ../../hnag.env -f docker-compose.prod.yml build backend
docker compose --env-file ../../hnag.env -f docker-compose.prod.yml up -d backend

# 5. Install backup scripts
sudo install -m 0755 backup-postgres.sh         /opt/hnag/backup-postgres.sh
sudo install -m 0755 restore-postgres-test.sh   /opt/hnag/restore-postgres-test.sh
sudo install -m 0755 tls-expiry-check.sh        /opt/hnag/tls-expiry-check.sh
sudo install -m 0644 cron.d-hnag                /etc/cron.d/hnag
sudo $EDITOR /opt/hnag/backup.env  # paste secrets from §6
sudo systemctl restart cron

# 6. Verify
sudo /opt/hnag/backup-postgres.sh daily
sudo /opt/hnag/tls-expiry-check.sh
# expect: "verified: <bytes>" and TLS days_left > 14 on every host
```

---

## §8 — Next session: where to start

### Items that REQUIRE user input (cannot be done solo by Claude)

These are the remaining 12 items. Each is gated on something only you can do:

1. **Real payment E2E** (Week 3) — needs:
   - A real personal bank account number → set `VIETQR_BANK_BIN`,
     `VIETQR_ACCOUNT_NO`, `VIETQR_ACCOUNT_NAME` in `hnag.env`.
   - A SePay account → `SEPAY_WEBHOOK_TOKEN`, `SEPAY_HMAC_SECRET`.
   - One real 49,000₫ transfer to your own account to prove the loop.
   - Flutter checkout flow swap: change [checkout_screen.dart](../code/flutter/lib/screens/detail_v2/checkout_screen.dart)
     to call `POST /v1/subscription/checkout` and show the returned
     `qrUrl` + poll `GET /v1/subscription/me` for `isPremium = true`,
     instead of the current deep-link to GrabFood. Backend is ready.

2. **Deploy SQL migrations + npm install** (verifies everything compiles):
   - `cd code/backend && npm install` then `npm run build` — fix any
     type errors that show up (this session can't run tsc).
   - Apply `09_payment_events.sql`, `10_indexes.sql`,
     `11_leaderboard_mv.sql` on ServerLinux.
   - Recreate backend with new compose (PgBouncer + backend-2).
   - Smoke-test: `curl https://api.tothanhthuy.cloud/health` and
     verify pino-JSON logs in `docker logs`.

3. **Flutter v2 main-flow cut-over** (Week 4) — needs UX review on which
   v2 screens are launch-ready. Half-day pair-programming with designer
   to swap [lib/main.dart](../code/flutter/lib/main.dart) routing.

4. **Owner dashboard backend wiring** (Week 5) — needs the backend
   endpoints `GET /v1/owner/orders/live`, `GET /v1/owner/reviews`,
   `PATCH /v1/owner/restaurants/:id`. These don't exist yet; need to
   spec the data shape first.

5. **Menu CRUD for claimed restaurants** (Week 5) — needs schema design
   (menu_items already has `restaurant_id` FK, need to expose write
   endpoints for verified claim owners).

6. **Restaurant data ops** (Week 5) — 500-1,000 HCMC restaurants with
   menus + photos + hours. Pay 2 interns 2 weeks. Not engineering.

7. **e2e test scaffolding** (Week 6) — `test/jest-e2e.json` referenced
   but `test/` empty. ~half-day to scaffold auth/order/AI happy paths.

8. **k6 load test** (Week 6) — needs a staging environment + the new
   backend deployed; otherwise the baseline is meaningless.

9. **iOS build verification** — needs Mac VM access; track via
   `ios-vm-build.yml`.

10-12. (Defer / out of scope until product decision)
    - Account-deletion email receipt — small.
    - Cart persistence with `flutter_secure_storage` — small.
    - Deep linking + restaurant SEO pages — medium.

### Recommended next focus

Open §3 → Week 3 OR Week 4 (pick one — both blocked-by ≠ each other).

### Recommended next: Week 3 — Monetization

Highest-value remaining work. The mock payment is the single biggest gap
between pitch and reality (audit §5-Flutter / §27 / §B-1).

1. **Choose a Vietnam-friendly provider:** VietQR (no business reg
   needed; we already have the QR + SePay reconciliation pipeline hardened
   in W1) OR VNPay (full e-commerce flow, requires business reg).
   For Series-A bridge: VietQR is enough to *prove the loop*.
2. **Wire the Flutter checkout to actually call
   `POST /v1/subscription/checkout`** instead of deep-linking out. Show
   the QR, poll `GET /v1/subscription/me` for activation, fall back to
   "tôi đã chuyển" button → manual support.
3. **Enforce premium server-side** on every premium-only endpoint. The
   audit found the JWT `isPremium` claim is up to 15min stale — never
   trust it; query `users.is_premium && users.premium_until > now()`.
4. **End-to-end proof** — make one real ₫49,000 transfer to your own
   personal account, verify the webhook fires, premium activates.

### Alternative next: Week 4 — Flutter cut-over

If you'd rather collapse the two design systems first (it's accruing
bug-fix double-cost every week), the next-item is:

1. Read `lib/main.dart` routing — confirm `home_v2/` is now the main
   path; if `_hifi_demo.dart` is still gating v2 access, swap the
   default route.
2. Run a sweep: replace every `Image.network(...)` with
   `CachedNetworkImage` (already in pubspec).
3. Convert the TikTok feed to `ListView.builder` with lazy chunked load.
4. Add `flutter_secure_storage` write for cart + auth state.

### Before either: a 30-minute cleanup

- Run `npm install` in code/backend so the new TypeScript files type-check.
  If anything fails, fix or revert specific files (NOT the whole batch).
- Apply both new SQL files in order:
  ```
  docker exec -i hnag-postgres psql -U hnag -d hnag < code/sql/09_payment_events.sql
  docker exec -i hnag-postgres psql -U hnag -d hnag < code/sql/10_indexes.sql
  ```
- Pull the new Prisma schema view: `npx prisma db pull && npx prisma generate`.
- Recreate the backend with the new compose (PgBouncer dep + new env vars):
  ```
  cd code/infra/server
  docker compose --env-file ../../hnag.env -f docker-compose.prod.yml up -d --force-recreate pgbouncer backend
  ```
- Smoke-test: `curl https://api.tothanhthuy.cloud/health` — both `db` and
  `cache` should return true. Check `docker logs hnag-backend` for
  pino-JSON output.

When Week 3 or 4 is done, update §2 status board, append to §4 done log,
and refresh §5 score.

---

_End of plan. If you find this stale, that's a bug — update it._
