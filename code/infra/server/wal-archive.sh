#!/usr/bin/env bash
# =============================================================================
# WAL archiving + base backup → Backblaze B2.
#
# Closes incident-readiness gap: daily pg_dump RPO of 24h is too lossy for
# a payment-processing app. With WAL archiving, RPO drops to the cron
# cadence (1 min by default).
#
# Architecture:
#   - Base backup (full pg cluster) runs nightly at 02:00 UTC. Uses
#     pg_basebackup so it's online + crash-consistent.
#   - WAL push every minute via `push-current`: rsync any new completed
#     16MB WAL segment from the volume to B2.
#
# Usage:
#   ./wal-archive.sh init          One-time: bootstrap pgbackrest stanza
#   ./wal-archive.sh base          Take a base backup (cron: nightly)
#   ./wal-archive.sh push-current  Push completed WAL segments (cron: 1m)
#   ./wal-archive.sh status        Show retention + last successful backup
#
# Required:
#   - rclone configured with remote `hnag-b2` (`rclone config create ...`)
#   - B2 bucket `hnag-wal` (create via B2 dashboard)
#   - Postgres `archive_mode=on` + `archive_command` pointing here
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

REMOTE="${HNAG_WAL_REMOTE:-hnag-b2}"
BUCKET="${HNAG_WAL_BUCKET:-hnag-wal}"
PG_CONTAINER="${PG_CONTAINER:-hnag-postgres}"
LOCAL_BASE_DIR="${LOCAL_BASE_DIR:-./backups/wal}"

log() { echo "[wal-archive $(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"; }
die() { echo "ERR: $*" >&2; exit 1; }

require() {
  command -v "$1" >/dev/null 2>&1 || die "$1 not installed"
}

verify_remote() {
  rclone listremotes 2>/dev/null | grep -q "^${REMOTE}:$" \
    || die "rclone remote '${REMOTE}' not configured. Run: rclone config create ${REMOTE} b2 ..."
}

cmd=${1:-status}

case "$cmd" in
  init)
    require rclone
    verify_remote
    log "Initial bucket check — ${REMOTE}:${BUCKET}"
    rclone mkdir "${REMOTE}:${BUCKET}" 2>&1 | tail -3 || true
    rclone mkdir "${REMOTE}:${BUCKET}/base" 2>&1 | tail -3 || true
    rclone mkdir "${REMOTE}:${BUCKET}/wal"  2>&1 | tail -3 || true
    log "Initial base backup..."
    "$0" base
    log "Configured. Add cron entries to /etc/cron.d/hnag-wal-archive (MUST run as root —"
    log "the WAL volume at /var/lib/docker/volumes/* is root:root and unreadable to non-root):"
    cat <<CRON
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
RCLONE_CONFIG=/home/huy/.config/rclone/rclone.conf
MAILTO=""

*/1 * * * * root /opt/docker/hnag/wal-archive.sh push-current >> /opt/docker/hnag/logs/wal-push.log 2>&1
0 2 * * * root /opt/docker/hnag/wal-archive.sh base >> /opt/docker/hnag/logs/wal-base.log 2>&1
CRON
    ;;

  base)
    require rclone
    verify_remote
    mkdir -p "$LOCAL_BASE_DIR"
    STAMP=$(date -u +%Y%m%dT%H%M%SZ)
    OUT="$LOCAL_BASE_DIR/base-${STAMP}.tar.gz"
    log "Taking base backup → $OUT"
    # pg_basebackup writes a tar stream. We pipe through gzip + tee to file.
    # The `-X stream` flag includes the WAL segments needed to start the
    # restore. Postgres remains online.
    # `-X fetch` (not stream) is required when piping tar to stdout — postgres
    # refuses `-X stream` + `-Ft` + stdout combination ("cannot stream
    # write-ahead logs in tar mode to stdout"). fetch is fine at our scale
    # because WAL won't recycle in the seconds the backup takes.
    docker exec "$PG_CONTAINER" pg_basebackup \
      -U hnag -D - -Ft -z -X fetch -P 2>&1 | gzip -c > "$OUT"
    SIZE=$(du -h "$OUT" | cut -f1)
    log "Base size: $SIZE — uploading to B2"
    # `--b2-versions` is a *download* flag (it makes hidden versions visible);
    # using it on `copy` errors out with "can't modify or delete files in
    # --b2-versions mode". We just want the latest upload — drop the flag.
    rclone copy "$OUT" "${REMOTE}:${BUCKET}/base/" \
      --transfers=4 --stats-one-line 2>&1 | tail -5
    # Local retention: keep 3 most recent (B2 handles long-term)
    ls -t "$LOCAL_BASE_DIR"/base-*.tar.gz 2>/dev/null | tail -n +4 | xargs -r rm -v
    log "✓ Base backup ${STAMP} complete"
    ;;

  push-current)
    # Postgres writes filled WAL segments to pg_wal (formerly pg_xlog).
    # archive_command should `cp` them to a host-mounted dir; this script
    # syncs that dir to B2 every minute.
    #
    # The volume mount in docker-compose.prod.yml is `pg_wal_archive:/var/lib/postgresql/wal_archive`.
    # We rsync from the docker volume mount on the host.
    require rclone
    verify_remote
    VOLUME_PATH=$(docker volume inspect hnag_pg_wal_archive --format '{{ .Mountpoint }}' 2>/dev/null || echo "")
    if [ -z "$VOLUME_PATH" ] || [ ! -d "$VOLUME_PATH" ]; then
      log "WAL archive volume not yet provisioned — run after first archive_command fires"
      exit 0
    fi
    # Sync new files only; never re-upload already-shipped segments.
    rclone copy "$VOLUME_PATH" "${REMOTE}:${BUCKET}/wal/" \
      --immutable --transfers=8 --no-traverse --stats=10s --stats-one-line 2>&1 | tail -3
    # Clean local segments that have safely landed in B2 (older than 5 min
    # so we never delete one mid-flight). pgbackrest equivalent would do
    # this via `repo-retention-archive`.
    find "$VOLUME_PATH" -name '*.partial' -prune -o -mmin +5 -name '0*' -delete 2>/dev/null || true
    ;;

  status)
    require rclone
    verify_remote
    log "Bucket: ${REMOTE}:${BUCKET}"
    echo "--- last base backups ---"
    rclone lsf "${REMOTE}:${BUCKET}/base/" 2>/dev/null | sort | tail -7
    echo "--- WAL segment count ---"
    rclone size "${REMOTE}:${BUCKET}/wal/" 2>/dev/null | head
    echo "--- local archive volume ---"
    VOLUME_PATH=$(docker volume inspect hnag_pg_wal_archive --format '{{ .Mountpoint }}' 2>/dev/null || echo "(not provisioned)")
    echo "$VOLUME_PATH"
    if [ -d "$VOLUME_PATH" ]; then
      echo "  recent segments:"
      ls -la "$VOLUME_PATH" 2>/dev/null | tail -5
    fi
    ;;

  *)
    die "unknown command: $cmd. Try: init | base | push-current | status"
    ;;
esac
