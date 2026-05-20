#!/usr/bin/env bash
# =============================================================================
# Run ONCE on a fresh Ubuntu 22.04 / 24.04 server to set up HNAG production stack.
# Idempotent — safe to re-run.
#
# SSH to server first:  ssh ServerLinux
# Then:                 sudo bash bootstrap.sh
# =============================================================================
set -euo pipefail

USER_NAME="${SUDO_USER:-huy}"
HNAG_HOME="/opt/hnag"

log() { echo "[$(date +%H:%M:%S)] $*"; }

# 1. Update OS
log "Updating apt..."
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq

# 2. Essentials
apt-get install -y \
  curl wget git ufw fail2ban htop tmux jq \
  ca-certificates gnupg lsb-release \
  unattended-upgrades

# 3. Docker
if ! command -v docker >/dev/null 2>&1; then
  log "Installing Docker..."
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -qq
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
  usermod -aG docker "$USER_NAME"
fi

# 4. Firewall
log "Configuring UFW..."
ufw --force reset >/dev/null
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
# Note: 100.x is Tailscale CGNAT — allow tailscale0 if installed
if command -v tailscale >/dev/null 2>&1; then
  ufw allow in on tailscale0
fi
ufw --force enable

# 5. fail2ban (SSH protection)
systemctl enable --now fail2ban

# 6. Unattended security upgrades
cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

# 7. Tailscale (recommended — server is already on 100.100.210.85)
if ! command -v tailscale >/dev/null 2>&1; then
  log "Installing Tailscale..."
  curl -fsSL https://tailscale.com/install.sh | sh
  log "⚠ Run: sudo tailscale up    (paste auth key from admin.tailscale.com)"
fi

# 8. HNAG home dir
mkdir -p "$HNAG_HOME"/{secrets,backups,certs,init,logs}
chown -R "$USER_NAME":"$USER_NAME" "$HNAG_HOME"

# 9. Create secrets if missing
if [ ! -f "$HNAG_HOME/secrets/postgres_password" ]; then
  log "Generating postgres password..."
  openssl rand -hex 24 > "$HNAG_HOME/secrets/postgres_password"
  chmod 600 "$HNAG_HOME/secrets/postgres_password"
  chown "$USER_NAME":"$USER_NAME" "$HNAG_HOME/secrets/postgres_password"
fi

# 10. Swap (helps PostgreSQL under memory pressure)
if [ ! -f /swapfile ]; then
  log "Setting up 4G swap..."
  fallocate -l 4G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile >/dev/null
  swapon /swapfile
  grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# 11. Sysctl tweaks for high-concurrency
cat > /etc/sysctl.d/99-hnag.conf <<EOF
net.core.somaxconn = 4096
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
fs.file-max = 2097152
vm.swappiness = 10
EOF
sysctl -p /etc/sysctl.d/99-hnag.conf >/dev/null

# 12. Systemd unit for HNAG (auto-start on boot)
cat > /etc/systemd/system/hnag.service <<EOF
[Unit]
Description=HNAG production stack
After=docker.service network-online.target
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$HNAG_HOME
ExecStart=/usr/bin/docker compose -f docker-compose.prod.yml up -d
ExecStop=/usr/bin/docker compose -f docker-compose.prod.yml down
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable hnag.service

log "✅ Bootstrap done."
log ""
log "Next steps:"
log "  1. Logout/login so docker group works for $USER_NAME"
log "  2. Copy code/infra/server/* to $HNAG_HOME"
log "  3. Fill $HNAG_HOME/hnag.env (see hnag.env.example)"
log "  4. cd $HNAG_HOME && ./deploy.sh"
log "  5. Open https://api.tothanhthuy.cloud/health"
