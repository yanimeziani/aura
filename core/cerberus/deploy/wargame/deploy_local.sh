#!/bin/bash
# Deploy Wargame Roster Locally
set -e

REPO_ROOT=$(pwd)
WARGAME_DIR="$REPO_ROOT/core/cerberus/deploy/wargame"
CERBERUS_BIN="$REPO_ROOT/core/cerberus/runtime/cerberus-core/zig-out/bin/cerberus"

if [ ! -f "$CERBERUS_BIN" ]; then
    echo "⚙️ Building Cerberus runtime..."
    cd "$REPO_ROOT/core/cerberus/runtime/cerberus-core"
    zig build -Doptimize=ReleaseSafe
    cd "$REPO_ROOT"
fi

echo "🚀 Deploying Wargame Roster..."
mkdir -p "$WARGAME_DIR/artifacts"
mkdir -p "$WARGAME_DIR/sandbox/trusted"
mkdir -p "$WARGAME_DIR/sandbox/quarantine"
mkdir -p "$WARGAME_DIR/sandbox/incoming"

# Symlink or copy prompts if needed by runtime (Cerberus usually reads from config or relative paths)
# For now, we assume Cerberus will run from this directory or we'll pass the config path.

echo "✅ Wargame roster ready."
echo "To start the simulation:"
echo "export AURA_ISOLATE_CLUSTER=1"
echo "cerberus --config $WARGAME_DIR/config.roster.json agent --id wargame-orchestrator"
