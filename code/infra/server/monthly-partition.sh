#!/usr/bin/env bash
# =============================================================================
# Create next month's events_archive partition.
# -----------------------------------------------------------------------------
# sql/08_hardening.sql pre-creates partitions through 2027_01 + a DEFAULT
# partition catch-all. This script keeps the chain extending: on the 25th
# of every month it creates the partition for two months ahead so there's
# always a non-default partition ready before the new month starts.
#
# Cron entry (/etc/cron.d/hnag-partition):
#   0 5 25 * * huy /opt/docker/hnag/monthly-partition.sh >> /opt/docker/hnag/logs/partition.log 2>&1
#
# Idempotent: CREATE TABLE IF NOT EXISTS makes re-runs safe.
# =============================================================================

set -euo pipefail
LOG_TAG="[partition-create $(date -u +%Y-%m-%dT%H:%M:%SZ)]"
log() { echo "$LOG_TAG $*"; }

# Target: 2 months from now (e.g. on 2027-01-25 we create 2027_03).
TARGET_YEAR_MONTH=$(date -u -d "+2 months" +%Y_%m)
TARGET_START=$(date -u -d "+2 months" +%Y-%m-01)
TARGET_END=$(date -u -d "+3 months" +%Y-%m-01)

log "Ensuring events_archive_${TARGET_YEAR_MONTH} (range ${TARGET_START} → ${TARGET_END})"

docker exec -i hnag-postgres psql -U hnag -d hnag -v ON_ERROR_STOP=1 <<SQL
CREATE TABLE IF NOT EXISTS events_archive_${TARGET_YEAR_MONTH}
  PARTITION OF events_archive
  FOR VALUES FROM ('${TARGET_START}') TO ('${TARGET_END}');
SQL

log "✓ Partition events_archive_${TARGET_YEAR_MONTH} ensured"
