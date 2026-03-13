#!/bin/bash
# Dotfiles Install Script — Nord Theme
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

echo "=== Nord Dotfiles Installer ==="
echo "Source: $DOTFILES_DIR"

# Create backup directory
mkdir -p "$BACKUP_DIR"

backup_and_link() {
    local src="$1"
    local dst="$2"
    
    if [[ -e "$dst" || -L "$dst" ]]; then
        echo "  Backing up: $dst"
        mv "$dst" "$BACKUP_DIR/" 2>/dev/null || true
    fi
    
    echo "  Linking: $dst -> $src"
    ln -sf "$src" "$dst"
}

echo ""
echo "Installing dotfiles..."

# Themes
mkdir -p "$HOME/.dotfiles"
backup_and_link "$DOTFILES_DIR/themes" "$HOME/.dotfiles/themes"

# ZSH
if command -v zsh &>/dev/null; then
    echo "[zsh]"
    backup_and_link "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
fi

# Bash
echo "[bash]"
backup_and_link "$DOTFILES_DIR/bash/.bashrc" "$HOME/.bashrc"

# Tmux
if command -v tmux &>/dev/null; then
    echo "[tmux]"
    backup_and_link "$DOTFILES_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"
fi

# Starship
if command -v starship &>/dev/null; then
    echo "[starship]"
    mkdir -p "$HOME/.config"
    backup_and_link "$DOTFILES_DIR/starship/starship.toml" "$HOME/.config/starship.toml"
else
    echo "[starship] Not installed. Install with:"
    echo "  curl -sS https://starship.rs/install.sh | sh"
fi

echo ""
echo "=== Installation Complete ==="
echo "Backups saved to: $BACKUP_DIR"
echo ""
echo "Next steps:"
echo "  1. Restart your shell or run: source ~/.bashrc"
echo "  2. For tmux: tmux source ~/.tmux.conf"
echo "  3. Install Starship for best prompt: curl -sS https://starship.rs/install.sh | sh"
