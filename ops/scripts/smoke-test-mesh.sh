#!/usr/bin/env bash
# Smoke-test deployed mesh from the outside (in-house Zig gateway only).
# Usage: MESH_VPS_IP=1.2.3.4 MESH_LANDING_URL=https://example.com ./ops/scripts/smoke-test-mesh.sh
# Exits 0 if all pass, non-zero otherwise.
set -euo pipefail

VPS_IP="${MESH_VPS_IP:-}"
if [[ -z "$VPS_IP" ]]; then
  echo "[smoke] FAIL: set MESH_VPS_IP or VPS_IP before running smoke test." >&2
  exit 1
fi

PUBLIC_BASE_URL="${NEXA_PUBLIC_BASE_URL:-${AURA_PUBLIC_BASE_URL:-}}"
if [[ -z "$PUBLIC_BASE_URL" ]]; then
  if [[ -n "${VPS_DOMAIN:-}" ]]; then
    PUBLIC_BASE_URL="https://${VPS_DOMAIN}"
  else
    PUBLIC_BASE_URL="http://${VPS_IP}"
  fi
fi

GATEWAY_URL="${MESH_GATEWAY_URL:-${PUBLIC_BASE_URL%/}}"

fail() { echo "[smoke] FAIL: $*"; exit 1; }
ok()   { echo "[smoke] OK: $*"; }

echo "[smoke] Testing mesh (VPS=$VPS_IP, Gateway=$GATEWAY_URL)..."

# 1. Gateway health
code=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 10 "${GATEWAY_URL}/health" || true)
if [ "$code" != "200" ]; then
  fail "gateway /health returned $code (expected 200)"
fi
ok "gateway /health 200"

# 2. Gateway specs
code=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 10 "${GATEWAY_URL}/api/specs" || true)
if [ "$code" != "200" ]; then
  fail "gateway /api/specs returned $code"
fi
ok "gateway /api/specs 200"

# 3. Mission Control shell
code=$(curl -s -o /dev/null -w '%{http_code}' -L --connect-timeout 10 "$GATEWAY_URL/" || true)
if [ "$code" != "200" ]; then
  fail "mission control returned $code (expected 200)"
fi
ok "mission control $code"

# 4. Mission control contains expected content
body=$(curl -s -L --connect-timeout 10 "$GATEWAY_URL/" || true)
if ! echo "$body" | grep -Eqi "Nexa Lite|Mission Control|supply chain"; then
  fail "mission control page missing expected content"
fi
ok "mission control content check"

# 5. Docs bundle
code=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 10 "${GATEWAY_URL}/docs/nexa" || true)
if [ "$code" != "200" ]; then
  fail "docs bundle returned $code"
fi
ok "docs bundle 200"

echo "[smoke] All checks passed."
