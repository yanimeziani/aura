#!/usr/bin/env bash
# sync-cockpit.sh — The "Final Boss" Sync Bridge (Z Fold <-> VPS)
set -euo pipefail

# Configuration
VPS_IP="89.116.170.202"
VPS_USER="root"
REMOTE="${VPS_USER}@${VPS_IP}"
LOCAL_ROOT="/root"
REMOTE_CONFIG_DIR="/opt/configs"
REMOTE_CERBERUS_DIR="/opt/cerberus"

info() { printf '\033[0;34m[cockpit-sync]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[cockpit-sync]\033[0m %s\n' "$*"; }

# 1. Environment Parity Check (Dependencies)
info "Checking A/V Digestion Stack dependencies..."
deps=(ffmpeg python3 pip3 zig)
for dep in "${deps[@]}"; do
    command -v "$dep" >/dev/null 2>&1 || { echo "Missing $dep locally. Install it first."; exit 1; }
done

# 2. Sync Configuration & Prompts
info "Syncing Unified Roster and Agent Prompts to VPS..."
rsync -avzP "${LOCAL_ROOT}/core/cerberus/configs/unified-roster.json" "${REMOTE}:${REMOTE_CONFIG_DIR}/config.json"
rsync -avzP "${LOCAL_ROOT}/core/cerberus/runtime/cerberus-core/prompts/" "${REMOTE}:${REMOTE_CONFIG_DIR}/prompts/"

# 3. Sync Dotfiles (Parity)
info "Syncing shell aliases and functions..."
rsync -avzP "${LOCAL_ROOT}/.zshrc" "${REMOTE}:/root/.zshrc"

# 4. Sync Memory Structures (Incremental)
info "Syncing Agent Memory..."
rsync -avzP "${LOCAL_ROOT}/.cerberus/memory/" "${REMOTE}:/root/.cerberus/memory/"

# 5. Remote Execution: Rebuild & Restart
info "Restarting Cerberus Gateway on VPS..."
ssh "${REMOTE}" bash -s <<EOF
    systemctl stop cerberus-gateway 2>/dev/null || true
    # Update binary if needed
    cp /opt/cerberus/cerberus /usr/local/bin/cerberus
    # Restart with unified config
    systemctl restart cerberus-gateway
    systemctl restart cerberus-pegasus-api
EOF
ok "VPS Services Restarted."

ok "Sync Complete. Your Mobile Cockpit is now in parity with the Production VPS."
