#!/bin/bash
set -e

echo "🛡️ Deploying Aura Edge (Vercel Clone) securely to VPS..."

# Build for release
zig build -Doptimize=ReleaseSafe

echo "📦 Setting up systemd service..."

# Create a systemd service file
cat << 'EOF' | sudo tee /etc/systemd/system/aura-edge.service > /dev/null
[Unit]
Description=Aura Edge Sovereign Router (Zig-based Vercel Clone)
After=network.target

[Service]
Type=simple
# Using root to bind to low ports, in a real env could use capabilities or port forwarding
User=root
WorkingDirectory=/home/yani/Aura/aura-edge
ExecStart=/home/yani/Aura/aura-edge/zig-out/bin/aura_edge
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

# Security Hardening
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=full
ProtectHome=read-only

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable aura-edge
sudo systemctl restart aura-edge

echo "✅ Aura Edge deployed and running securely!"
echo "Status: sudo systemctl status aura-edge"
