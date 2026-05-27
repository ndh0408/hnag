#!/usr/bin/env bash
#
# HNAG — TLS expiry monitor
# -----------------------------------------------------------------------------
# Production fronts every public hostname through Cloudflare (tunnel +
# edge certs), so Cloudflare auto-renews the certificate. That is _usually_
# fine, except:
#   * misconfigured zones / SSL/TLS mode changes silently break renewal
#   * Cloudflare can fail to renew if DNS validation breaks
#   * If TLS mode is "Full (strict)" and the origin's self-signed cert expires
#     the edge starts 5xx-ing even though the public cert is fine
#
# This script does an out-of-band TLS handshake against every public hostname
# (over the open internet, not via the tunnel) and alerts when an effective
# cert is within 14 days of expiry — giving ops a full window to react before
# the audit-flagged "100% outage on silent expiry" plays out.
#
# Cron suggested in /etc/cron.d/hnag-tls:
#   0 7 * * *  root  /opt/hnag/tls-expiry-check.sh >> /var/log/hnag-tls.log 2>&1
#
# Env (sourced from /opt/hnag/backup.env or /etc/hnag-monitor.env):
#   HOSTNAMES               space-separated list (default: built-in HNAG list)
#   ALERT_DAYS              alert when remaining ≤ this many days (default 14)
#   ALERT_WEBHOOK_URL       Slack / Discord / Telegram webhook (optional)
#   HEALTHCHECK_TLS_URL     ping on overall success (optional)
# -----------------------------------------------------------------------------

set -euo pipefail

for env_file in /opt/hnag/backup.env /etc/hnag-monitor.env; do
  [[ -r "$env_file" ]] && source "$env_file"
done

: "${HOSTNAMES:=api.tothanhthuy.cloud dash.tothanhthuy.cloud app.tothanhthuy.cloud tothanhthuy.cloud}"
: "${ALERT_DAYS:=14}"

log() { echo "$(date -u +%FT%TZ) [tls] $*"; }

alert() {
  local msg="$1"
  log "ALERT: $msg"
  if [[ -n "${ALERT_WEBHOOK_URL:-}" ]]; then
    curl -fsS -m 10 -H 'Content-Type: application/json' \
      -d "$(printf '{"text":"🔐 HNAG TLS alert: %s"}' "$msg")" \
      "$ALERT_WEBHOOK_URL" >/dev/null || true
  fi
}

EXIT=0
for host in $HOSTNAMES; do
  expiry_raw="$(echo | openssl s_client -servername "$host" -connect "$host:443" 2>/dev/null \
                  | openssl x509 -noout -enddate 2>/dev/null \
                  | sed 's/^notAfter=//')"
  if [[ -z "$expiry_raw" ]]; then
    alert "$host: handshake failed"
    EXIT=1
    continue
  fi
  expiry_sec="$(date -d "$expiry_raw" +%s 2>/dev/null || true)"
  if [[ -z "$expiry_sec" ]]; then
    alert "$host: cannot parse expiry '$expiry_raw'"
    EXIT=1
    continue
  fi
  now_sec="$(date +%s)"
  days_left=$(( (expiry_sec - now_sec) / 86400 ))
  log "$host expires in $days_left days ($expiry_raw)"
  if [[ "$days_left" -le "$ALERT_DAYS" ]]; then
    alert "$host expires in $days_left days"
    EXIT=1
  fi
done

if [[ "$EXIT" -eq 0 && -n "${HEALTHCHECK_TLS_URL:-}" ]]; then
  curl -fsS -m 10 -o /dev/null --retry 3 "$HEALTHCHECK_TLS_URL" || true
fi
exit "$EXIT"
