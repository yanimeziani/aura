#!/bin/bash
set -euo pipefail

VPS_HOST="${VPS_HOST:-89.116.170.202}"
VPS_USER="${VPS_USER:-root}"
DEPLOY_PATH="/home/conductor"

echo "=== Deploying Conductor to ${VPS_HOST} ==="

# Sync
rsync -avz --delete \
    --exclude 'zig-out' \
    --exclude 'zig-cache' \
    --exclude '.zig-cache' \
    ./ "${VPS_USER}@${VPS_HOST}:${DEPLOY_PATH}/"

# Build on VPS
ssh "${VPS_USER}@${VPS_HOST}" << 'EOF'
cd /home/conductor
zig build -Doptimize=ReleaseSafe
echo "Build: $(ls -la zig-out/bin/conductor 2>/dev/null || echo 'failed')"
EOF

echo "=== Deploy Complete ==="
