# HNAG — Incident Runbook

> What to do when something is on fire at 2am. Pair with the live
> [99-PRODUCTION-READINESS.md](99-PRODUCTION-READINESS.md) tracker and
> [ARCHITECTURE.md](ARCHITECTURE.md) for system context.

Production lives on a single host (memory `hnag-deploy-server`):
`ServerLinux` (Tailscale `TAILNET_HOST`, user `huy`). SSH via the
alias `ServerLinux`. Cloudflare tunnel fronts `api.tothanhthuy.cloud`.

---

## 0. First 90 seconds — triage

1. **Confirm the symptom.** Open https://api.tothanhthuy.cloud/health
   in a browser. Note which sub-checks are red:
   - `db: false` → §1 Postgres down
   - `cache: false` → §2 Redis down
   - `queues.<x>.failed > 0` → §3 queue stuck
   - `ok: false` but everything green → §8 partial degradation
   - whole endpoint 5xx → §7 process crashed / container OOM
2. **Check `/metrics`.** Latency spike? Memory near limit? Spend spiked?
3. **`ssh ServerLinux` then `docker ps`.** Are all expected containers
   running? Restart count growing?
4. **`docker logs --tail 200 -f hnag-backend`** — most incidents announce
   themselves in the last 200 lines.

If you can't tell within 5 minutes, **declare an incident** (post in
the team channel) and start the §9 communications template. Don't
silently debug for 30 minutes.

---

## 1. Postgres is down

Symptoms: `/health` shows `db: false`. Backend logs `prisma error:
ECONNREFUSED` or `prepared statement … does not exist`.

```bash
# Confirm
docker ps --filter "name=hnag-postgres"
docker logs --tail 100 hnag-postgres

# Common: OOM
dmesg | grep -i "out of memory" | tail -5
free -h

# Recovery
docker compose --env-file ../../hnag.env -f docker-compose.prod.yml \
    -p hnag restart postgres
# Wait for healthcheck:
until docker exec hnag-postgres pg_isready -U hnag; do sleep 2; done
docker compose --env-file ../../hnag.env -f docker-compose.prod.yml \
    -p hnag restart backend backend-2
```

If Postgres won't start (corruption / disk full):
- **Disk full**: `df -h`. Trim `/var/lib/docker/` images: `docker image prune -af`.
- **Data corruption**: stop accepting writes via Cloudflare (pause
  the tunnel ingress in CF Zero Trust dashboard), then restore from
  the most recent B2 backup using `restore-postgres-test.sh`.
- **Lost data window**: RPO target is 1 hour (last cron backup); RTO
  target is 30 minutes.

---

## 2. Redis is down

Symptoms: `/health` shows `cache: false`. WebSocket reconnect loops.
OTP send fails (queue cannot enqueue).

```bash
docker ps --filter "name=hnag-redis"
docker logs --tail 100 hnag-redis

# Recovery
docker compose -p hnag restart redis
# Verify AOF on disk is intact:
docker exec hnag-redis ls -la /data/appendonlydir/
```

**Degraded mode**: backend keeps running with no cache + no queues.
Auth still works (SMTP fires synchronously). AI suggest re-fetches
every time (slower but functional). Push notifications queue up in
memory and may be lost.

---

## 3. BullMQ queue stuck

Symptoms: `/admin/queues` shows `waiting > 100` or `failed > 20`.
Users complain emails / push notifications don't arrive.

```bash
# Inspect
curl -s -H "Authorization: Bearer <ADMIN_JWT>" \
     https://api.tothanhthuy.cloud/admin/queues | jq

# Drain failed jobs after fixing the root cause
docker exec -it hnag-backend node -e "
  const { Queue } = require('bullmq');
  const q = new Queue('push:fcm', { connection: { host: 'hnag-redis', port: 6379 } });
  q.clean(0, 1000, 'failed').then(console.log).finally(() => q.close());
"
```

If the worker process itself is dead (workers are in-process with the
backend), restart the backend — they re-attach on boot.

---

## 4. AI provider down (OpenAI 5xx)

Symptoms: `/v1/ai/suggest` returns stale heuristics-only cards, or 500s.
Sentry shows spikes of `openai.api.error`.

**By design, this is graceful**: `LlmReasonService` catches timeouts and
falls back to `fallback()` static lines. The user gets cards with less
witty captions but still gets cards. No emergency action needed.

If OpenAI is sustained-down > 30 min:
1. Set `OPENAI_API_KEY=` (empty) in `hnag.env` and restart backend to
   force all suggests through the static fallback path immediately
   without per-request timeout cost.
2. Post status page note.
3. Restore key when OpenAI's status page goes green.

---

## 5. AI spend anomaly

Symptoms: Grafana "Projected monthly burn" panel hits red threshold
(> $500/month), or a single user's `ai:spend:<userId>:<date>` Redis
counter goes > 100k cents (i.e. $1).

