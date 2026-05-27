#!/usr/bin/env bash
#
# HNAG — Postgres restore-drill
# -----------------------------------------------------------------------------
# A backup you have never restored is not a backup. This script downloads the
# latest off-site daily dump, restores it into a throwaway container, and runs
# a smoke-test query to prove the data is intact. Run monthly via cron.
#
# Cron suggested in /etc/cron.d/hnag-backup:
#   0 6 1 * *  root  /opt/hnag/restore-postgres-test.sh  >>/var/log/hnag-restore-drill.log 2>&1
#
# Required env (sourced from /opt/hnag/backup.env):
#   RCLONE_REMOTE          e.g. b2:hnag-backups-prod
#   POSTGRES_USER          default: hnag
#   POSTGRES_DB            default: hnag
#   POSTGRES_PASSWORD      a fresh password for the throwaway container
#   BACKUP_AGE_IDENTITY    path to age private key, if dumps are encrypted
#   HEALTHCHECK_RESTORE_URL optional success ping
# -----------------------------------------------------------------------------

set -euo pipefail

for env_file in /opt/hnag/backup.env /etc/hnag-backup.env; do
  if [[ -r "$env_file" ]]; then
    # shellcheck disable=SC1090
    source "$env_file"
  fi
done

: "${RCLONE_REMOTE:?RCLONE_REMOTE required}"
: "${POSTGRES_USER:=hnag}"
: "${POSTGRES_DB:=hnag}"
: "${POSTGRES_PASSWORD:=$(openssl rand -hex 16)}"

CONTAINER="hnag-restore-drill-$$"
WORKDIR="$(mktemp -d /tmp/hnag-restore.XXXXXX)"
log() { echo "$(date -u +%FT%TZ) [restore-drill] $*"; }
cleanup() {
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

# 1. Find the newest daily backup on the remote
log "locating newest daily backup on $RCLONE_REMOTE/daily/"
LATEST="$(rclone lsf "$RCLONE_REMOTE/daily/" --files-only \
  | grep -E 'hnag-daily-[0-9]+-[0-9]+\.(dump|dump\.age)$' \
  | sort -r | head -1)"
if [[ -z "$LATEST" ]]; then
  log "ERROR: no daily backups found"
  exit 1
fi
log "newest = $LATEST"

# 2. Download
rclone copyto "$RCLONE_REMOTE/daily/$LATEST" "$WORKDIR/$LATEST" --quiet
DUMP_FILE="$WORKDIR/$LATEST"

# 3. Decrypt if needed
if [[ "$LATEST" == *.age ]]; then
  : "${BACKUP_AGE_IDENTITY:?Encrypted dump but BACKUP_AGE_IDENTITY missing}"
  log "decrypting…"
  age -d -i "$BACKUP_AGE_IDENTITY" -o "${DUMP_FILE%.age}" "$DUMP_FILE"
  DUMP_FILE="${DUMP_FILE%.age}"
fi

# 4. Spin a disposable Postgres
log "starting throwaway postgres container $CONTAINER"
docker run -d --rm \
  --name "$CONTAINER" \
  -e POSTGRES_USER="$POSTGRES_USER" \
  -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
  -e POSTGRES_DB="$POSTGRES_DB" \
  -v "$WORKDIR":/dump \
  postgres:16-alpine >/dev/null

# Wait for readiness
for _ in $(seq 1 60); do
  if docker exec "$CONTAINER" pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
docker exec "$CONTAINER" pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null

# 5. Restore
log "pg_restore (this may take a few minutes)…"
docker exec "$CONTAINER" pg_restore \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" \
  --clean --if-exists --no-owner --no-acl \
  "/dump/$(basename "$DUMP_FILE")" || {
    log "ERROR: pg_restore failed"
    exit 1
  }

# 6. Smoke-test queries (counts > 0 prove the data is real, not an empty schema)
log "running smoke-test queries"
SMOKE="$(docker exec "$CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -At -c "
  SELECT (SELECT COUNT(*) FROM users)      AS users,
         (SELECT COUNT(*) FROM restaurants) AS restaurants,
         (SELECT COUNT(*) FROM foods)      AS foods;
")"
log "smoke: $SMOKE"

USERS_COUNT="$(echo "$SMOKE" | awk -F'|' '{print $1}')"
REST_COUNT="$(echo "$SMOKE" | awk -F'|' '{print $2}')"
if [[ -z "$REST_COUNT" || "$REST_COUNT" -lt 1000 ]]; then
  log "ERROR: restaurant count $REST_COUNT < 1000 — backup looks suspect"
  exit 1
fi

log "RESTORE DRILL OK — restaurants=$REST_COUNT users=$USERS_COUNT"
if [[ -n "${HEALTHCHECK_RESTORE_URL:-}" ]]; then
  curl -fsS -m 10 -o /dev/null --retry 3 "${HEALTHCHECK_RESTORE_URL}" || true
fi
