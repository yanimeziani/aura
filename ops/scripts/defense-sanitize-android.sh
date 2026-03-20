#!/data/data/com.termux/files/usr/bin/bash
# Android-level Automated Sanitization for Meziani AI Global Defense System
# Target: Termux native environment (Android 16)

echo "=== Meziani AI: Android-Level Sanitization Protocol ==="
echo "Initiating defense environment sanitization..."

# 1. Clear system clipboards via termux-api
if command -v termux-clipboard-set &> /dev/null; then
    echo "[*] Sanitizing clipboard memory..."
    termux-clipboard-set ""
else
    echo "[!] Warning: termux-api not installed. Clipboard not cleared."
fi

# 2. Wipe standard cache directories in internal storage
CACHE_DIRS=(
    "/storage/emulated/0/Android/data/*/cache"
    "/storage/emulated/0/Download/*"
    "$HOME/.cache"
)

for dir in "${CACHE_DIRS[@]}"; do
    echo "[*] Purging cached state from $dir..."
    find $dir -type f -delete 2>/dev/null || true
done

# 3. Purge orphaned temp files
echo "[*] Cleaning temporary execution paths..."
find /data/data/com.termux/files/usr/tmp -type f -delete 2>/dev/null || true

# 4. Enforce strict permissions on Meziani AI critical folders
echo "[*] Hardening vault and critical path permissions..."
chmod 700 /root/vault 2>/dev/null || true
chmod 600 /root/vault/* 2>/dev/null || true
chmod 700 /root/.ssh 2>/dev/null || true
chmod 600 /root/.ssh/* 2>/dev/null || true
chmod 700 /root/.gnupg 2>/dev/null || true

echo "=== Android-Level Sanitization Complete ==="
