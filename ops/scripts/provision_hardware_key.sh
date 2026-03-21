#!/bin/bash
# Meziani AI: Hardware Key Provisioning & Beacon
# This script prepares the SanDisk key for Direct Stream Auth.

USB_MOUNT="/mnt/media_rw/9D32-E916" # Target mount point
VAULT_PATH="$USB_MOUNT/.aura_vault"
BEACON_FILE="$VAULT_PATH/beacon.sig"
PRIV_KEY="/root/mlkem768_priv.pem"

echo "=== AURA: Hardware Provisioning ==="

if [ ! -d "$USB_MOUNT" ]; then
    echo "[!] Error: SanDisk USB key not detected at $USB_MOUNT"
    echo "[*] Please ensure the key is plugged and mounted."
    exit 1
fi

# 1. Create secure enclave on hardware
echo "[*] Creating hardware-gated vault..."
mkdir -p "$VAULT_PATH"
chmod 700 "$VAULT_PATH"

# 2. Migrate the Sovereign Identity
echo "[*] Transferring ML-KEM Private Key to hardware..."
if [ -f "$PRIV_KEY" ]; then
    cp "$PRIV_KEY" "$VAULT_PATH/identity.key"
    chmod 600 "$VAULT_PATH/identity.key"
    echo "[SUCCESS] Identity migrated."
else
    echo "[!] Warning: Source key $PRIV_KEY not found."
fi

# 3. Create the Sovereign Beacon (Proof of Possession)
echo "[*] Signing hardware beacon for auto-detection..."
echo "Aura Sovereign Key: 9D32-E916" > "$BEACON_FILE"
(cd /root/core/aura-signer && zig run src/main.zig -- "$BEACON_FILE") >> "$BEACON_FILE"

echo "=== Provisioning Complete. Key is ready for Stream Auth. ==="
