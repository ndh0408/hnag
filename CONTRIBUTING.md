# Contributing to HNAG

> Quick rules so a new engineer can ship a PR on day 1 without breaking things.
> Pair with [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the mental model
> and [docs/99-PRODUCTION-READINESS.md](docs/99-PRODUCTION-READINESS.md) for the
> current work tracker.

## Before you start

1. Read **ARCHITECTURE.md §"Where things go"** — confirm your change lands
   in the right module.
2. Skim **99-PRODUCTION-READINESS.md §2 status board** — there's a decent
   chance a related item is already in flight.
3. If you're touching anything in the "production-killer" list (DDD,
   recommendation CF, OpenTelemetry, frontend polish), open an issue
   first — those need cross-module coordination.

## Branch + commit

- Branch off `main` for fixes, off `develop` for bigger features.
- Conventional commit prefixes:
  - `feat(<scope>): ...`  — new feature
  - `fix(<scope>): ...`   — bug fix
  - `refactor(<scope>): ...` — no behavior change
  - `chore(<scope>): ...` — config / deps / docs
  - `test(<scope>): ...`  — test-only
  - `perf(<scope>): ...`  — measurable perf change
- Co-authors: include for AI-assisted PRs.

## Code rules (enforced)

These are NOT style preferences — CI fails if you break them.

1. **No module-to-module internal imports.** Module `users` may NOT
   import `modules/orders/orders.service.ts`. Inject the service via
   the module's public `*.module.ts` exports. See
   `.dependency-cruiser.cjs` for the exact rule.
2. **No circular deps anywhere.** Refactor through `common/`.
3. **No `body: any` on controllers.** Use a DTO with `class-validator`
   decorators (or `ZodValidationPipe` for newer code). The global
   `ValidationPipe` (whitelist + forbidNonWhitelisted) strips extras but
   the DTO is the **explicit allowlist** that documents what's writable.
4. **No `$queryRawUnsafe` with user-controlled `LIKE` prefixes.** Use
   the typed Prisma builder; reserve raw SQL for genuinely complex
   aggregates with parameterised inputs only.
5. **No plaintext OTPs / refresh tokens / passwords in logs.** Use
   `fingerprintOtp(code)` or SHA-256 prefix. Sentry / Loki audit-grade
   redaction is on the request/response level (see
   `common/config/logger.ts redact` list).
6. **No raw `http.post`/`http.get` in Flutter API services.** Wrap via
   `ResilientClient` or at minimum convert errors to `ApiException` so
   UI doesn't surface raw `ClientException` text.
7. **Always pair `@Roles(...)` with `@Audit(...)` on admin actions.**
   The audit log is the forensic trail when something breaks at 2am.

## Style

- TypeScript: 2-space indent, single quotes, trailing commas, ESLint
  config in `code/backend/.eslintrc.js`.
- Dart: `dart format` (auto-enforced in CI).
- No emoji in code unless the user explicitly asks. Emojis in commit
  messages are fine; in comments / docs / code, avoid.
- Comments explain **why**, not what. `// increment counter` is noise;
  `// reset on success so a future verify gets a fresh window (audit
  hnag-audit-2026-05 #3)` earns its line.

## Testing

- Unit tests: `npm test` in `code/backend/`, `flutter test` in
  `code/flutter/`. Both run on every PR via GitHub Actions.
- E2E tests: in `code/backend/test/` with `*.e2e-spec.ts` naming. Use
  in-memory fakes for Prisma + Redis (see `test/auth.e2e-spec.ts` for
  the pattern). The CI test job also spins real Postgres + Redis
  service containers, so heavier E2E flows can hit a live stack.
- Load tests: `code/infra/loadtest/k6-suggest.js`. Run with
  `k6 run -e BASE_URL=... -e TOKEN=...`.

## Deploying

- Production deploys are **gated**: PR → green CI → merge to `main` →
  `backend-ci.yml` builds the image to GHCR with `:latest` tag → manual
  `deploy.sh` on `ServerLinux` pulls + recreates.
- Schema changes go through staging first. There is no
  `prisma db push --accept-data-loss` in any script — if you need to
  drop a column, write a backward-compatible migration, deploy, deprecate
  the read path, deploy again, drop the column on the third deploy.
- SQL changes land as a new `code/sql/NN_<name>.sql` file. After
  bootstrap (`scripts/bootstrap-prisma-migrations.sh`), they ALSO need
  to be expressed as a Prisma migration (`npx prisma migrate dev`).
- Env vars: add to BOTH `hnag.env.example` AND `hnag.staging.env.example`.

## Security gates

- Never commit secrets. Run `git diff --staged | grep -iE 'sk-|pk_|api[_-]?key|secret|password'` before committing if you touched env files.
- Never push `--force` to `main` or `develop`. Tagged releases only.
- Never skip CI checks (`--no-verify` etc.) without explicit team approval.

## Need help?

- Architecture questions: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- Where is X tracked: [docs/99-PRODUCTION-READINESS.md](docs/99-PRODUCTION-READINESS.md)
- Reusable audit prompts: [scripts/audit-prompts.md](scripts/audit-prompts.md)
- Stuck on env / deploy: [code/infra/server/README.md](code/infra/server/README.md)
