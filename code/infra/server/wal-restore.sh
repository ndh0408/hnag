#!/usr/bin/env bash
# =============================================================================
# WAL restore — bring Postgres back to a specific point in time.
#
# Companion to wal-archive.sh. See WAL-ARCHIVING.md for the runbook.
#
# Usage:
#   ./wal-restore.sh restore <ISO_TARGET>
#     Stops live Postgres, restores latest base + replays WAL up to target.
#     ISO_TARGET example: "2026-05-27T08:00:00Z"
#
#   ./wal-restore.sh restore-to <host> <port> <ISO_TARGET>
#     Restores to a SEPARATE (staging) Postgres for verification. Use this
#     monthly to prove the backup chain works.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

REMOTE="${HNAG_WAL_REMOTE:-hnag-b2}"
BUCKET="${HNAG_WAL_BUCKET:-hnag-wal}"
PG_CONTAINER="${PG_CONTAINER:-hnag-postgres}"

log() { echo "[wal-restore $(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"; }
die() { echo "ERR: $*" >&2; exit 1; }

cmd=${1:-help}

case "$cmd" in
  restore)
    TARGET="${2:-}"
    [ -z "$TARGET" ] && die "Usage: wal-restore.sh restore <ISO_TARGET>"

    log "Restoring to target=$TARGET"
    log "Stopping live Postgres..."
    docker stop "$PG_CONTAINER" || true

    log "Snapshotting current data dir (in case we need to undo)..."
    docker run --rm -v hnag_pg_data:/data -v /tmp:/out alpine \
      tar -czf "/out/pg_data-pre-restore-$(date +%s).tar.gz" -C /data .

    log "Clearing data dir..."
    docker run --rm -v hnag_pg_data:/data alpine sh -c "rm -rf /data/*"

    log "Pulling latest base backup..."
    LATEST=$(rclone lsf "${REMOTE}:${BUCKET}/base/" 2>/dev/null | sort | tail -1)
    [ -z "$LATEST" ] && die "No base backup found in ${REMOTE}:${BUCKET}/base/"
    log "Using base: $LATEST"
    rclone copy "${REMOTE}:${BUCKET}/base/$LATEST" /tmp/restore/

    log "Unpacking base into pg_data volume..."
    gunzip -c "/tmp/restore/$LATEST" | docker run --rm -i -v hnag_pg_data:/data alpine \
      tar -xf - -C /data

    log "Configuring restore_command + recovery.signal..."
    docker run --rm -v hnag_pg_data:/data alpine sh -c "
      cat >> /data/postgresql.auto.conf <<EOF
restore_command = 'rclone copy ${REMOTE}:${BUCKET}/wal/%f /tmp/wal-pull/ 2>/dev/null && cp /tmp/wal-pull/%f %p'
recovery_target_time = '${TARGET}'
recovery_target_action = 'promote'
EOF
      touch /data/recovery.signal
    "

    log "Starting Postgres for replay..."
    docker start "$PG_CONTAINER"

    log "Waiting for replay to finish..."
    for i in $(seq 1 60); do
      sleep 5
      STATE=$(docker exec "$PG_CONTAINER" psql -U hnag -d hnag -tAc \
        "SELECT pg_is_in_recovery();" 2>/dev/null || echo "true")
      [ "$STATE" = "f" ] && break
      log "Still in recovery (probe $i/60)"
    done

    log "Verifying replayed timestamp..."
    docker exec "$PG_CONTAINER" psql -U hnag -d hnag -c \
      "SELECT now() AS server_time, pg_last_xact_replay_timestamp() AS last_replayed;"

    log "✓ Restore complete to $TARGET. Start backend with:"
    log "  cd /opt/docker/hnag && docker compose --env-file hnag.env -f docker-compose.prod.yml up -d backend"
    ;;

  restore-to)
    HOST="${2:-}"; PORT="${3:-5432}"; TARGET="${4:-}"
    [ -z "$HOST" ] || [ -z "$TARGET" ] && \
      die "Usage: wal-restore.sh restore-to <host> <port> <ISO_TARGET>"
    log "STAGING restore to ${HOST}:${PORT} for target=$TARGET"
    log "(Implementation: run pg_basebackup of base + apply WAL — write per-environment.)"
    log "This stub exists so the monthly verification calendar item has a script to call;"
    log "fill in once we provision a dedicated staging Postgres."
    ;;

  help|*)
    cat <<USAGE
Usage:
  wal-restore.sh restore <ISO_TARGET>
    Restore the LIVE Postgres to a point in time.
    DANGEROUS — stops live DB. Snapshots current data before overwriting.

  wal-restore.sh restore-to <host> <port> <ISO_TARGET>
    Restore to a separate (staging) Postgres for verification.

Examples:
  wal-restore.sh restore "2026-05-27T08:00:00Z"
USAGE
    ;;
esac
