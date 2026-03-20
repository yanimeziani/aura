import re
import time
import subprocess
import os
import sys
from pathlib import Path

# Import our local 2FA logic
sys.path.append("/home/yani/Aura/vault")
import aura_2fa

# Regex for common 2FA code patterns (4-8 digits, or alphanumeric)
# Matches: 123456, 123-456, G-123456, 1234
OTP_REGEX = r'\b(?:G-)?(\d{4,8})\b|\b(\d{3}-\d{3})\b'

def get_clipboard():
    try:
        return subprocess.check_output(['xclip', '-selection', 'clipboard', '-o'], stderr=subprocess.DEVNULL).decode('utf-8').strip()
    except:
        return ""

def set_clipboard(text):
    try:
        subprocess.run(['xclip', '-selection', 'clipboard'], input=text.encode('utf-8'), check=True)
    except:
        pass

def notify(title, message):
    try:
        subprocess.run(['notify-send', '-i', 'security-high', title, message], check=False)
    except:
        print(f"[{title}] {message}")

def run_2fa_daemon():
    print("🛡️ AURA 2FA AUTO-FILL DAEMON ACTIVE")
    print("Watching for SMS, Email, and Vault patterns...")
    
    last_clipboard = ""
    
    while True:
        current_clipboard = get_clipboard()
        
        # 1. Check for incoming OTP patterns in clipboard (from Email or Manual Copy)
        if current_clipboard != last_clipboard:
            match = re.search(OTP_REGEX, current_clipboard)
            if match:
                code = match.group(0).replace("-", "")
                if code != last_clipboard:
                    notify("🛡️ Aura 2FA Detected", f"Captured code: {code}\nReady for auto-fill.")
                    last_clipboard = code
            else:
                last_clipboard = current_clipboard

        # 2. Check for KDE Connect SMS Notifications (Simulated intercept)
        # This can be expanded to use 'kdeconnect-cli --list-notifications'
        
        time.sleep(2)

def quick_fill(service_name):
    """Command line helper to instantly fetch, notify, and copy a vault code."""
    print(f"🔍 Aura searching vault for: {service_name}")
    # This calls our existing aura_2fa logic
    aura_2fa.get_totp(service_name)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        quick_fill(sys.argv[1])
    else:
        run_2fa_daemon()
