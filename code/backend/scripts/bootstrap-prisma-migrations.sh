#!/usr/bin/env bash
#
# Bootstrap Prisma Migrate baseline.
# ============================================================================
# Audit prompt-pack §9 ("migration safety mindset"). HNAG has been managed
# via `prisma db pull` + hand-applied SQL files (code/sql/01-14_*.sql).
# That's fine for solo development; with real users it's a foot-gun:
#   - no rollback path
#   - no record of WHICH migration ran WHEN
#   - identical-name files can be applied twice (some are not idempotent)
#
# This script captures the CURRENT live schema as the Prisma Migrate
# "init" baseline. After this runs once, every future schema change
# goes through `prisma migrate dev` (local) → committed as a new
# migration file → applied in prod by `prisma migrate deploy`.
#
# Idempotent. Safe to re-run — bails early if the baseline already exists.
#
# Run inside the backend container (or wherever node_modules is) on a
# machine that can reach the prod DB via DIRECT_DATABASE_URL.
#
#   ./scripts/bootstrap-prisma-migrations.sh
#
# Required env (sourced from hnag.env or set inline):
#   DATABASE_URL          — pooled (PgBouncer:6432); used by app at runtime
#   DIRECT_DATABASE_URL   — direct to Postgres:5432; required by Prisma migrate
# ============================================================================

set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -z "${DIRECT_DATABASE_URL:-}" ]]; then
  echo "❌ DIRECT_DATABASE_URL is required (Prisma migrate cannot use a PgBouncer connection)"
  exit 1
fi

BASELINE_DIR="prisma/migrations/0_init"
if [[ -d "$BASELINE_DIR" ]]; then
  echo "✓ Baseline already exists at $BASELINE_DIR — nothing to do."
  echo "   To start a fresh baseline, delete the directory and re-run."
  exit 0
fi

echo "→ Generating baseline migration from current schema.prisma…"
mkdir -p "$BASELINE_DIR"

# Generate the SQL that would create the current schema from empty.
# This is the snapshot we declare "ground truth" — it MUST match what's
# in the live database; we'll resolve any drift in the next step.
DATABASE_URL="$DIRECT_DATABASE_URL" \
  npx prisma migrate diff \
    --from-empty \
    --to-schema-datamodel prisma/schema.prisma \
    --script > "$BASELINE_DIR/migration.sql"

# Tell Prisma to record this migration as already applied without re-running
# it (the schema already exists in prod from the hand-applied SQL files).
echo "→ Marking baseline as applied (without running it)…"
DATABASE_URL="$DIRECT_DATABASE_URL" \
  npx prisma migrate resolve --applied 0_init

echo ""
echo "✅ Baseline established. From here:"
echo "   - Local dev:  npx prisma migrate dev --name <change-name>"
echo "   - Prod deploy: npx prisma migrate deploy"
echo ""
echo "Committed files: $BASELINE_DIR/migration.sql"
echo "Run 'git add prisma/migrations' to lock this in."
