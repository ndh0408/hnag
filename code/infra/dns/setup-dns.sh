#!/usr/bin/env bash
# =============================================================================
# Setup DNS records for tothanhthuy.cloud → ServerLinux (TAILNET_HOST / public IP)
#
# Usage:
#   export CF_API_TOKEN='your-token-here'
#   export PUBLIC_IP='1.2.3.4'           # your server's public IP (NOT Tailscale)
#   ./setup-dns.sh
#
# Detects provider automatically: tries Cloudflare first, then Porkbun.
# =============================================================================
set -euo pipefail

DOMAIN="${DOMAIN:-tothanhthuy.cloud}"
EMAIL="${EMAIL:-huy04082000@gmail.com}"
PUBLIC_IP="${PUBLIC_IP:?Set PUBLIC_IP=1.2.3.4 (server's public IPv4)}"
TOKEN="${CF_API_TOKEN:-${PORKBUN_API_KEY:-}}"

if [ -z "$TOKEN" ]; then
  echo "❌ Set CF_API_TOKEN (Cloudflare) or PORKBUN_API_KEY (+ PORKBUN_SECRET_KEY)"
  exit 1
fi

log() { echo "[$(date +%H:%M:%S)] $*"; }

# Subdomains to create
declare -a SUBS=(
  "@"
  "www"
  "api"
  "dash"
  "app"
  "cdn"
)

# ─── Cloudflare detection ──────────────────────────────────────────────────
detect_cloudflare() {
  local zone_id
  zone_id=$(curl -fsS -X GET "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" 2>/dev/null | jq -r '.result[0].id // empty')
  [ -n "$zone_id" ] && echo "$zone_id"
}

upsert_cf_record() {
  local zone_id="$1" name="$2" type="$3" content="$4"
  local fqdn="$name"
  [ "$name" = "@" ] && fqdn="$DOMAIN" || fqdn="$name.$DOMAIN"

  local existing
  existing=$(curl -fsS -X GET \
    "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?type=$type&name=$fqdn" \
    -H "Authorization: Bearer $TOKEN" | jq -r '.result[0].id // empty')

  local payload
  payload=$(jq -nc --arg type "$type" --arg name "$name" --arg content "$content" \
    '{type:$type,name:$name,content:$content,ttl:300,proxied:false}')

  if [ -n "$existing" ]; then
    log "  ↻ Update $fqdn → $content"
    curl -fsS -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$existing" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      --data "$payload" > /dev/null
  else
    log "  + Create $fqdn → $content"
    curl -fsS -X POST "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      --data "$payload" > /dev/null
  fi
}

# ─── Porkbun detection ─────────────────────────────────────────────────────
detect_porkbun() {
  local result
  result=$(curl -fsS -X POST "https://api.porkbun.com/api/json/v3/ping" \
    -H "Content-Type: application/json" \
    --data "{\"apikey\":\"$PORKBUN_API_KEY\",\"secretapikey\":\"$PORKBUN_SECRET_KEY\"}" 2>/dev/null | jq -r '.status // empty')
  [ "$result" = "SUCCESS" ] && echo "porkbun"
}

upsert_porkbun_record() {
  local name="$1" type="$2" content="$3"
  local sub="$name"
  [ "$name" = "@" ] && sub=""

  # Porkbun upsert: list, find, then create or update
  local resp records
  resp=$(curl -fsS -X POST "https://api.porkbun.com/api/json/v3/dns/retrieveByNameType/$DOMAIN/$type/$sub" \
    -H "Content-Type: application/json" \
    --data "{\"apikey\":\"$PORKBUN_API_KEY\",\"secretapikey\":\"$PORKBUN_SECRET_KEY\"}")

  records=$(echo "$resp" | jq -r '.records[]?.id')
  if [ -n "$records" ]; then
    for id in $records; do
      log "  ↻ Update $sub.$DOMAIN ($id) → $content"
      curl -fsS -X POST "https://api.porkbun.com/api/json/v3/dns/edit/$DOMAIN/$id" \
        -H "Content-Type: application/json" \
        --data "{\"apikey\":\"$PORKBUN_API_KEY\",\"secretapikey\":\"$PORKBUN_SECRET_KEY\",\"name\":\"$sub\",\"type\":\"$type\",\"content\":\"$content\",\"ttl\":\"300\"}" > /dev/null
    done
  else
    log "  + Create $sub.$DOMAIN → $content"
    curl -fsS -X POST "https://api.porkbun.com/api/json/v3/dns/create/$DOMAIN" \
      -H "Content-Type: application/json" \
      --data "{\"apikey\":\"$PORKBUN_API_KEY\",\"secretapikey\":\"$PORKBUN_SECRET_KEY\",\"name\":\"$sub\",\"type\":\"$type\",\"content\":\"$content\",\"ttl\":\"300\"}" > /dev/null
  fi
}

# ─── Run ───────────────────────────────────────────────────────────────────
log "🌐 Setting up DNS for $DOMAIN → $PUBLIC_IP"
ZONE_ID=$(detect_cloudflare || true)

if [ -n "$ZONE_ID" ]; then
  log "Provider: Cloudflare (zone=$ZONE_ID)"
  for sub in "${SUBS[@]}"; do
    upsert_cf_record "$ZONE_ID" "$sub" "A" "$PUBLIC_IP"
  done
elif [ -n "${PORKBUN_API_KEY:-}" ] && [ -n "${PORKBUN_SECRET_KEY:-}" ]; then
  if [ "$(detect_porkbun)" = "porkbun" ]; then
    log "Provider: Porkbun"
    for sub in "${SUBS[@]}"; do
      upsert_porkbun_record "$sub" "A" "$PUBLIC_IP"
    done
  else
    log "❌ Porkbun credentials invalid"; exit 1
  fi
else
  echo "❌ Could not detect DNS provider."
  echo "   Set CF_API_TOKEN for Cloudflare, or PORKBUN_API_KEY + PORKBUN_SECRET_KEY for Porkbun."
  exit 1
fi

log "✅ DNS records set."
log ""
log "Next: issue TLS certs on ServerLinux:"
log "  ssh ServerLinux"
log "  cd /opt/hnag"
log "  docker compose -f docker-compose.prod.yml up -d nginx"
log "  docker compose -f docker-compose.prod.yml run --rm certbot certonly \\"
log "    --webroot --webroot-path /var/www/certbot \\"
log "    -d api.$DOMAIN -d dash.$DOMAIN -d app.$DOMAIN -d cdn.$DOMAIN \\"
log "    --email $EMAIL --agree-tos --non-interactive"
