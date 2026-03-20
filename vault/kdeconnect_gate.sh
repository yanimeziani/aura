#!/bin/bash
echo "🛡️ AURA SOVEREIGN 2FA GATE IS OPEN"
echo "--------------------------------"
echo "1. Export accounts in Google Authenticator on your phone."
echo "2. Scan the QR code using any QR reader on your phone."
echo "3. Tap 'Share' -> 'KDE Connect' -> Select this PC ('fedora')."
echo "4. I will detect the URI and import all accounts instantly."
echo "--------------------------------"
echo "📡 Listening for incoming 2FA migration URI..."

# Wait for a clipboard or direct share that contains the migration URI
while true; do
    URI=$(xclip -o -selection clipboard 2>/dev/null | grep -i "otpauth-migration://")
    if [ ! -z "$URI" ]; then
        echo -e "\n📦 URI DETECTED! Importing to Aura Vault..."
        python3 /home/yani/Aura/vault/google_auth_import.py "$URI"
        
        # Clear clipboard for security
        echo -n "" | xclip -i -selection clipboard
        echo "🧹 Clipboard cleared. 🛡️ Aura 2FA Vault is now SECURE."
        break
    fi
    sleep 2
done
