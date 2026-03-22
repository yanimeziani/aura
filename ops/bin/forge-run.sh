#!/usr/bin/env bash
# Forge runner: run timeline verify steps F01..F19 in order.
# On success: update vault/forge_checkpoint.txt.
# On failure: write FORGE_FAILED=<ID>, append a dispatch note to the roster
# channel, and exit 1.
# Run from repo root (Aura).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CHECKPOINT="${FORGE_CHECKPOINT_FILE:-$ROOT/vault/forge_checkpoint.txt}"
FAILED_FILE="${FORGE_FAILED_FILE:-$ROOT/vault/forge_failed.txt}"
CHANNEL_FILE="${FORGE_CHANNEL_FILE:-$ROOT/vault/roster/CHANNEL.md}"
FORGE_ONLY="${FORGE_ONLY:-}"
FORCE_FAIL_ID="${FORGE_FORCE_FAIL_ID:-}"
LAST_SUCCESS="$(cat "$CHECKPOINT" 2>/dev/null || true)"

: > "$FAILED_FILE"

timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

selected() {
    local id="$1"
    if [ -z "$FORGE_ONLY" ]; then
        return 0
    fi
    case ",$FORGE_ONLY," in
        *,"$id",*) return 0 ;;
        *) return 1 ;;
    esac
}

owner_for() {
    case "$1" in
        F04|F05|F06|F07|F08|F09|F10|F11|F12|F13|F14|F15|F16|F17)
            printf '%s\n' "Implementer"
            ;;
        *)
            printf '%s\n' "Runner"
            ;;
    esac
}

task_summary() {
    case "$1" in
        F01) printf '%s\n' "Verify Zig version lock and docs are present." ;;
        F02) printf '%s\n' "Verify first-party build.zig.zon files stay pinned to Zig 0.13.0 with empty dependencies." ;;
        F03) printf '%s\n' "Restore green builds for the four core Zig projects." ;;
        F04) printf '%s\n' "Restore ziggy-compiler build integrity." ;;
        F05) printf '%s\n' "Restore ziggy-compiler CLI contract (--version, no-input behavior, exit 0)." ;;
        F06) printf '%s\n' "Restore structured progress logging in ziggy-compiler." ;;
        F07) printf '%s\n' "Restore lex phase invocation in ziggy-compiler." ;;
        F08) printf '%s\n' "Restore alarms.zig integration/build health." ;;
        F09) printf '%s\n' "Restore artifacts.zig and test coverage." ;;
        F10) printf '%s\n' "Restore aura-mcp build and test health." ;;
        F11) printf '%s\n' "Restore aura-mcp ping tool behavior." ;;
        F12) printf '%s\n' "Keep sovereign-mcp docs aligned with exposed tools." ;;
        F13) printf '%s\n' "Keep lint artifact format documented in ziggy-compiler docs." ;;
        F14) printf '%s\n' "Restore --lint-only output and report artifact generation." ;;
        F15) printf '%s\n' "Restore aura-tailscale WireGuard module build health." ;;
        F16) printf '%s\n' "Restore aura-tailscale tests for wireguard/hash behavior." ;;
        F17) printf '%s\n' "Keep aura-tailscale AGENTS docs aligned with wireguard module." ;;
        F18) printf '%s\n' "Keep forge runner script present and executable in repo." ;;
        F19) printf '%s\n' "Keep forge timeline checkpoint contract aligned with runner state handling." ;;
        *) printf '%s\n' "Restore forge task contract for $1." ;;
    esac
}

append_channel() {
    local role="$1"
    local id="$2"
    local subject="$3"
    local body="$4"

    mkdir -p "$(dirname "$CHANNEL_FILE")"
    {
        printf '\n[%s] [%s] %s\n' "$role" "$id" "$subject"
        printf '%s\n' "$body"
    } >> "$CHANNEL_FILE"
}

dispatch_failure() {
    local id="$1"
    local verify="$2"
    local owner
    owner="$(owner_for "$id")"

    append_channel \
        "Runner" \
        "$id" \
        "VERIFY FAILED" \
        "Time: $(timestamp)
Verify: \`$verify\`
Last success: ${LAST_SUCCESS:-none}
Dispatch owner: $owner"

    if [ "$owner" = "Implementer" ]; then
        append_channel \
            "Implementer" \
            "$id" \
            "DISPATCHED by Runner" \
            "Time: $(timestamp)
Task: $(task_summary "$id")
Restore verify target: \`$verify\`
Source: bin/forge-run.sh auto-dispatch on verification failure."
    fi
}

manual_dispatch() {
    local id="$1"
    shift || true
    local note="${*:-Manual dispatch requested by runner operator.}"

    append_channel \
        "Runner" \
        "$id" \
        "MANUAL DISPATCH" \
        "Time: $(timestamp)
Note: $note"

    append_channel \
        "Implementer" \
        "$id" \
        "DISPATCHED by Runner" \
        "Time: $(timestamp)
Task: $(task_summary "$id")
Note: $note"
}

run() {
    local id="$1"
    shift

    if ! selected "$id"; then
        return 0
    fi

    local verify_cmd="$*"

    if [ -n "$FORCE_FAIL_ID" ] && [ "$FORCE_FAIL_ID" = "$id" ]; then
        printf 'FORGE_FAILED=%s\n' "$id" > "$FAILED_FILE"
        dispatch_failure "$id" "$verify_cmd"
        printf 'FORGE_FAILED=%s\n' "$id"
        return 1
    fi

    if "$@"; then
        printf '%s\n' "$id" > "$CHECKPOINT"
        LAST_SUCCESS="$id"
        return 0
    fi

    printf 'FORGE_FAILED=%s\n' "$id" > "$FAILED_FILE"
    dispatch_failure "$id" "$verify_cmd"
    printf 'FORGE_FAILED=%s\n' "$id"
    return 1
}

case "${1:-run}" in
    dispatch)
        shift
        if [ $# -lt 1 ]; then
            echo "Usage: bin/forge-run.sh dispatch <Fnn> [note]"
            exit 2
        fi
        manual_dispatch "$@"
        echo "Dispatch written for $1"
        exit 0
        ;;
    run)
        shift || true
        ;;
    *)
        ;;
esac

# F01
run F01 bash -c 'test "$(tr -d "\r\n" < .zig-version)" = "0.13.0" && test -f docs/ZIG_VERSION.md' || exit 1

# F02
run F02 bash -c 'for z in core/nexa-gateway/build.zig.zon core/aura-mcp/build.zig.zon; do grep -q "minimum_zig_version = \"0.13.0\"" "$z" || exit 1; grep -q ".dependencies = .{}" "$z" || exit 1; done' || exit 1

# F03
run F03 bash -c 'cd core/nexa-gateway && zig build && cd ../aura-mcp && zig build' || exit 1

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
run F10 bash -c 'cd core/aura-mcp && zig build && zig build test' || exit 1

# F11 (ping tool present)
run F11 bash -c 'grep -q "ping" core/aura-mcp/src/main.zig && grep -q "pong" core/aura-mcp/src/main.zig' || exit 1

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

# F18
run F18 test -f bin/forge-run.sh || exit 1

# F19
run F19 bash -c 'grep -q "vault/forge_checkpoint.txt" docs/forge-timeline.md && test -f vault/forge_checkpoint.txt' || exit 1

echo "Forge run complete through $(cat "$CHECKPOINT")"