```bash
# Top spenders this week
curl -s -H "Authorization: Bearer <ADMIN_JWT>" \
   "https://api.tothanhthuy.cloud/admin/ai-spend?from=$(date -d '7 days ago' +%F)&top=20" | jq

# Block a specific user (per-user budget already exists; tighten it
# via env without redeploy):
echo "LLM_DAILY_CAP=10" >> hnag.env
# Then recreate the backend container per memory hnag-server-compose-env-gotcha:
docker compose --env-file ../../hnag.env -f docker-compose.prod.yml \
    -p hnag up -d --force-recreate backend backend-2
```

If it's prompt-injection abuse (sees in moderation abuse counter
`mod:abuse:<userId>:<date>` over the threshold): flip the user to
`status='deleted'` in users table and revoke sessions.

---

## 6. Cloudflare Tunnel down

Symptoms: `https://api.tothanhthuy.cloud/*` returns 521/522/523/525.
`/health` works when curled from inside `ServerLinux` but not from
outside.

```bash
# Check tunnel container
docker ps --filter "name=hnag-cloudflared"
docker logs --tail 100 hnag-cloudflared

# Common: token rotation expired
# Regenerate token in CF Zero Trust dashboard → Networks → Tunnels →
# hnag → Configure → copy new token into hnag.env → restart:
docker compose -p hnag up -d --force-recreate cloudflared
```

---

## 7. Backend container OOM / crash loop

Symptoms: `docker ps` shows `Restarting (137)`. Container memory at the
1.5GB limit. Logs end with `JavaScript heap out of memory`.

```bash
# Confirm memory pressure
docker stats --no-stream hnag-backend hnag-backend-2

# Quick mitigation: bump heap (compose limit is 1.5G, set Node's flag higher)
# Edit hnag.env:
echo "NODE_OPTIONS=--max-old-space-size=2000" >> hnag.env
# Edit docker-compose.prod.yml backend.deploy.resources.limits.memory: 2.5G
docker compose -p hnag up -d --force-recreate backend backend-2
```

If it's an actual leak (not pressure), enable heap snapshots:
```bash
docker exec hnag-backend kill -USR2 1  # tells Node to dump heap snapshot
```
Pull the snapshot, run through Chrome DevTools "Memory" tab. Open a PR.

---

## 8. Deploy gone bad — rollback

```bash
# Find the last known-good image tag (CI tags with full SHA)
ssh ServerLinux 'docker images ghcr.io/ndh0408/hnag-backend --format "{{.Tag}}" | head -10'

# Roll back (replace TAG with the last-good SHA)
ssh ServerLinux 'cd /opt/docker/hnag && \
  HNAG_BACKEND_IMAGE=ghcr.io/ndh0408/hnag-backend:TAG \
  docker compose --env-file hnag.env -f code/infra/server/docker-compose.prod.yml \
    -p hnag up -d --force-recreate backend backend-2'
```

If the bad deploy ran a SQL migration that needs rollback: there is no
auto-rollback today. Schema changes ship as additive (new column with
default, deprecation phase, then drop on a later release). If we
actually need to undo a recent schema change, write a hand-crafted
DOWN migration and apply it directly:
```bash
docker exec -i hnag-postgres psql -U hnag -d hnag < /opt/docker/hnag/code/sql/rollback-NN-<name>.sql
```

---

## 9. Communications — first-message template

When a user-visible incident is confirmed, post in the team channel:

```
🚨 INCIDENT — <one-line symptom>
Started: <utc time>
Detected via: <synthetic monitor / customer report / Grafana alert>
Impact: <% of traffic affected, which feature(s)>
Lead: <your name>
Channel: this thread
Status: investigating
```

Update every 15 minutes minimum. Resolution post:
```
✅ RESOLVED — <symptom>
Duration: <minutes>
Root cause: <one-sentence>
Mitigation: <what was deployed>
Next steps: postmortem doc to follow within 48h
```

---

## 10. Backup + restore (drill)

This drill runs automatically the 2nd of every month via
`restore-postgres-test.sh`. If you suspect data loss, run it now:

```bash
ssh ServerLinux 'sudo /opt/hnag/restore-postgres-test.sh'
```

It restores the latest daily backup into a throwaway container, runs
smoke-test queries (`COUNT(*)` on users / restaurants / foods), and
prints OK / FAIL. The restored container is auto-cleaned afterwards.

For an actual disaster restore (not a drill), follow §1 "Postgres is
down" with the additional step: stop the production container, mount
the restored data dir as the production volume, then resume.

---

## Appendix — runbook coverage

| Scenario | Section | Tested? |
|----------|---------|---------|
| Postgres down | §1 | Drilled monthly via restore-postgres-test.sh |
| Redis down | §2 | Not drilled; backend tolerates per design |
| Queue stuck | §3 | Not drilled |
| AI provider down | §4 | Not drilled; tested via OPENAI_API_KEY="" |
| AI spend anomaly | §5 | Not drilled |
| Cloudflare tunnel down | §6 | Not drilled |
| Backend crash loop | §7 | Not drilled |
| Bad deploy rollback | §8 | Not drilled |

Next quarter: pick 2 from "not drilled" and run a real game day.
