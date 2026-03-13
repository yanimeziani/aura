#!/bin/bash
# Forge VPS Setup — Simple, Safe, Single VPS per User
# Target: Debian 11/12/13

set -euo pipefail

echo "=== Forge VPS Setup ==="

# System update
apt-get update && apt-get upgrade -y

# Essential packages only (zero trust — minimal deps)
apt-get install -y \
    curl \
    git \
    sqlite3 \
    nginx \
    certbot \
    python3-certbot-nginx \
    ufw \
    fail2ban

# Firewall — deny all, allow essentials
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow http
ufw allow https
ufw --force enable

# Fail2ban for SSH protection
systemctl enable fail2ban
systemctl start fail2ban

# Create forge user (non-root ops)
useradd -m -s /bin/bash forge || true
mkdir -p /home/forge/app /home/forge/logs /home/forge/data
chown -R forge:forge /home/forge

# Install Zig (latest stable, no package manager)
ZIG_VERSION="0.14.0"
cd /tmp
curl -LO "https://ziglang.org/download/${ZIG_VERSION}/zig-linux-x86_64-${ZIG_VERSION}.tar.xz"
tar -xf "zig-linux-x86_64-${ZIG_VERSION}.tar.xz"
mv "zig-linux-x86_64-${ZIG_VERSION}" /opt/zig
ln -sf /opt/zig/zig /usr/local/bin/zig

# Verify
zig version

# SQLite logs database
sqlite3 /home/forge/data/logs.db <<EOF
CREATE TABLE IF NOT EXISTS agent_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT DEFAULT (datetime('now')),
    source TEXT NOT NULL,
    level TEXT NOT NULL,
    message TEXT NOT NULL,
    metadata TEXT
);

CREATE INDEX IF NOT EXISTS idx_logs_timestamp ON agent_logs(timestamp);
CREATE INDEX IF NOT EXISTS idx_logs_source ON agent_logs(source);
CREATE INDEX IF NOT EXISTS idx_logs_level ON agent_logs(level);
EOF

chown forge:forge /home/forge/data/logs.db

echo "=== Setup Complete ==="
echo "Zig: $(zig version)"
echo "SQLite DB: /home/forge/data/logs.db"
echo "App dir: /home/forge/app"
