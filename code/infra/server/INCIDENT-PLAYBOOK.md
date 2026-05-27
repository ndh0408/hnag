# HNAG Incident Playbook (15 scenarios)

Companion to DEPLOY-RUNBOOK.md. Each entry: signal → triage commands →
mitigation → root-cause hooks. SSH alias `ServerLinux`. All times UTC.

---

## 1. Redis outage

**Signal**:
- `/health` returns `cache: false`
- Backend logs: `MaxRetriesPerRequestError` from ioredis
- WS clients see `force_disconnect: heartbeat_timeout`

**Triage**:
```bash
ssh ServerLinux
docker ps --filter name=hnag-redis --format '{{.Status}}'
docker logs --tail 100 hnag-redis 2>&1 | tail -20
docker stats --no-stream hnag-redis      # memory pressure?
```

**Mitigation**:
```bash
# Quick restart if container is dead
docker compose --env-file /opt/docker/hnag/hnag.env \
  -f /opt/docker/hnag/docker-compose.prod.yml up -d redis

# If Redis is up but unresponsive — check AOF size:
docker exec hnag-redis redis-cli INFO persistence | grep aof_

# Wait for hnag-backend to reconnect (~10s). If it doesn't:
docker restart hnag-backend
```

**Post-mortem hooks**: AOF + maxmemory-policy volatile-lru already on
(sql/19 + compose). Recovery within ≤30s for OOM. Long network partition
needs Redis Sentinel — Tier-2 work.

---

## 2. AI provider timeout (OpenAI 5xx)

**Signal**:
- Backend logs: `LLM batch failed` / `LLM select failed` warnings
- Metric: rising `degraded: true` responses on `/v1/ai/suggest`
- Org cost dashboard flat (no spend = no calls)

**Triage**:
```bash
ssh ServerLinux
docker logs --tail 200 hnag-backend 2>&1 | grep -E 'LLM (batch|select)' | tail -20
# Check if circuit breaker is open
docker logs --tail 200 hnag-backend 2>&1 | grep 'LLM breaker'
```

**Mitigation**: nothing — circuit breaker opens automatically after 5
fails/min, falls back to heuristic captions for 30s. Watch OpenAI status
page; recovery is automatic.

To force-open the breaker (e.g. manual incident-mitigation):
```
# Set OPENAI_DAILY_HARD_CAP_USD=0 in hnag.env, recreate backend.
# This blocks all LLM calls until you reset.
```

---

## 3. Socket server restart (deploy)

**Signal**: planned — operator runs deploy

**Mitigation**: clients auto-reconnect (capped 20 attempts, max 15s
backoff). Tier-1 replay protocol via `RoomEventStreamService` fills in
missed events.

Drain procedure:
```bash
# Just `docker compose up -d --force-recreate backend` — Nest's
# enableShutdownHooks gives 10s drain for in-flight HTTP. WS clients
# auto-reconnect.
```

---

## 4. DB slowdown

**Signal**:
- `/health` `dbLatencyMs > 100`
- Backend logs: `slow-query CRITICAL 2000ms+`
- Prisma errors: `P2024: Timed out fetching a new connection`

**Triage**:
```bash
ssh ServerLinux
# Top queries by total time
docker exec -i hnag-postgres psql -U hnag -d hnag <<'SQL'
SELECT pid, age(clock_timestamp(), query_start) AS dur, state, substring(query, 1, 80)
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY dur DESC LIMIT 10;
SQL

# Long-running queries (>30s)
docker exec hnag-postgres psql -U hnag -d hnag -c "
SELECT pg_terminate_backend(pid) FROM pg_stat_activity
 WHERE state != 'idle'
   AND age(clock_timestamp(), query_start) > interval '30 seconds';
"
```

**Mitigation**:
- Identify + kill via pg_terminate_backend (above)
- If autovacuum is the culprit: `ALTER TABLE foo SET (autovacuum_vacuum_scale_factor=0.01);`
- If retention cron stuck: `docker logs hnag-backend | grep RetentionCron`

---

## 5. Mobile reconnect storm (after backend restart)

**Signal**: 30-60s after restart, dashboard shows WS conn count climb
spike + DB CPU spike

**Mitigation**: nothing — self-heals via 60s `ws:userstatus:` cache and
60s `ws:gmember:` cache. First 30 reconnects warm both, subsequent ones
hit cache. Tier-1 features (this session) added per-user rate limit
(90/min) preventing fresh-socket bypass.

---

## 6. Duplicate requests

**Coverage** (today):
- Orders: client `Idempotency-Key` ✓
- Vote: jsonb_set overwrite ✓
- AI feedback: 30s SETNX dedup ✓
- Like: createMany skipDuplicates ✓
- Promo: pg_advisory_xact_lock ✓
- SePay: UNIQUE(provider, external_txn_id) ✓

**Mitigation**: dedup is automatic. Check logs for `idempotency replay`
or `dedup` entries.

---

## 7. Packet loss / mobile carrier issues

**Signal**: rising HTTP 5xx rate from one CGNAT egress + WS heartbeat
timeouts

**Mitigation**: nothing actionable on server side. ResilientClient on
Flutter retries idempotent GETs; non-idempotent POSTs require user
retry. Heartbeat catches dead sockets in ≤90s.

