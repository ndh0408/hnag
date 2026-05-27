# HNAG Production Deploy Runbook (ServerLinux / self-host)

> Last updated: 2026-05-27 (audit-hardening deploy `e03ba10`).
> All commands assume SSH alias `ServerLinux` is configured locally.

## 1. Architecture in 30 seconds

```
client → Cloudflare Edge → cloudflared tunnel → hnag-backend:4000
                                              → hnag-owner-dashboard:3000
                                              → hnag-static (nginx, app.tothanhthuy.cloud)
```

No public ports on the VM. Cloudflare Tunnel terminates TLS and routes by Host header. The `nginx.conf` file in this directory documents a topology used by other deploys; the live VM does NOT run nginx for the API.

## 2. Container inventory

| Container | Image | Role |
| --- | --- | --- |
| `hnag-postgres` | `postgis/postgis:15-3.4` | Primary DB |
| `hnag-redis` | `redis:7-alpine` | Cache + queues + sessions (AOF on, volatile-lru) |
| `hnag-backend` | `hnag-backend:local` (built on server) | NestJS API |
| `hnag-owner-dashboard` | `hnag-owner-dashboard:local` | Next.js admin |
| `hnag-static` | `nginx:1.27-alpine` | APK/IPA file server at app.tothanhthuy.cloud |
| `hnag-cloudflared` | `cloudflare/cloudflared:latest` | Tunnel ingress |
| `hnag-postgres-backup` | `prodrigestivill/postgres-backup-local:16` | Daily 03:00 UTC pg_dump |

## 3. Routine deploy (code change → live)

```bash
ssh ServerLinux

# 0. Pre-flight: snapshot DB before any risky deploy
cd /opt/docker/hnag
BACKUP_DIR="./backups/pre-deploy-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
docker exec -i hnag-postgres pg_dump -U hnag hnag | gzip > "$BACKUP_DIR/hnag.sql.gz"

# 1. Pull latest main + sync source
cd /tmp/hnag-deploy/hnag && git pull --ff-only
rsync -a --delete \
  --exclude=node_modules --exclude=dist \
  /tmp/hnag-deploy/hnag/code/backend/ /opt/docker/hnag/build/backend/

# 2. Build new image
cd /opt/docker/hnag/build/backend
docker build -t hnag-backend:local .

# 3. Apply any new SQL migrations idempotently
for f in /tmp/hnag-deploy/hnag/code/sql/*.sql; do
  echo "=== $f ==="
  docker exec -i hnag-postgres psql -U hnag -d hnag -v ON_ERROR_STOP=1 -f - < "$f"
done

# 4. Restart backend (must include --env-file because compose interpolates
#    ${POSTGRES_PASSWORD} — without --env-file the password is empty and
#    Prisma crash-loops with P1000. See memory hnag-server-compose-env-gotcha.)
cd /opt/docker/hnag
docker compose --env-file hnag.env -f docker-compose.prod.yml up -d --force-recreate backend

# 5. Verify
sleep 15
docker ps --filter 'name=hnag-backend' --format '{{.Status}}'
docker exec hnag-backend wget -qO- http://localhost:4000/health
```

## 4. Apply a SQL migration without restart

```bash
ssh ServerLinux 'docker exec -i hnag-postgres psql -U hnag -d hnag -v ON_ERROR_STOP=1' \
  < code/sql/NN_migration.sql
```

All migrations are idempotent (`CREATE INDEX IF NOT EXISTS`, `DO $$ BEGIN ... IF NOT EXISTS ...`).

## 5. Rollback a backend deploy

