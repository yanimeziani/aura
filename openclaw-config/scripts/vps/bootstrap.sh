#!/usr/bin/env bash
# bootstrap.sh — VPS first-time setup for OpenClaw / Dragun.app
# Run once as root (or sudo) on a fresh Debian VPS.
# Idempotent: safe to re-run.
# Usage: bash bootstrap.sh

set -euo pipefail

OPENCLAW_USER="openclaw"
DATA_DIR="/data"
OPENCLAW_DIR="$DATA_DIR/openclaw"
DRAGUN_DIR="$DATA_DIR/dragun"

info()    { printf '\033[0;34m[bootstrap]\033[0m %s\n' "$*"; }
ok()      { printf '\033[0;32m[bootstrap]\033[0m %s\n' "$*"; }
warn()    { printf '\033[0;33m[bootstrap]\033[0m %s\n' "$*"; }
section() { printf '\n\033[1;36m=== %s ===\033[0m\n' "$*"; }

# ---------- 1. System packages ----------
section "System packages"
apt-get update -qq
apt-get install -y --no-install-recommends \
  docker.io docker-compose-plugin \
  git curl wget jq tmux \
  fail2ban ufw \
  unattended-upgrades \
  ca-certificates gnupg
ok "Packages installed"

# ---------- 2. Docker ----------
section "Docker"
systemctl enable docker
systemctl start docker
ok "Docker running"

# ---------- 3. Dedicated user ----------
section "openclaw user"
if ! id "$OPENCLAW_USER" &>/dev/null; then
  useradd -m -s /bin/bash "$OPENCLAW_USER"
  usermod -aG docker "$OPENCLAW_USER"
  ok "Created user: $OPENCLAW_USER"
else
  ok "User $OPENCLAW_USER already exists"
fi

# ---------- 4. Directory layout ----------
section "Data directories"
mkdir -p \
  "$OPENCLAW_DIR/config" \
  "$OPENCLAW_DIR/artifacts/devsecops" \
  "$OPENCLAW_DIR/artifacts/growth" \
  "$OPENCLAW_DIR/logs" \
  "$OPENCLAW_DIR/hitl-queue/pending" \
  "$OPENCLAW_DIR/hitl-queue/approved" \
  "$OPENCLAW_DIR/hitl-queue/rejected" \
  "$DRAGUN_DIR/repos" \
  "$DRAGUN_DIR/artifacts"

chown -R "$OPENCLAW_USER:$OPENCLAW_USER" "$DATA_DIR"
ok "Data directories created at $DATA_DIR"

# ---------- 5. Firewall ----------
section "Firewall (ufw)"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow "$SSH_PORT" comment "SSH"   # set SSH_PORT env var or defaults to 22
ufw allow 80/tcp  comment "HTTP"
ufw allow 443/tcp comment "HTTPS"
ufw --force enable
ok "Firewall configured"

# ---------- 6. SSH hardening ----------
section "SSH hardening"
SSHD_CONF="/etc/ssh/sshd_config"

# Disable password auth (key-only)
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONF"
sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' "$SSHD_CONF"
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONF"

systemctl reload sshd
warn "Password auth disabled. Ensure your SSH key is in authorized_keys BEFORE logging out."
ok "SSH hardened"

# ---------- 7. fail2ban ----------
section "fail2ban"
cat > /etc/fail2ban/jail.local <<'EOF'
[sshd]
enabled  = true
port     = ssh
maxretry = 5
bantime  = 1h
findtime = 10m
EOF
systemctl enable fail2ban
systemctl restart fail2ban
ok "fail2ban configured"

# ---------- 8. Log rotation ----------
section "Log rotation"
cat > /etc/logrotate.d/openclaw <<'EOF'
/data/openclaw/logs/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 openclaw openclaw
}
EOF
ok "Log rotation configured"

# ---------- 9. Unattended upgrades ----------
section "Unattended upgrades"
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
ok "Unattended upgrades enabled"

# ---------- 10. openclaw CLI on PATH ----------
section "openclaw CLI"
# Will be symlinked once repo is cloned; this step is a post-clone reminder.
OPENCLAW_BIN="/usr/local/bin/openclaw"
if [[ -f "$OPENCLAW_DIR/config/bin/openclaw" ]]; then
  ln -sf "$OPENCLAW_DIR/config/bin/openclaw" "$OPENCLAW_BIN"
  ok "openclaw CLI linked to $OPENCLAW_BIN"
else
  warn "Repo not cloned yet — run after cloning:"
  warn "  ln -sf $OPENCLAW_DIR/config/bin/openclaw $OPENCLAW_BIN"
fi

# ---------- done ----------
section "Bootstrap complete"
ok "VPS is ready. Next steps:"
printf "  1. Copy SSH public key to /home/%s/.ssh/authorized_keys\n" "$OPENCLAW_USER"
printf "  2. Clone openclaw-config:\n"
printf "       git clone git@github.com:yourorg/openclaw-config %s/config\n" "$OPENCLAW_DIR"
printf "  3. Link CLI: ln -sf %s/config/bin/openclaw /usr/local/bin/openclaw\n" "$OPENCLAW_DIR"
printf "  4. cd %s/config/docker && cp .env.example .env  # fill in secrets\n" "$OPENCLAW_DIR"
printf "  5. docker compose up -d\n"
printf "  6. openclaw status\n"
