#!/usr/bin/env bash
# Smoke-test deployed mesh services from the outside.
# Usage: MESH_VPS_IP=1.2.3.4 MESH_BASE_URL=https://example.com ./ops/scripts/smoke-test-mesh.sh
# Exits 0 if all pass, non-zero otherwise.
set -euo pipefail

VPS_IP="${MESH_VPS_IP:-}"
if [[ -z "$VPS_IP" ]]; then
  echo "[smoke] FAIL: set MESH_VPS_IP or VPS_IP before running smoke test." >&2
  exit 1
fi

PUBLIC_BASE_URL="${MESH_BASE_URL:-${MESH_LANDING_URL:-${NEXA_PUBLIC_BASE_URL:-${AURA_PUBLIC_BASE_URL:-}}}}"
if [[ -z "$PUBLIC_BASE_URL" ]]; then
  if [[ -n "${VPS_DOMAIN:-}" ]]; then
    PUBLIC_BASE_URL="https://${VPS_DOMAIN}"
  else
    PUBLIC_BASE_URL="http://${VPS_IP}"
  fi
fi

GATEWAY_URL="${MESH_GATEWAY_URL:-${PUBLIC_BASE_URL%/}/gw}"
WEB_URL="${MESH_WEB_URL:-${PUBLIC_BASE_URL%/}}"
SKIP_WEB_HEALTH="${MESH_SKIP_WEB_HEALTH:-0}"
SKIP_GATEWAY_INGRESS="${MESH_SKIP_GATEWAY_INGRESS:-0}"
ALLOW_INSECURE_TLS="${MESH_ALLOW_INSECURE_TLS:-0}"

fail() { echo "[smoke] FAIL: $*"; exit 1; }
ok()   { echo "[smoke] OK: $*"; }

CURL_ARGS=(-s --connect-timeout 10)
if [ "$ALLOW_INSECURE_TLS" = "1" ]; then
  CURL_ARGS+=(-k)
fi

echo "[smoke] Testing mesh (VPS=$VPS_IP, Base URL=$PUBLIC_BASE_URL, Gateway=$GATEWAY_URL, Web=$WEB_URL)..."

if [ "$SKIP_GATEWAY_INGRESS" != "1" ]; then
  # 1. Gateway health
  code=$(curl "${CURL_ARGS[@]}" -o /dev/null -w '%{http_code}' "${GATEWAY_URL}/health" || true)
  if [ "$code" != "200" ]; then
    fail "gateway /health returned $code (expected 200)"
  fi
  ok "gateway /health 200"

  # 2. Gateway specs
  code=$(curl "${CURL_ARGS[@]}" -o /dev/null -w '%{http_code}' "${GATEWAY_URL}/api/specs" || true)
  if [ "$code" != "200" ]; then
    fail "gateway /api/specs returned $code"
  fi
  ok "gateway /api/specs 200"
fi

# 3. Base URL response
code=$(curl "${CURL_ARGS[@]}" -o /dev/null -w '%{http_code}' -L "$PUBLIC_BASE_URL/" || true)
if [ "$code" != "200" ]; then
  fail "base URL returned $code (expected 200)"
fi
ok "base URL $code"

# 4. Base URL contains expected content
body=$(curl "${CURL_ARGS[@]}" -L "$PUBLIC_BASE_URL/" || true)
if ! echo "$body" | grep -Eqi "Nexa|HTTP|mesh|Dragun|debt recovery"; then
  fail "base URL content check failed"
fi
ok "base URL content check"

if [ "$SKIP_GATEWAY_INGRESS" != "1" ]; then
  # 5. Gateway validation route through HTTP ingress
  code=$(curl "${CURL_ARGS[@]}" -o /dev/null -w '%{http_code}' \
    -H 'Content-Type: application/json' \
    -d '{"email":"smoke@example.com"}' \
    "${GATEWAY_URL}/api/validate-access" || true)
  if [ "$code" != "200" ]; then
    fail "gateway validation route returned $code"
  fi
  ok "gateway validation route 200"
fi

if [ "$SKIP_WEB_HEALTH" != "1" ]; then
  # 6. Self-hosted web app health
  code=$(curl "${CURL_ARGS[@]}" -o /dev/null -w '%{http_code}' "${WEB_URL}/api/health" || true)
  if [ "$code" != "200" ]; then
    fail "web /api/health returned $code"
  fi
  ok "web /api/health 200"
fi

echo "[smoke] All checks passed."
