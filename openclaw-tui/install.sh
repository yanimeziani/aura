#!/usr/bin/env bash
# install.sh — build and install openclaw-tui on Termux
# Usage: bash install.sh [--release]
set -euo pipefail

MODE="${1:---release}"
BIN_DIR="$HOME/bin"

info()  { printf '\033[0;36m[install]\033[0m %s\n' "$*"; }
ok()    { printf '\033[0;32m[install]\033[0m %s\n' "$*"; }
err()   { printf '\033[0;31m[install]\033[0m %s\n' "$*" >&2; exit 1; }
need()  { command -v "$1" &>/dev/null || err "Missing: $1 — install with: pkg install $1"; }

# ── preflight ─────────────────────────────────────────────────────────────────
need cargo
need ssh
need rustc

RUST_VER=$(rustc --version)
info "Rust: $RUST_VER"

# ── optional Termux libs ───────────────────────────────────────────────────────
# openclaw-tui is pure-SSH, no native libs needed beyond standard toolchain.

# ── build ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ "$MODE" == "--release" ]]; then
    info "Building (release)…"
    cargo build --release
    SRC="target/release/openclaw-tui"
else
    info "Building (debug)…"
    cargo build
    SRC="target/debug/openclaw-tui"
fi

# ── install ───────────────────────────────────────────────────────────────────
mkdir -p "$BIN_DIR"
cp "$SRC" "$BIN_DIR/openclaw-tui"
chmod +x "$BIN_DIR/openclaw-tui"
ok "Installed → $BIN_DIR/openclaw-tui"

# Ensure ~/bin is on PATH
if ! echo "$PATH" | grep -q "$BIN_DIR"; then
    info "Adding $BIN_DIR to PATH in ~/.bashrc"
    echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
    info "Run: source ~/.bashrc  (or restart Termux)"
fi

# ── config scaffold ───────────────────────────────────────────────────────────
CONFIG_DIR="$HOME/.config/openclaw-tui"
CONFIG_FILE="$CONFIG_DIR/config.toml"

if [[ ! -f "$CONFIG_FILE" ]]; then
    mkdir -p "$CONFIG_DIR"
    cp "$SCRIPT_DIR/config.example.toml" "$CONFIG_FILE"
    ok "Config created → $CONFIG_FILE"
    info "Edit it with your VPS details before running:"
    info "  nano $CONFIG_FILE"
else
    info "Config already exists at $CONFIG_FILE — skipping."
fi

ok "Done. Run: openclaw-tui"