```bash
ssh ServerLinux
cd /opt/docker/hnag

# Option A: rebuild from a prior commit
cd /tmp/hnag-deploy/hnag && git checkout <prev-sha>
rsync -a --delete --exclude=node_modules --exclude=dist /tmp/hnag-deploy/hnag/code/backend/ /opt/docker/hnag/build/backend/
cd /opt/docker/hnag/build/backend && docker build -t hnag-backend:local .
cd /opt/docker/hnag && docker compose --env-file hnag.env -f docker-compose.prod.yml up -d --force-recreate backend

# Option B (faster): keep a tagged prior image
docker tag hnag-backend:local hnag-backend:rollback-$(date +%Y%m%d-%H%M%S)
# … then later …
docker tag hnag-backend:rollback-20260527-061107 hnag-backend:local
cd /opt/docker/hnag && docker compose --env-file hnag.env up -d --force-recreate backend
```

## 6. Restore DB from postgres-backup

```bash
ssh ServerLinux

# 1. Find the snapshot
docker exec hnag-postgres-backup ls -lh /backups/daily/

# 2. Copy it out + stop API to prevent writes during restore
docker cp hnag-postgres-backup:/backups/daily/hnag-2026-05-27.sql.gz /tmp/
docker compose --env-file hnag.env -f docker-compose.prod.yml stop backend owner-dashboard

# 3. Drop + restore (destructive — be sure)
docker exec -i hnag-postgres psql -U hnag -d postgres -c 'DROP DATABASE hnag;'
docker exec -i hnag-postgres psql -U hnag -d postgres -c 'CREATE DATABASE hnag;'
gunzip -c /tmp/hnag-2026-05-27.sql.gz | docker exec -i hnag-postgres psql -U hnag -d hnag

# 4. Start API back up
docker compose --env-file hnag.env -f docker-compose.prod.yml up -d backend owner-dashboard
```

## 7. Promote a user to admin

```bash
ssh ServerLinux "docker exec -i hnag-postgres psql -U hnag -d hnag -c \
  \"UPDATE users SET role='super_admin' WHERE email='someone@example.com';\""
```

Roles: `user | owner | creator | moderator | support | admin | super_admin`. RolesGuard reads live on every request (no JWT re-sign needed).

## 8. Cron jobs

```
/etc/cron.d/hnag-maintenance
  0 4 * * * huy /opt/docker/hnag/offsite-backup.sh   # daily 04:00 UTC → B2
  0 5 25 * * huy /opt/docker/hnag/monthly-partition.sh  # 25th of each month
```

The `postgres-backup` CONTAINER schedules its own daily dump at 03:00 UTC.

## 9. Audit-hardening env vars (set on this server 2026-05-27)

```
TRUST_PROXY_DEPTH=1               # cloudflared is the only proxy hop
OPENAI_DAILY_HARD_CAP_USD=50      # kill switch when org daily spend exceeded
MODERATION_IMAGE_MODEL=omni-moderation-latest
PRISMA_QUERY_LOG=false            # flip true while investigating latency
SLOW_QUERY_MS_THRESHOLD=200
SLOW_QUERY_BLOCK_MS=2000
```

## 10. Offsite backup setup (one-time, manual)

The `offsite-backup.sh` script is committed but inert until rclone is
configured. To activate:

```bash
ssh ServerLinux

# 1. Install rclone if missing
sudo apt install -y rclone

# 2. Configure Backblaze B2 remote (interactive)
rclone config
# → choose New remote → name=hnag-b2 → storage=b2
# → application key id + key from B2 dashboard
# → bucket name e.g. hnag-backups-offsite (created in B2 first)

# 3. Test
/opt/docker/hnag/offsite-backup.sh
```

## 11. Known gotchas

- `docker compose up` WITHOUT `--env-file hnag.env` interpolates
  `${POSTGRES_PASSWORD}` to empty string → Prisma P1000 crash loop. See
  memory `hnag-server-compose-env-gotcha`.
- BullMQ queue names cannot contain `:` (rejected at v5). Queues are now
  `otp-email`, `push-fcm`.
- Apple Sign-In requires bundle id env var `APPLE_BUNDLE_ID=vn.hnag.hnag`.
- pgvector is NOT available in `postgis/postgis:15-3.4` — vector search
  paths are guarded with `DO $$ ... pg_available_extensions ...` and skip
  cleanly if unavailable.
