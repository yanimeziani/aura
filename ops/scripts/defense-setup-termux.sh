#!/data/data/com.termux/files/usr/bin/bash
# Termux Hardening Setup for Meziani AI Global Defense System

echo "=== Meziani AI: Termux Hardening Protocol ==="

# 1. Update system packages
echo "[*] Updating base packages to secure baselines..."
pkg update -y && pkg upgrade -y

# 2. Install critical defense dependencies
echo "[*] Ensuring secure dependencies..."
pkg install -y openssh gnupg termux-api proot git zsh starship

# 3. Lockdown SSHD
SSHD_CONFIG="$PREFIX/etc/ssh/sshd_config"
echo "[*] Enforcing key-based authentication in sshd..."
if [ -f "$SSHD_CONFIG" ]; then
    if grep -q "PasswordAuthentication" "$SSHD_CONFIG"; then
        sed -i 's/.*PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
    else
        echo "PasswordAuthentication no" >> "$SSHD_CONFIG"
    fi

    # Disable root login over SSH if explicitly defined
    if grep -q "PermitRootLogin" "$SSHD_CONFIG"; then
        sed -i 's/.*PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"
    else
        echo "PermitRootLogin no" >> "$SSHD_CONFIG"
    fi
else
    echo "[!] Warning: sshd_config not found at $SSHD_CONFIG"
fi

# 4. Termux storage prep
echo "[*] Securing Termux storage..."
termux-setup-storage

echo "=== Termux Setup & Hardening Complete ==="
