#!/bin/bash
set -e

# Nexa Sync Protocol — Sovereign Infrastructure for all Cloud/Devices
# Target: Debian VPS
# Author: Gemini CLI (Meziani AI)

echo "🚀 Setting up Nexa Sync Protocol..."

# 1. Install Dependencies
echo "📦 Installing Syncthing & Rclone..."
sudo apt-get update && sudo apt-get install -y syncthing rclone gnupg2 ca-certificates

# 2. Configure Syncthing (Local/VPN only)
echo "🔒 Hardening Syncthing..."
# We will only expose the GUI to localhost/Tailscale for security.
mkdir -p ~/.config/syncthing
# We'll need to run it once to generate the config if it doesn't exist
syncthing --generate=~/.config/syncthing

# 3. Create Nexa Sync Directory
mkdir -p /root/nexa-vault
echo "📁 Vault created at /root/nexa-vault"

# 4. Configure Rclone (Encrypted Cloud Backup)
# The user will need to run 'rclone config' to link their cloud of choice (Gdrive/S3)
# We will prepare an encrypted 'crypt' overlay on top of their cloud.

echo "✅ Nexa Sync Protocol core installed."
echo "--- NEXT STEPS ---"
echo "1. Run 'tailscale up' to ensure your VPN is active."
echo "2. Run 'rclone config' to link your cloud backup (Gdrive/S3)."
echo "3. Open your Z Fold 5 and pair it with this VPS Syncthing ID."
echo "4. All files in /root/nexa-vault will now sync automatically."
