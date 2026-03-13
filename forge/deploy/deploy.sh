#!/bin/bash
# Forge Deploy Script — Simple rsync + build
set -euo pipefail

VPS_HOST="${VPS_HOST:-89.116.170.202}"
VPS_USER="${VPS_USER:-root}"
DEPLOY_PATH="/home/forge/app"

echo "=== Deploying Forge to ${VPS_HOST} ==="

# Sync source (exclude build artifacts)
rsync -avz --delete \
    --exclude 'zig-out' \
    --exclude 'zig-cache' \
    --exclude '.zig-cache' \
    --exclude '.git' \
    ./ "${VPS_USER}@${VPS_HOST}:${DEPLOY_PATH}/"

# Build on VPS
ssh "${VPS_USER}@${VPS_HOST}" << 'EOF'
cd /home/forge/app
zig build -Doptimize=ReleaseSafe
chown -R forge:forge /home/forge/app
echo "Build complete: $(ls -la zig-out/bin/forge 2>/dev/null || echo 'no binary')"
EOF

echo "=== Deploy Complete ==="
