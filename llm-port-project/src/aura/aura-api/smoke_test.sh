#!/usr/bin/env bash
# smoke_test.sh — aura-api HTTP smoke test suite (G11)
# Builds the binary, starts the server, curls all known endpoints,
# validates status codes, tears down. Exits 0 on all pass, 1 on any failure.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT=9000
BASE="http://127.0.0.1:${PORT}"
SERVER_PID=""
PASS=0
FAIL=0

# ── Colour helpers ─────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

pass() { echo -e "${GREEN}PASS${RESET}  $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${RESET}  $1"; FAIL=$((FAIL + 1)); }

# ── Cleanup on exit ────────────────────────────────────────────────────────────
cleanup() {
    if [[ -n "${SERVER_PID}" ]]; then
        kill "${SERVER_PID}" 2>/dev/null || true
        wait "${SERVER_PID}" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# ── 1. Build ───────────────────────────────────────────────────────────────────
echo "==> Building aura-api ..."
cd "${SCRIPT_DIR}"
zig build 2>&1
echo "==> Build OK."

BINARY="${SCRIPT_DIR}/zig-out/bin/aura-api"
if [[ ! -x "${BINARY}" ]]; then
    echo "ERROR: binary not found at ${BINARY}" >&2
    exit 1
fi

# ── 2. Start server ────────────────────────────────────────────────────────────
echo "==> Starting aura-api on port ${PORT} ..."
AURA_API_PORT="${PORT}" "${BINARY}" &
SERVER_PID=$!

# Wait up to 3 seconds for the server to be ready
READY=0
for i in $(seq 1 30); do
    if curl -sf "${BASE}/health" >/dev/null 2>&1; then
        READY=1
        break
    fi
    sleep 0.1
done

if [[ "${READY}" -eq 0 ]]; then
    echo "ERROR: server did not become ready within 3 s" >&2
    exit 1
fi
echo "==> Server ready (PID ${SERVER_PID})."

# ── 3. Helper: assert HTTP status code ────────────────────────────────────────
# check_status <label> <expected_code> <actual_code>
check_status() {
    local label="$1"
    local expected="$2"
    local actual="$3"
    if [[ "${actual}" == "${expected}" ]]; then
        pass "${label}  (HTTP ${actual})"
    else
        fail "${label}  (expected HTTP ${expected}, got HTTP ${actual})"
    fi
}

# ── 4. Curl all endpoints ──────────────────────────────────────────────────────
echo ""
echo "==> Running endpoint checks ..."

# GET /
CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE}/")
check_status "GET /" "200" "${CODE}"

# GET /health
CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE}/health")
check_status "GET /health" "200" "${CODE}"

# GET /status
CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE}/status")
check_status "GET /status" "200" "${CODE}"

# GET /mesh
CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE}/mesh")
check_status "GET /mesh" "200" "${CODE}"

# GET /providers
CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE}/providers")
check_status "GET /providers" "200" "${CODE}"

# POST /sync/session
CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -d '{"workspace_id":"test","payload":"{}"}' \
    "${BASE}/sync/session")
check_status "POST /sync/session" "200" "${CODE}"

# GET /sync/session/{id}
CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE}/sync/session/test")
check_status "GET /sync/session/test" "200" "${CODE}"

# DELETE /sync/session/{id}
CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X DELETE \
    "${BASE}/sync/session/test")
check_status "DELETE /sync/session/test" "200" "${CODE}"

# ── 5. Summary ─────────────────────────────────────────────────────────────────
echo ""
echo "==> Results: ${PASS} passed, ${FAIL} failed."

if [[ "${FAIL}" -gt 0 ]]; then
    echo "SMOKE TEST FAILED" >&2
    exit 1
fi

echo "SMOKE TEST PASSED"
exit 0
