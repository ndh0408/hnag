# WAL Archiving + PITR for HNAG Postgres

Closes audit incident-readiness gap "RPO 24h is unacceptable for a
payment-processing app". After this is wired:

- **RPO**: ~60 seconds (WAL segments shipped to B2 every minute)
- **RTO**: ~15-30 minutes (restore base + replay WAL to target time)
- **Restore granularity**: any point in time within retention window

This document is the source-of-truth runbook. The actual containers +
scripts ship in `docker-compose.prod.yml` (the `postgres-wal-archive`
service) and `wal-restore.sh`.

## How it works

Postgres has built-in WAL (write-ahead log). Every change to the DB
writes a record to a WAL segment (16MB each) BEFORE the data files
update. With `archive_mode=on + archive_command`, Postgres ships each
filled segment to a script that pushes it to B2.

Restore process:
1. Pull latest `base_backup.tar.gz` from B2 → unpack to fresh pg_data
2. Set `recovery.conf` (Postgres 15+: `recovery.signal` file) pointing
   at our `restore_command` that pulls WAL from B2
3. Start Postgres → it replays WAL until target time, then promotes

## Setup (one-time)

```bash
ssh ServerLinux

# 1. Install pgbackrest binary (we use the official container so this is
#    inside the Postgres image extension at runtime — pgbackrest is bundled).
#    Verify:
docker exec hnag-postgres which pgbackrest 2>/dev/null || \
  echo "pgbackrest not in base image — using a sidecar container"

# 2. Configure rclone (one-time, B2 credentials)
sudo apt install -y rclone
rclone config create hnag-b2 b2 \
  account=<B2_KEY_ID> \
  key=<B2_APP_KEY> \
  hard_delete=true

# 3. Initial base backup + cron install
/opt/docker/hnag/wal-archive.sh init

# 4. Drop the cron file shown by `init` into /etc/cron.d/hnag-wal-archive
#    (the entries MUST run as root — see "Daily base backup" section).
```

## Operations

### Daily base backup

Runs automatically via cron at `/etc/cron.d/hnag-wal-archive`. **Must run as
root** — the postgres WAL volume (`/var/lib/docker/volumes/hnag_pg_wal_archive`)
is owned by root inside docker and the script needs to read it directly:

```
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
RCLONE_CONFIG=/home/huy/.config/rclone/rclone.conf
MAILTO=""

*/1 * * * * root /opt/docker/hnag/wal-archive.sh push-current >> /opt/docker/hnag/logs/wal-push.log 2>&1
0 2 * * * root /opt/docker/hnag/wal-archive.sh base >> /opt/docker/hnag/logs/wal-base.log 2>&1
```

### Postgres archive_command pre-flight

`archive_mode=on` + `archive_command` must be set in `postgresql.conf` (we
bake this into the postgres init scripts). If you ever see `failed_count`
in `pg_stat_archiver` climbing, the most common cause is the bind-mounted
archive dir is root-owned but postgres runs as user `postgres`. Fix once:

```bash
docker exec -u root hnag-postgres chown postgres:postgres /var/lib/postgresql/wal_archive
docker exec hnag-postgres psql -U hnag -d hnag -c "SELECT pg_stat_reset_shared('archiver');"
```

### Restore to a point in time

```bash
ssh ServerLinux

# Find the target time you want to restore to (UTC ISO 8601)
TARGET="2026-05-27T08:00:00Z"

# Stop the live backend so no new writes happen during restore
cd /opt/docker/hnag
docker compose --env-file hnag.env -f docker-compose.prod.yml stop backend

# Backup current data dir (just in case)
docker exec hnag-postgres pg_dumpall -U hnag > /tmp/pre-restore-$(date +%s).sql

# Run the restore script — it stops postgres, restores base, sets
# restore_command, restarts, waits for replay to TARGET, promotes
/opt/docker/hnag/wal-restore.sh restore "$TARGET"

# Verify the restore landed at the right time
docker exec hnag-postgres psql -U hnag -d hnag -c \
  "SELECT now() AS server_time, pg_last_xact_replay_timestamp() AS replayed;"

# Start backend
docker compose --env-file hnag.env -f docker-compose.prod.yml up -d backend
```

### Retention

B2 lifecycle rule retains:
- Last 7 base backups (one per day → 7 days)
- Last 14 days of WAL segments

Older are auto-pruned by B2 lifecycle (configured in dashboard).

## Verification (monthly)

Restore to a staging Postgres + run smoke queries:

```bash
# On a separate VM or local docker
docker run --name pg-restore-test -e POSTGRES_PASSWORD=test \
  -v $(mktemp -d):/var/lib/postgresql/data \
  -d postgis/postgis:15-3.4

# Use wal-restore.sh in --target-host mode (see script)
/opt/docker/hnag/wal-restore.sh restore-to localhost 5432 "2026-05-26T12:00:00Z"

# Smoke: count rows in key tables; verify timestamps make sense
docker exec pg-restore-test psql -U hnag -d hnag -c \
  "SELECT 'users' as t, count(*) FROM users
   UNION ALL SELECT 'foods', count(*) FROM foods
   UNION ALL SELECT 'restaurants', count(*) FROM restaurants;"
```

Schedule this in calendar — quarterly minimum, monthly ideal.
