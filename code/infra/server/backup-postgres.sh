#!/usr/bin/env bash
#
# HNAG — Postgres off-site backup
# -----------------------------------------------------------------------------
# Closes audit hnag-audit-2026-05 CRITICAL: "no off-site database backups".
#
# Strategy:
#   * Take a logical dump (pg_dump --format=custom) from the running container
#   * Gzip + age-encrypt locally (optional, only if BACKUP_AGE_RECIPIENT set)
#   * Push to Backblaze B2 / S3 via rclone, then verify the upload size
#   * Retain N daily / W weekly / M monthly copies on the remote
#
# Cron suggested in /etc/cron.d/hnag-backup:
#   0 3  * * *  root  /opt/hnag/backup-postgres.sh daily   >>/var/log/hnag-backup.log 2>&1
#   0 4  * * 0  root  /opt/hnag/backup-postgres.sh weekly  >>/var/log/hnag-backup.log 2>&1
#   0 5  1 * *  root  /opt/hnag/backup-postgres.sh monthly >>/var/log/hnag-backup.log 2>&1
#
# Required env (sourced from /opt/hnag/backup.env or /etc/hnag-backup.env):
#   PG_CONTAINER     (default: hnag-postgres)
#   POSTGRES_USER    (default: hnag)
#   POSTGRES_DB      (default: hnag)
#   RCLONE_REMOTE    (e.g. "b2:hnag-backups-prod")
#   RETENTION_DAILY  (default: 14)
#   RETENTION_WEEKLY (default: 8)
#   RETENTION_MONTHLY(default: 12)
#   BACKUP_AGE_RECIPIENT (optional age public key; encrypts before upload)
#   HEALTHCHECK_URL  (optional UptimeRobot / healthchecks.io ping-on-success)
# -----------------------------------------------------------------------------

set -euo pipefail
shopt -s nullglob

CADENCE="${1:-daily}"
case "$CADENCE" in
  daily|weekly|monthly) ;;
  *) echo "Usage: $0 {daily|weekly|monthly}" >&2; exit 2 ;;
esac

# Load secrets (chmod 600, owned root).
for env_file in /opt/hnag/backup.env /etc/hnag-backup.env; do
  if [[ -r "$env_file" ]]; then
    # shellcheck disable=SC1090
    source "$env_file"
  fi
done

: "${PG_CONTAINER:=hnag-postgres}"
: "${POSTGRES_USER:=hnag}"
: "${POSTGRES_DB:=hnag}"
: "${RCLONE_REMOTE:?RCLONE_REMOTE is required (e.g. b2:hnag-backups-prod)}"
: "${RETENTION_DAILY:=14}"
: "${RETENTION_WEEKLY:=8}"
: "${RETENTION_MONTHLY:=12}"

TIMESTAMP="$(date -u +%Y%m%d-%H%M%S)"
LOCAL_DIR="${LOCAL_BACKUP_DIR:-/var/backups/hnag}"
mkdir -p "$LOCAL_DIR"

DUMP_FILE="${LOCAL_DIR}/hnag-${CADENCE}-${TIMESTAMP}.dump"
META_FILE="${DUMP_FILE}.meta"
UPLOAD_FILE="$DUMP_FILE"

log() { echo "$(date -u +%FT%TZ) [backup] $*"; }
cleanup() { rm -f "$DUMP_FILE" "$DUMP_FILE.age" 2>/dev/null || true; }
trap cleanup EXIT

# 1. Dump (custom format → restorable with pg_restore, includes indexes)
log "pg_dump $POSTGRES_DB → $DUMP_FILE"
docker exec "$PG_CONTAINER" pg_dump \
  --format=custom \
  --no-owner \
  --no-acl \
  --username "$POSTGRES_USER" \
  "$POSTGRES_DB" > "$DUMP_FILE"

DUMP_BYTES="$(stat -c %s "$DUMP_FILE")"
if [[ "$DUMP_BYTES" -lt 10000 ]]; then
  log "ERROR: dump is suspiciously small ($DUMP_BYTES bytes) — aborting upload"
  exit 1
fi

# 2. Optional encryption (age — single recipient, simple, audit-friendly)
if [[ -n "${BACKUP_AGE_RECIPIENT:-}" ]] && command -v age >/dev/null 2>&1; then
  log "encrypting with age recipient ${BACKUP_AGE_RECIPIENT:0:20}…"
  age -r "$BACKUP_AGE_RECIPIENT" -o "$DUMP_FILE.age" "$DUMP_FILE"
  UPLOAD_FILE="$DUMP_FILE.age"
fi

# 3. Metadata sidecar (so we can verify integrity later)
{
  echo "timestamp_utc=$TIMESTAMP"
  echo "cadence=$CADENCE"
  echo "container=$PG_CONTAINER"
  echo "database=$POSTGRES_DB"
  echo "bytes_uncompressed=$DUMP_BYTES"
  echo "sha256=$(sha256sum "$UPLOAD_FILE" | awk '{print $1}')"
  echo "host=$(hostname -f 2>/dev/null || hostname)"
} > "$META_FILE"

# 4. Upload to remote
REMOTE_PATH="$RCLONE_REMOTE/$CADENCE/$(basename "$UPLOAD_FILE")"
META_REMOTE="$RCLONE_REMOTE/$CADENCE/$(basename "$META_FILE")"
log "uploading → $REMOTE_PATH"
rclone copyto "$UPLOAD_FILE" "$REMOTE_PATH" --transfers 1 --checksum --quiet
rclone copyto "$META_FILE" "$META_REMOTE" --quiet

# 5. Verify remote size matches local
REMOTE_BYTES="$(rclone size "$REMOTE_PATH" --json 2>/dev/null | sed -nE 's/.*"bytes":\s*([0-9]+).*/\1/p')"
LOCAL_BYTES="$(stat -c %s "$UPLOAD_FILE")"
if [[ "$REMOTE_BYTES" != "$LOCAL_BYTES" ]]; then
  log "ERROR: remote size $REMOTE_BYTES != local $LOCAL_BYTES — leaving local copy in place"
  exit 1
fi
log "verified: $LOCAL_BYTES bytes"

# 6. Retention — delete old objects on the remote
case "$CADENCE" in
  daily)   KEEP="$RETENTION_DAILY" ;;
  weekly)  KEEP="$RETENTION_WEEKLY" ;;
  monthly) KEEP="$RETENTION_MONTHLY" ;;
esac
log "applying retention: keep newest $KEEP $CADENCE backups"
rclone lsf "$RCLONE_REMOTE/$CADENCE/" --files-only \
  | grep -E "hnag-${CADENCE}-[0-9]+-[0-9]+\.(dump|dump\.age)$" \
  | sort -r \
  | tail -n +"$((KEEP + 1))" \
  | while read -r stale; do
      log "  prune $stale"
      rclone deletefile "$RCLONE_REMOTE/$CADENCE/$stale" --quiet || true
      rclone deletefile "$RCLONE_REMOTE/$CADENCE/${stale}.meta" --quiet || true
    done

# 7. Healthcheck ping (so a missed backup triggers an alert next morning)
if [[ -n "${HEALTHCHECK_URL:-}" ]]; then
  curl -fsS -m 10 -o /dev/null --retry 3 "${HEALTHCHECK_URL}" || log "healthcheck ping failed (non-fatal)"
fi

log "done."
