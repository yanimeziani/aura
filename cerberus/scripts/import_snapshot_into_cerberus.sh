#!/usr/bin/env bash
# import_snapshot_into_cerberus.sh
# Import a snapshot created by export_openclaw_context.sh into Cerberus config tree.

set -euo pipefail

SNAPSHOT_DIR="${1:-}"
TARGET_CONFIG="${TARGET_CONFIG:-/data/cerberus/config}"

info() { printf '\033[0;34m[import]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[import]\033[0m %s\n' "$*"; }
warn() { printf '\033[0;33m[import]\033[0m %s\n' "$*"; }

if [[ -z "$SNAPSHOT_DIR" ]]; then
  warn "Usage: bash import_snapshot_into_cerberus.sh /data/cerberus/bootstrap/openclaw-context-<ts>"
  exit 1
fi

if [[ ! -d "$SNAPSHOT_DIR/files" ]]; then
  warn "Snapshot files directory not found: $SNAPSHOT_DIR/files"
  exit 1
fi

mkdir -p "$TARGET_CONFIG"
cp -a "$SNAPSHOT_DIR/files/." "$TARGET_CONFIG/"

info "Rewriting OpenClaw path/name references"

while IFS= read -r file; do
  sed -i \
    -e 's#/data/openclaw#/data/cerberus#g' \
    -e 's#OPENCLAW_#CERBERUS_#g' \
    -e 's#openclaw#cerberus#g' \
    "$file"
done < <(find "$TARGET_CONFIG" -type f \( -name "*.md" -o -name "*.yaml" -o -name "*.yml" -o -name "*.json" -o -name "*.sh" \))

ok "Import complete into $TARGET_CONFIG"
printf "Review required:\n"
printf "  - agent model routing IDs\n"
printf "  - compose service names and env vars\n"
printf "  - API routes consumed by clients\n"
