#!/usr/bin/env bash
# prepare_cerberus_vps.sh
# Prepare Debian VPS for Cerberus migration from OpenClaw.
# Non-destructive by default. Optional wipe mode requires explicit confirmation.

set -euo pipefail

CERBERUS_USER="${CERBERUS_USER:-cerberus}"
DATA_DIR="${DATA_DIR:-/data}"
CERBERUS_DIR="${DATA_DIR}/cerberus"
OPENCLAW_DIR="${DATA_DIR}/openclaw"
BACKUP_DIR="${DATA_DIR}/backups"

WIPE_OPENCLAW=false
for arg in "$@"; do
  case "$arg" in
    --wipe-openclaw) WIPE_OPENCLAW=true ;;
  esac
done

info()  { printf '\033[0;34m[cerberus]\033[0m %s\n' "$*"; }
ok()    { printf '\033[0;32m[cerberus]\033[0m %s\n' "$*"; }
warn()  { printf '\033[0;33m[cerberus]\033[0m %s\n' "$*"; }
fatal() { printf '\033[0;31m[cerberus]\033[0m %s\n' "$*"; exit 1; }

if [[ "$EUID" -ne 0 ]]; then
  fatal "Run as root or with sudo."
fi

info "Preparing VPS directories for Cerberus"
mkdir -p \
  "${CERBERUS_DIR}/config" \
  "${CERBERUS_DIR}/artifacts/devsecops" \
  "${CERBERUS_DIR}/artifacts/growth" \
  "${CERBERUS_DIR}/logs" \
  "${CERBERUS_DIR}/hitl-queue/pending" \
  "${CERBERUS_DIR}/hitl-queue/approved" \
  "${CERBERUS_DIR}/hitl-queue/rejected" \
  "${CERBERUS_DIR}/task-queue" \
  "${CERBERUS_DIR}/auth" \
  "${BACKUP_DIR}"

if ! id "$CERBERUS_USER" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "$CERBERUS_USER"
  usermod -aG docker "$CERBERUS_USER" || true
  ok "Created user ${CERBERUS_USER}"
else
  ok "User ${CERBERUS_USER} already exists"
fi

chown -R "${CERBERUS_USER}:${CERBERUS_USER}" "${CERBERUS_DIR}"
ok "Cerberus directory ownership set"

if [[ -d "${OPENCLAW_DIR}" ]]; then
  ts="$(date -u +%Y%m%dT%H%M%SZ)"
  archive="${BACKUP_DIR}/openclaw-pre-cerberus-${ts}.tar.gz"
  info "Backing up ${OPENCLAW_DIR} to ${archive}"
  tar -C "${DATA_DIR}" -czf "${archive}" "openclaw"
  ok "Backup complete"
else
  warn "OpenClaw directory not found at ${OPENCLAW_DIR}; skipping backup"
fi

if $WIPE_OPENCLAW; then
  [[ "${CERBERUS_CONFIRM_WIPE:-}" == "YES" ]] || fatal "Set CERBERUS_CONFIRM_WIPE=YES to allow --wipe-openclaw"
  warn "Wipe mode enabled: stopping/removing known OpenClaw containers"
  for c in openclaw agent-devsecops agent-growth caddy vector uptime-check; do
    docker rm -f "$c" >/dev/null 2>&1 || true
  done
  docker network rm openclaw >/dev/null 2>&1 || true
  warn "OpenClaw containers/network removed (volumes and backups retained)"
fi

ok "Preparation complete"
printf "Next:\n"
printf "  1) Clone Cerberus private repo into %s/config\n" "${CERBERUS_DIR}"
printf "  2) Import preserved prompts/MCP/policies\n"
printf "  3) Configure runtime env + Claude auth mount\n"
printf "  4) Start Cerberus stack and run smoke tests\n"
