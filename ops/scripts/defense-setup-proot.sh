#!/bin/bash
# Proot environment dotfile initialization

echo "=== Meziani AI: Proot Dotfiles Initialization ==="

DOTFILES_SRC="/root/archive/dotfiles"
export DOTFILES_DIR="/root/.dotfiles"

# Verify dotfiles archive exists
if [ -d "$DOTFILES_SRC" ]; then
    echo "[*] Deploying dotfiles from $DOTFILES_SRC..."
    
    # Ensure installer is executable
    chmod +x "$DOTFILES_SRC/install.sh"
    
    # Execute the installer overriding the DOTFILES_DIR path
    DOTFILES_DIR="$DOTFILES_SRC" bash "$DOTFILES_SRC/install.sh"
    
    echo ""
    echo "[*] Dotfiles successfully linked into proot environment."
    echo "[*] Use 'source ~/.bashrc' or 'source ~/.zshrc' to apply immediately."
else
    echo "[!] Error: Dotfiles archive not found at $DOTFILES_SRC"
    exit 1
fi
