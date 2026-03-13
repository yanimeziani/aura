#!/usr/bin/env bash
# build.sh — install Rust if needed, then compile cctui
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v cargo &>/dev/null; then
    echo "[cctui] Rust not found — installing via rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --profile minimal --default-toolchain stable
    # shellcheck source=/dev/null
    source "$HOME/.cargo/env"
fi

echo "[cctui] Building (release)..."
cd "$SCRIPT_DIR"
cargo build --release 2>&1

BIN="$SCRIPT_DIR/target/release/cctui"
echo "[cctui] Built: $BIN"

# Optional: symlink into ~/bin if it exists
if [[ -d "$HOME/bin" ]]; then
    ln -sf "$BIN" "$HOME/bin/cctui"
    echo "[cctui] Symlinked to ~/bin/cctui"
fi
