# HNAG Self-hosted Deployment

> Production stack chạy trên 1 Linux server (Ubuntu 22.04+) qua Docker Compose.
> Target: **ServerLinux** (`100.100.210.85` Tailscale, user `huy`).
>
> Đây là path Series-A pre-launch — rẻ + đủ scale cho 100K MAU. Chuyển lên Kubernetes/AWS sau khi đạt traction.

---

## Stack

| Service | Image | Purpose |
|---|---|---|
| postgres | postgis/postgis:15-3.4 | Database + spatial queries |
| redis | redis:7-alpine | Cache + pub/sub + queues |
| backend | ghcr.io/.../hnag-backend | NestJS API (2 replicas) |
| owner-dashboard | ghcr.io/.../hnag-owner-dashboard | Next.js dashboard |
| nginx | nginx:1.27-alpine | TLS + reverse proxy |
| certbot | certbot/certbot | Auto-renew Let's Encrypt |
| dozzle | amir20/dozzle | Web log viewer (Tailscale-only) |
| watchtower | containrrr/watchtower | Auto-update labeled containers |

## One-time server setup

```bash
ssh ServerLinux
sudo bash <(curl -fsSL https://raw.githubusercontent.com/<owner>/<repo>/main/code/infra/server/bootstrap.sh)
# OR copy bootstrap.sh manually and: sudo bash bootstrap.sh
```

Then:
```bash
mkdir -p /opt/hnag/{secrets,init,certs}
cp /path/to/repo/code/sql/{01_schema.sql,02_seed_data.sql} /opt/hnag/init/
cp /path/to/repo/code/infra/server/* /opt/hnag/
cd /opt/hnag
cp hnag.env.example hnag.env
nano hnag.env   # fill all secrets

# Initial TLS issuance (only first time)
docker compose -f docker-compose.prod.yml up -d nginx
docker compose -f docker-compose.prod.yml run --rm certbot certonly \
  --webroot --webroot-path /var/www/certbot \
  -d api.tothanhthuy.cloud -d dash.tothanhthuy.cloud \
  --email ops@tothanhthuy.cloud --agree-tos --non-interactive

./deploy.sh latest
```

## Deploy on push to main

GitHub Action `.github/workflows/server-deploy.yml`:
- Triggered after `Backend · CI` success on `main`
- SSHes to `ServerLinux` via Tailscale OAuth
- Runs `deploy.sh` which: pulls image → backs up DB → migrates → rolling restart → smoke test

Secrets required in GitHub repo:
- `TS_OAUTH_CLIENT_ID`, `TS_OAUTH_SECRET` — Tailscale OAuth client for runner
- `SERVER_SSH_KEY` — private key for `huy@ServerLinux` (read-only deploy key)
- `GHCR_TOKEN` — for `docker login ghcr.io` on server

## Manual operations

```bash
# Tail logs
docker compose -f /opt/hnag/docker-compose.prod.yml logs -f backend

# psql shell
docker compose -f /opt/hnag/docker-compose.prod.yml exec postgres psql -U hnag hnag

# Redis CLI
docker compose -f /opt/hnag/docker-compose.prod.yml exec redis redis-cli

# Manual backup
cd /opt/hnag && ./deploy.sh skip-deploy-just-backup    # or just: docker exec ... pg_dump

# Rollback to previous image
docker compose -f /opt/hnag/docker-compose.prod.yml down
HNAG_VERSION=<previous-sha> docker compose -f docker-compose.prod.yml up -d
```

## Sizing recommendations

| Stage | RAM | CPU | Disk | Bandwidth |
|---|---|---|---|---|
| Pre-launch (<10K MAU) | 8 GB | 4 vCPU | 100 GB SSD | 1 TB/mo |
| Early (10–100K MAU)   | 16 GB | 8 vCPU | 250 GB | 5 TB/mo |
| Growth (>100K MAU) | move to multi-server / Kubernetes |

## Monitoring

- **Logs**: `dozzle` at `http://localhost:9999` (SSH-forward or Tailscale)
- **Metrics**: container resource via `docker stats`
- **DB**: `pg_stat_statements` already enabled
- **Uptime**: external monitor (UptimeRobot / Better Stack) pinging `/health`

## Backup policy

- Pre-deploy automatic backups in `./backups/YYYYMMDD-HHMMSS/hnag.sql.gz`
- Retention: last 14
- Off-site: cron job `rclone copy backups/ b2:hnag-backups-prod/` daily
- Test restore monthly
