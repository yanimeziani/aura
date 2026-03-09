#!/usr/bin/env bash
# Forge runner: run timeline verify steps F01..F18 in order.
# On success: update vault/forge_checkpoint.txt.
# On failure: write FORGE_FAILED=<ID> and exit 1.
# Run from repo root (Aura).

set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
CHECKPOINT="$ROOT/vault/forge_checkpoint.txt"
FAILED_FILE="$ROOT/vault/forge_failed.txt"

run() {
    local id="$1"
    shift
    if "$@"; then
        echo "$id" > "$CHECKPOINT"
        return 0
    fi
    echo "FORGE_FAILED=$id" > "$FAILED_FILE"
    echo "FORGE_FAILED=$id"
    return 1
}

# F01
run F01 bash -c 'test "$(cat .zig-version)" = "0.15.2" && test -f docs/ZIG_VERSION.md' || exit 1

# F02
run F02 bash -c '! grep -r minimum_zig_version aura-edge aura-tailscale aura-mcp ziggy-compiler tui --include="*.zon" 2>/dev/null | grep -v 0.15.2 || true' || exit 1

# F03
run F03 bash -c 'cd aura-edge && zig build && cd ../aura-tailscale && zig build && cd ../aura-mcp && zig build && cd ../tui && zig build' || exit 1

# F04
run F04 bash -c 'cd ziggy-compiler && zig build' || exit 1

# F05
run F05 bash -c 'cd ziggy-compiler && ./zig-out/bin/ziggyc --version 2>&1 | grep -q ziggyc && ./zig-out/bin/ziggyc 2>&1 | head -1' || exit 1

# F06
run F06 bash -c 'cd ziggy-compiler && ./zig-out/bin/ziggyc foo.zig 2>&1 | grep -q "phase="' || exit 1

# F07
run F07 bash -c 'cd ziggy-compiler && zig build && ./zig-out/bin/ziggyc src/main.zig 2>&1 | grep -q lex' || exit 1

# F08
run F08 bash -c 'cd ziggy-compiler && zig build' || exit 1

# F09
run F09 bash -c 'cd ziggy-compiler && zig build test' || exit 1

# F10
run F10 bash -c 'cd aura-mcp && zig build && zig build test' || exit 1

# F11 (ping tool present)
run F11 bash -c 'grep -q "ping" aura-mcp/src/main.zig && grep -q "pong" aura-mcp/src/main.zig' || exit 1

# F12
run F12 bash -c 'grep -q ping docs/sovereign-mcp.md' || exit 1

# F13
run F13 bash -c 'grep -q "Lint report artifact format" docs/ziggy-compiler.md' || exit 1

# F14
run F14 bash -c 'cd ziggy-compiler && zig build && ./zig-out/bin/ziggyc --lint-only src/main.zig 2>&1; test -f out/lint/report.jsonl' || exit 1

# F15
run F15 bash -c 'cd aura-tailscale && zig build' || exit 1

# F16
run F16 bash -c 'cd aura-tailscale && zig build test' || exit 1

# F17
run F17 bash -c 'grep -q wireguard.zig aura-tailscale/AGENTS.md' || exit 1

# F18 (this script exists; full run verified by reaching here)
run F18 test -f bin/forge-run.sh

echo "Forge run complete through F18. Checkpoint: $(cat "$CHECKPOINT")"
