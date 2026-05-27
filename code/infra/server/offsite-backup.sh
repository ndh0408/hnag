#!/usr/bin/env bash
# =============================================================================
# Offsite backup → Backblaze B2 (or S3-compatible).
# -----------------------------------------------------------------------------
# Closes the second half of audit #40: local pg_dump in pg_backups volume is
# necessary but not sufficient — a disk failure or full server compromise
# wipes both prod data AND backups. This script ships the latest daily dump
# off-server.
#
# Requires:
#   - rclone configured with a remote named "hnag-b2" pointing at Backblaze B2:
#       rclone config create hnag-b2 b2 account=<KEY_ID> key=<APP_KEY>
#   - destination bucket exists (e.g. hnag-backups-offsite)
#   - this script in /opt/docker/hnag/ ; called by cron daily 04:00 UTC
#     (1h after postgres-backup container runs at 03:00)
#
# Cron entry (/etc/cron.d/hnag-offsite-backup):
#   0 4 * * * huy /opt/docker/hnag/offsite-backup.sh >> /opt/docker/hnag/logs/offsite.log 2>&1
#
# Retention: rclone --b2-versions keeps prior versions per Backblaze settings;
# we only sync the "daily" subdir (7 latest). Weekly/monthly snapshots stay
# local to save bandwidth. To restore: pull from B2, gunzip, pg_restore.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

LOG_TAG="[offsite-backup $(date -u +%Y-%m-%dT%H:%M:%SZ)]"
log() { echo "$LOG_TAG $*"; }

# -----------------------------------------------------------------------------
# 1. Sanity checks
# -----------------------------------------------------------------------------
if ! command -v rclone >/dev/null 2>&1; then
  log "ERROR: rclone not installed. apt install rclone (or curl -fsSL https://rclone.org/install.sh | sudo bash)"
  exit 1
fi

REMOTE="${HNAG_B2_REMOTE:-hnag-b2}"
BUCKET="${HNAG_B2_BUCKET:-hnag-backups-offsite}"

if ! rclone listremotes 2>/dev/null | grep -q "^${REMOTE}:$"; then
  log "ERROR: rclone remote '${REMOTE}' not configured. Run:"
  log "       rclone config create ${REMOTE} b2 account=<B2_KEY_ID> key=<B2_APP_KEY>"
  exit 1
fi

# -----------------------------------------------------------------------------
# 2. Pull the latest dump out of the postgres-backup volume.
# -----------------------------------------------------------------------------
# The prodrigestivill image keeps the most recent backup at
# /backups/last/hnag-latest.sql.gz inside the container's volume. We snapshot
# the daily/ subdir which holds the 7 retention slots; B2 versioning + 30d
# lifecycle does the rest.
LOCAL_DUMP_DIR=$(mktemp -d -t hnag-backup-XXXXXX)
trap "rm -rf '$LOCAL_DUMP_DIR'" EXIT

log "Copying daily dumps out of postgres-backup volume..."
docker cp hnag-postgres-backup:/backups/daily/. "$LOCAL_DUMP_DIR/" 2>&1 | tail -5

COUNT=$(find "$LOCAL_DUMP_DIR" -type f -name '*.sql.gz' | wc -l)
if [ "$COUNT" -eq 0 ]; then
  log "ERROR: no .sql.gz files found in /backups/daily/. Has postgres-backup run yet?"
  exit 2
fi
log "Found $COUNT daily snapshot(s) totaling $(du -sh "$LOCAL_DUMP_DIR" | cut -f1)"

# -----------------------------------------------------------------------------
# 3. Sync to B2.
# -----------------------------------------------------------------------------
DEST="${REMOTE}:${BUCKET}/postgres/daily"
log "Syncing → ${DEST}"
rclone sync "$LOCAL_DUMP_DIR" "${DEST}" \
  --transfers=4 \
  --b2-versions \
  --b2-hard-delete=false \
  --log-level INFO \
  --stats=15s \
  --stats-one-line 2>&1 | tail -20

# -----------------------------------------------------------------------------
# 4. (Optional) Sanity-check by reading back a manifest.
# -----------------------------------------------------------------------------
log "Remote listing:"
rclone lsf "${DEST}" 2>&1 | head -10

log "✓ Offsite backup complete."
