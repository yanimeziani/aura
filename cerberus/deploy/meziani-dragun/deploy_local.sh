#!/usr/bin/env bash
# Deploy Cerberus binary + Meziani/Dragun roster locally.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNTIME_DIR="${RUNTIME_DIR:-${ROOT_DIR}/runtime/cerberus-core}"
DEPLOY_DIR="${ROOT_DIR}/deploy/meziani-dragun"
INSTALL_BIN_DIR="${INSTALL_BIN_DIR:-/usr/local/bin}"
INSTALL_CONFIG_DIR="${INSTALL_CONFIG_DIR:-${HOME}/.cerberus}"
GATEWAY_HOST="${GATEWAY_HOST:-0.0.0.0}"
GATEWAY_PORT="${GATEWAY_PORT:-3000}"
DRAGUN_PATH="${DRAGUN_PATH:-/root/dragun-app}"
CERBERUS_PATH="${CERBERUS_PATH:-${HOME}/.cerberus}"

info() { printf '\033[0;34m[deploy-local]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[deploy-local]\033[0m %s\n' "$*"; }
warn() { printf '\033[0;33m[deploy-local]\033[0m %s\n' "$*"; }
die()  { printf '\033[0;31m[deploy-local]\033[0m %s\n' "$*"; exit 1; }

[[ -d "$RUNTIME_DIR" ]] || die "Runtime directory not found: $RUNTIME_DIR"
[[ -f "$DEPLOY_DIR/generate_roster_config.py" ]] || die "Missing config generator script"
command -v python3 >/dev/null 2>&1 || die "python3 is required"

if ! command -v zig >/dev/null 2>&1; then
  die "zig is required to compile Cerberus (expected Zig 0.15.2)"
fi

info "Compiling Cerberus runtime"
zig -v >/dev/null 2>&1 || true
(
  cd "$RUNTIME_DIR"
  zig build -Doptimize=ReleaseSmall
)
ok "Compilation complete"

bin_src="${RUNTIME_DIR}/zig-out/bin/cerberus"
[[ -x "$bin_src" ]] || die "Compiled binary not found: $bin_src"

mkdir -p "$INSTALL_BIN_DIR"
cp "$bin_src" "${INSTALL_BIN_DIR}/cerberus"
chmod 0755 "${INSTALL_BIN_DIR}/cerberus"
ok "Installed binary to ${INSTALL_BIN_DIR}/cerberus"

mkdir -p "$INSTALL_CONFIG_DIR"
config_target="${INSTALL_CONFIG_DIR}/config.json"
if [[ -f "$config_target" ]]; then
  ts="$(date -u +%Y%m%dT%H%M%SZ)"
  cp "$config_target" "${INSTALL_CONFIG_DIR}/config.backup.${ts}.json"
  ok "Backed up existing config to config.backup.${ts}.json"
fi

generated_config="${DEPLOY_DIR}/config.roster.json"
python3 "$DEPLOY_DIR/generate_roster_config.py" \
  --output "$generated_config" \
  --gateway-host "$GATEWAY_HOST" \
  --gateway-port "$GATEWAY_PORT" \
  --dragun-path "$DRAGUN_PATH" \
  --cerberus-path "$CERBERUS_PATH"

cp "$generated_config" "$config_target"
ok "Installed roster config at $config_target"

info "Validating runtime status"
cerberus status || die "Cerberus status failed after deployment"

ok "Local deployment complete"
printf "Run gateway:\n"
printf "  cerberus gateway --host %s --port %s\n" "$GATEWAY_HOST" "$GATEWAY_PORT"
