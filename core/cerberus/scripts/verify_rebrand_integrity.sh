#!/usr/bin/env bash
# verify_rebrand_integrity.sh
# Quick integrity checks for rebranded Cerberus tree.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="${TARGET_DIR:-${ROOT_DIR}/runtime/cerberus-core}"

for arg in "$@"; do
  case "$arg" in
    --target=*) TARGET_DIR="${arg#*=}" ;;
  esac
done

info() { printf '\033[0;34m[verify]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[verify]\033[0m %s\n' "$*"; }
warn() { printf '\033[0;33m[verify]\033[0m %s\n' "$*"; }
fail() { printf '\033[0;31m[verify]\033[0m %s\n' "$*"; exit 1; }

[[ -d "$TARGET_DIR" ]] || fail "Target directory not found: $TARGET_DIR"

info "Checking required files"
required=(
  "$TARGET_DIR/build.zig"
  "$TARGET_DIR/build.zig.zon"
  "$TARGET_DIR/src/main.zig"
  "$TARGET_DIR/README.md"
)
for f in "${required[@]}"; do
  [[ -f "$f" ]] || fail "Missing required file: $f"
done
ok "Required files present"

info "Checking binary/module naming"
grep -q '\.name = "cerberus"' "$TARGET_DIR/build.zig" || fail "build.zig does not define executable name as cerberus"
grep -q '\.name = \.cerberus' "$TARGET_DIR/build.zig.zon" || warn "build.zig.zon package name may still be legacy"
ok "Naming check completed"

info "Scanning for legacy branding tokens"
if grep -RIn \
  --exclude-dir=".git" \
  --exclude-dir="sqlite3" \
  --exclude-dir="reports" \
  --exclude="LICENSE" \
  --exclude="UPSTREAM.md" \
  --exclude="nullclaw" \
  -E "nullclaw|NullClaw|NULLCLAW" "$TARGET_DIR" >/dev/null; then
  warn "Legacy tokens remain. Review with:"
  printf "  grep -RIn --exclude-dir='.git' --exclude-dir='sqlite3' --exclude-dir='reports' --exclude='LICENSE' --exclude='UPSTREAM.md' --exclude='nullclaw' -E 'nullclaw|NullClaw|NULLCLAW' %s\n" "$TARGET_DIR"
else
  ok "No legacy tokens found in scanned files"
fi

info "Checking compatibility shim"
[[ -x "$TARGET_DIR/scripts/compat/nullclaw" ]] || fail "Compatibility shim missing or not executable"
ok "Compatibility shim present"

ok "Integrity checks complete"
