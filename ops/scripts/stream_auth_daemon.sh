#!/bin/bash
# Meziani AI: Direct Stream Auth Daemon
# Polling service to detect hardware key and unlock the system.

USB_MOUNT="/mnt/media_rw/9D32-E916"
BEACON="$USB_MOUNT/.aura_vault/beacon.sig"
SSH_KEY_SOURCE="$USB_MOUNT/.aura_vault/identity.key"
SSH_KEY_TARGET="/root/.ssh/id_rsa"

echo "=== Direct Stream Auth: Monitoring for Hardware Key ==="

while true; do
    if [ -f "$BEACON" ]; then
        if [ ! -L "$SSH_KEY_TARGET" ]; then
            echo "[*] KEY DETECTED: Initializing Stream Auth..."
            # Link identity
            ln -sf "$SSH_KEY_SOURCE" "$SSH_KEY_TARGET"
            
            # Notify Mission Control (Mock signal)
            echo "AUTH_ARMED" > /tmp/system_auth_status
            
            echo "[*] Identity Stream: ACTIVE. System Armed."
        fi
    else
        if [ -L "$SSH_KEY_TARGET" ]; then
            echo "[!] KEY REMOVED: Terminating Stream Auth..."
            rm -f "$SSH_KEY_TARGET"
            echo "AUTH_LOCKED" > /tmp/system_auth_status
            echo "[!] Identity Stream: SEVERED. System Locked."
        fi
    fi
    sleep 5 # Poll every 5 seconds
done
