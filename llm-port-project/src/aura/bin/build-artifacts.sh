#!/usr/bin/env bash
# Build final artifacts for the three sys configs:
# - mobile: aura-lynx (Zig) for Android
# - kde: aura-tui, aura-mesh, aura-lynx for this machine
# - vps: aura-api (Zig) for VPS
set -e

AURA_ROOT="${AURA_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
OUT="${AURA_ROOT}/out"
cd "$AURA_ROOT"

mkdir -p "$OUT/mobile" "$OUT/kde" "$OUT/vps"

echo "=== Building KDE (this machine) ==="
cd aura-tailscale && zig build && cp zig-out/bin/aura-mesh "$OUT/kde/" && cd ..
cd tui && zig build && cp zig-out/bin/aura-tui "$OUT/kde/" && cd ..
cd aura-lynx && zig build && cp zig-out/bin/aura-lynx "$OUT/kde/" && cd ..

echo "=== Building VPS API ==="
cd aura-api && zig build && cp zig-out/bin/aura-api "$OUT/vps/" && cd ..

echo "=== Building mobile (aura-lynx for Android) ==="
cd aura-lynx && zig build mobile 2>/dev/null || true
if [ -f aura-lynx/zig-out/mobile/aura-lynx ]; then
    cp aura-lynx/zig-out/mobile/aura-lynx "$OUT/mobile/"
    echo "  aura-lynx (aarch64-linux-android) -> out/mobile/"
else
    echo "  (Android build requires NDK; native aura-lynx in out/kde/ works on Termux)"
fi
cd ..

echo ""
echo "=== Artifacts ==="
echo "  out/kde/   : aura-tui, aura-mesh, aura-lynx (this machine)"
echo "  out/vps/   : aura-api (VPS server)"
echo "  out/mobile/: aura-lynx (Android when built)"
echo ""
echo "Run: out/kde/aura-tui | out/vps/aura-api | out/kde/aura-lynx <url>"