---

## 8. API rate abuse / botnet

**Signal**: Throttle logs flood with 429s from same IP range. OTP
lockout logs spike.

**Triage**:
```bash
docker logs hnag-backend 2>&1 | grep -E 'OTP_RATE_LIMITED|OTP_LOCKED' | tail -50
# Get top abusive IPs (from cf-connecting-ip header in logs)
```

**Mitigation**:
- Block at Cloudflare WAF (faster than backend)
- If specific email targeted: extend `otp:lock:email:<email>` manually:
  ```
  docker exec hnag-redis redis-cli SETEX otp:lock:email:victim@example.com 86400 1
  ```

---

## 9. AI spam attack (premium user automation)

**Signal**: `ai:spend:org:<today>` Redis counter climbs unusually fast

**Triage**:
```bash
ssh ServerLinux
docker exec hnag-redis redis-cli GET ai:spend:org:$(date -u +%Y-%m-%d)
# (returned value × 1e-5 = USD)
# Top spenders today:
docker exec hnag-redis redis-cli KEYS "ai:spend:*:$(date -u +%Y-%m-%d)" | \
  xargs -I {} sh -c "echo -n '{}: '; docker exec hnag-redis redis-cli GET {}"
```

**Mitigation**:
- Drop `OPENAI_DAILY_HARD_CAP_USD` in hnag.env, recreate backend — kills
  ALL LLM calls until reset
- Ban abusive user:
  ```
  docker exec hnag-postgres psql -U hnag -d hnag -c \
    "UPDATE users SET status='banned' WHERE id='<userId>';"
  # PremiumGuard + WS user.status check reject within 60s of cache expiry
  ```

---

## 10. Cache corruption

**Signal**: 500s on `/v1/ai/suggest` for specific users with logs like
`safeReadJson(...) bad JSON — DEL + recompute`

**Mitigation**: automatic — `safeReadJson` DELs bad key + recomputes
(this session's fix). If you see repeated 500s on a specific user:
```bash
docker exec hnag-redis redis-cli --scan --pattern "ai:suggest:<userId>:*" | \
  xargs -r docker exec hnag-redis redis-cli DEL
```

---

## 11. Race conditions

**All known race conditions are closed** at code level (covered in 17
audit commits this week). If you see a NEW race symptom, capture the
exact query + reproduce.

---

## 12. Slow geospatial queries

**Signal**: `slow-query` log mentioning `ST_DWithin` or `<->` operator

**Triage**:
```bash
ssh ServerLinux
docker exec hnag-postgres psql -U hnag -d hnag <<'SQL'
-- Check that the partial GIST is being used
EXPLAIN ANALYZE
SELECT id FROM restaurants
WHERE status='active'
  AND ST_DWithin(location, ST_SetSRID(ST_MakePoint(106.69, 10.78), 4326)::geography, 3000)
ORDER BY location <-> ST_SetSRID(ST_MakePoint(106.69, 10.78), 4326)::geography
LIMIT 20;
SQL
```

**Mitigation**: re-index if the partial GIST isn't picked:
```sql
REINDEX INDEX CONCURRENTLY idx_restaurants_loc_active;
ANALYZE restaurants;
```

---

## 13. Feed overload

**Signal**: `/v1/feed` p95 latency > 1s, conn pool saturated

**Mitigation**: 60s Redis cache (this session's fix) absorbs spike.
Force-warm:
```bash
docker exec hnag-backend wget -qO- 'http://localhost:4000/v1/feed?tab=trending&page=1' \
  -H 'Authorization: Bearer <any-valid-jwt>'
```

---

## 14. Notification storm

**Signal**: `notifications` table growing > 1k rows/min

**Mitigation**:
- Throttle the source (admin broadcast endpoint)
- If FCM is enabled and rejecting: prune dead tokens
  ```
  docker exec hnag-postgres psql -U hnag -d hnag -c \
    "SELECT COUNT(*) FROM user_devices WHERE push_token IS NOT NULL;"
  ```

---

## 15. Large traffic spike

**Signal**: req/s > baseline 10x, conn pool warnings

**Mitigation**:
- Cloudflare → rate-limit `/v1/auth/*` to 100 req/s per IP (dashboard)
- Scale: deploy `backend-2` from reference compose (add nginx upstream)
- Cache warm: pre-populate Redis with common queries

---

# Emergency rollback

```bash
ssh ServerLinux
# 1. Roll backend image to last-good
docker tag hnag-backend:rollback-20260527-XXXX hnag-backend:local
cd /opt/docker/hnag
docker compose --env-file hnag.env -f docker-compose.prod.yml up -d --force-recreate backend

# 2. Restore DB to last clean point (24h granularity today; ≤1min after
#    WAL archiving is activated)
./wal-restore.sh restore "2026-05-27T07:00:00Z"
```

# Escalation contacts

| Severity | Who |
|---|---|
| P0 (full outage, payment broken) | huy04082000@gmail.com |
| P1 (degraded, no payment impact) | huy04082000@gmail.com |
| P2 (single feature) | next-day fix |

(Add PagerDuty / Opsgenie integration: see hnag-audit-deploy-2026-05-27.)
