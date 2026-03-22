#!/usr/bin/env bash
# Meziani AI — full mesh orchestration (Tailscale + Cerberus + VPS + mobile).
#
# Prerequisites:
#   - Same Tailscale tailnet on: workstation (Cerberus), VPS, Z Fold 5 (Tailscale app).
#   - SSH key access to VPS (BatchMode-capable).
#   - Branch pushed to origin before deploy (VPS clones/fetches origin).
#
# Usage:
#   VPS_IP=1.2.3.4 ./ops/scripts/meziani-full-mesh.sh
#   VPS_IP=… NEXA_REPO_REF=main MESH_LANDING_URL=https://nexa.meziani.ai ./ops/scripts/meziani-full-mesh.sh
#
# Z Fold 5 (yanis-z-fold5): install Tailscale from Play Store, sign into this tailnet,
#   enable MagicDNS; the phone is a mesh *client* unless you run a dev server (Termux).
#
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$REPO_ROOT"

VPS_IP="${VPS_IP:-}"
DRY_RUN="${MEZIANI_MESH_DRY_RUN:-0}"

echo "=== Meziani AI — full mesh ==="
echo "[mesh] repo: $REPO_ROOT"

if command -v tailscale >/dev/null 2>&1; then
  echo "[mesh] Tailscale peers (excerpt):"
  tailscale status 2>/dev/null | head -20 || echo "[mesh] (tailscale status failed)"
else
  echo "[mesh] tailscale CLI not found; install on nodes for encrypted transport."
fi

if [[ -z "$VPS_IP" ]]; then
  echo "[mesh] ERROR: set VPS_IP to your Hostinger (or edge) server." >&2
  echo "[mesh] Example: VPS_IP=89.116.170.202 $0" >&2
  exit 1
fi

if [[ -z "${NEXA_REPO_REF:-}" ]]; then
  NEXA_REPO_REF="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
  export NEXA_REPO_REF
fi
echo "[mesh] NEXA_REPO_REF=$NEXA_REPO_REF — ensure 'git push origin $NEXA_REPO_REF' completed."

REMOTE_REPO_URL="${NEXA_REPO_URL:-}"
if [[ -z "$REMOTE_REPO_URL" ]]; then
  REMOTE_REPO_URL="$(git remote get-url origin 2>/dev/null || true)"
  if [[ -n "$REMOTE_REPO_URL" ]]; then
    export NEXA_REPO_URL="$REMOTE_REPO_URL"
    echo "[mesh] NEXA_REPO_URL=$NEXA_REPO_URL"
  fi
fi

echo "[mesh] Cerberus agents (VPS): after deploy, on the server:"
echo "       systemctl enable --now cerberus-career-twin cerberus-sdr cerberus-devsecops  # if units installed"
echo "       See: ops/scripts/deploy-to-vps.sh ops/config/cerberus-*.service"

if [[ "$DRY_RUN" == "1" ]]; then
  echo "[mesh] DRY_RUN=1 — skipping deploy-mesh.sh and smoke test."
  exit 0
fi

echo "[mesh] Running deploy-mesh.sh → ${VPS_IP} …"
chmod +x "$REPO_ROOT/ops/scripts/deploy-mesh.sh"
VPS_IP="$VPS_IP" REPO_ROOT="$REPO_ROOT" NEXA_ROOT="$REPO_ROOT" \
  ./ops/scripts/deploy-mesh.sh

if [[ -n "${MESH_LANDING_URL:-}" ]]; then
  echo "[mesh] Smoke test (MESH_LANDING_URL=$MESH_LANDING_URL)…"
  chmod +x "$REPO_ROOT/ops/scripts/smoke-test-mesh.sh"
  MESH_VPS_IP="$VPS_IP" MESH_BASE_URL="$MESH_LANDING_URL" \
    ./ops/scripts/smoke-test-mesh.sh
else
  echo "[mesh] Set MESH_LANDING_URL to run smoke-test-mesh.sh automatically (optional)."
fi

echo "[mesh] Done. Public ingress (Caddy → Tailscale → local nginx) is outside this script; see docs/NETWORKING_INGRESS_EGRESS.md"
