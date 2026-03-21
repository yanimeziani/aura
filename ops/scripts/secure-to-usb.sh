#!/bin/bash
set -e
echo "🛡️ Securing System Vault to SanDisk USB"
echo "----------------------------------------"

PROFILE_FILE="/root/vault/aura_owner_profile.json"
if [ ! -f "$PROFILE_FILE" ]; then
    echo "❌ Profile not found at $PROFILE_FILE"
    exit 1
fi

read -s -p "Enter strong passphrase for Vault Seal: " PASSPHRASE
echo ""

echo "Sealing Vault Profile..."
python3 /root/tools/vault_seal.py "$PROFILE_FILE" "$PASSPHRASE"

SEALED_FILE="${PROFILE_FILE}.sealed"

echo "✅ Sealed artifact created: $SEALED_FILE"
echo ""
echo "Follow these steps to complete the transfer to your SanDisk USB key:"
echo "1. Plug in your SanDisk USB key."
echo "2. Identify the drive (e.g. lsblk)."
echo "3. Mount the drive: sudo mount /dev/sdX1 /mnt/usb"
echo "4. Copy the file: cp $SEALED_FILE /mnt/usb/"
echo "5. Unmount safely: sync && sudo umount /mnt/usb"
echo "6. DELETE the original sealed file from this machine."
