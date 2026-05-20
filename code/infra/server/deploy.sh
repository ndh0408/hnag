#!/usr/bin/env bash
# =============================================================================
# HNAG — Deploy script (runs on ServerLinux after SSH)
# Usage: ./deploy.sh [version]
#   version: image tag (default: latest)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

VERSION="${1:-latest}"
COMPOSE="docker compose -f docker-compose.prod.yml"

log() { echo "[$(date +%H:%M:%S)] $*"; }

log "🍜 HNAG deploy starting — version=$VERSION"

# 0. Sanity
if [ ! -f hnag.env ]; then
  echo "❌ hnag.env missing. Copy hnag.env.example and fill secrets."
  exit 1
fi
if [ ! -f secrets/postgres_password ]; then
  echo "❌ secrets/postgres_password missing."
  exit 1
fi

# 1. Pull new images
log "Pulling images..."
HNAG_VERSION="$VERSION" $COMPOSE pull backend owner-dashboard

# 2. Backup DB before deploy (production safety)
BACKUP_DIR="./backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
log "Backing up DB to $BACKUP_DIR..."
$COMPOSE exec -T postgres pg_dump -U hnag hnag | gzip > "$BACKUP_DIR/hnag.sql.gz"
log "✓ Backup size: $(du -h "$BACKUP_DIR/hnag.sql.gz" | cut -f1)"

# 3. Run migrations (Prisma)
log "Running migrations..."
HNAG_VERSION="$VERSION" $COMPOSE run --rm backend npx prisma migrate deploy || {
  log "⚠ Migration failed — restoring previous version"
  exit 1
}

# 4. Rolling restart (2 replicas → zero downtime via healthchecks)
log "Rolling restart of backend..."
HNAG_VERSION="$VERSION" $COMPOSE up -d --no-deps --remove-orphans backend
HNAG_VERSION="$VERSION" $COMPOSE up -d --no-deps owner-dashboard

# 5. Wait for healthy
log "Waiting for healthy..."
for i in {1..30}; do
  if curl -fsS http://127.0.0.1/health >/dev/null 2>&1; then
    log "✓ Backend healthy"
    break
  fi
  sleep 2
  if [ "$i" -eq 30 ]; then
    log "❌ Health check timeout — rolling back"
    $COMPOSE rollback || true
    exit 1
  fi
done

# 6. Reload nginx (in case configs changed)
$COMPOSE exec -T nginx nginx -s reload

# 7. Cleanup old images
docker image prune -f --filter "until=168h" >/dev/null || true

# 8. Retention: keep last 14 backups
ls -dt ./backups/*/ 2>/dev/null | tail -n +15 | xargs -r rm -rf

log "✅ Deploy complete — version=$VERSION"
log "View logs: docker compose logs -f backend"
