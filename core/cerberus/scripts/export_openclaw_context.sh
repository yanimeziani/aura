#!/usr/bin/env bash
# export_openclaw_context.sh
# Snapshot non-secret OpenClaw assets required for Cerberus migration.
# Safe to run multiple times.

set -euo pipefail

SRC_CONFIG="${SRC_CONFIG:-/data/openclaw/config}"
OUT_BASE="${OUT_BASE:-/data/cerberus/bootstrap}"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="${OUT_BASE}/openclaw-context-${TS}"

info() { printf '\033[0;34m[export]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[export]\033[0m %s\n' "$*"; }
warn() { printf '\033[0;33m[export]\033[0m %s\n' "$*"; }

if [[ ! -d "$SRC_CONFIG" ]]; then
  warn "Source config path not found: $SRC_CONFIG"
  warn "Set SRC_CONFIG=/path/to/openclaw-config and retry."
  exit 1
fi

mkdir -p "$OUT_DIR"
mkdir -p "$OUT_DIR/files"

info "Exporting OpenClaw context from $SRC_CONFIG"

paths=(
  "agents"
  "mcp"
  "policies"
  "runbooks"
  "scripts/termux"
  "README.md"
)

for rel in "${paths[@]}"; do
  src="${SRC_CONFIG}/${rel}"
  dst="${OUT_DIR}/files/${rel}"
  if [[ -e "$src" ]]; then
    mkdir -p "$(dirname "$dst")"
    cp -a "$src" "$dst"
    ok "Copied ${rel}"
  else
    warn "Missing ${rel}, skipped"
  fi
done

# Explicitly exclude secret-bearing files from snapshot payload.
rm -f \
  "${OUT_DIR}/files/docker/.env" \
  "${OUT_DIR}/files/docker/.env.example" \
  "${OUT_DIR}/files/scripts/termux/cockpit.conf" \
  2>/dev/null || true

manifest="${OUT_DIR}/manifest.txt"
{
  echo "snapshot_ts=${TS}"
  echo "source_config=${SRC_CONFIG}"
  echo "export_dir=${OUT_DIR}"
  echo "notes=non-secret migration snapshot for Cerberus"
} > "$manifest"

if command -v sha256sum >/dev/null 2>&1; then
  : > "${OUT_DIR}/sha256sums.txt"
  while IFS= read -r rel; do
    (cd "${OUT_DIR}/files" && sha256sum "$rel") >> "${OUT_DIR}/sha256sums.txt"
  done < <(cd "${OUT_DIR}/files" && find . -type f | sort)
fi

tarball="${OUT_BASE}/openclaw-context-${TS}.tar.gz"
tar -C "$OUT_BASE" -czf "$tarball" "openclaw-context-${TS}"

ok "Export complete"
printf "  Directory: %s\n" "$OUT_DIR"
printf "  Tarball:   %s\n" "$tarball"
