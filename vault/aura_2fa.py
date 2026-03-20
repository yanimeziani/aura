import os
import json
import sys
from pathlib import Path
from cryptography.fernet import Fernet
import pyotp

AURA_VAULT_DIR = Path("/home/yani/Aura/vault")
MACHINE_KEY_FILE = AURA_VAULT_DIR / ".aura_machine.key"
TOTP_VAULT = AURA_VAULT_DIR / "aura-2fa.enc"

def get_machine_key():
    if not MACHINE_KEY_FILE.exists():
        print("❌ Machine key not found. Please run browser_sync.py first to initialize the vault.")
        sys.exit(1)
    with open(MACHINE_KEY_FILE, "rb") as f:
        return f.read()

def encrypt_data(data: dict) -> bytes:
    f = Fernet(get_machine_key())
    return f.encrypt(json.dumps(data).encode())

def decrypt_data(encrypted_data: bytes) -> dict:
    f = Fernet(get_machine_key())
    return json.loads(f.decrypt(encrypted_data).decode())

def load_vault() -> dict:
    if not TOTP_VAULT.exists() or TOTP_VAULT.stat().st_size == 0:
        return {}
    try:
        with open(TOTP_VAULT, "rb") as f:
            return decrypt_data(f.read())
    except Exception as e:
        print(f"❌ Failed to decrypt 2FA vault: {e}")
        sys.exit(1)

def save_vault(data: dict):
    with open(TOTP_VAULT, "wb") as f:
        f.write(encrypt_data(data))
    os.chmod(TOTP_VAULT, 0o600)

def add_totp(name: str, secret: str):
    """Adds a new TOTP secret to the encrypted vault."""
    secret = secret.replace(" ", "").upper()
    try:
        # Validate the secret
        pyotp.TOTP(secret).now()
    except Exception as e:
        print(f"❌ Invalid TOTP secret: {e}")
        return

    vault = load_vault()
    vault[name] = secret
    save_vault(vault)
    print(f"✅ Secured 2FA secret for '{name}'.")

def get_totp(name: str):
    """Generates the current 6-digit code for a given name."""
    vault = load_vault()
    
    # Fuzzy match
    matches = [k for k in vault.keys() if name.lower() in k.lower()]
    
    if not matches:
        print(f"❌ No 2FA configuration found for '{name}'.")
        return
        
    if len(matches) > 1:
        print(f"⚠️ Multiple matches found: {', '.join(matches)}. Be more specific.")
        return
        
    actual_name = matches[0]
    secret = vault[actual_name]
    totp = pyotp.TOTP(secret)
    code = totp.now()
    
    # Try to copy to clipboard automatically
    try:
        import subprocess
        subprocess.run(['xclip', '-selection', 'clipboard'], input=code.encode('utf-8'), check=False)
        copied = " (Copied to clipboard)"
    except:
        copied = ""
        
    print(f"🔐 {actual_name}: {code}{copied}")

def list_totp():
    vault = load_vault()
    if not vault:
        print("Vault is empty.")
        return
    print("Protected 2FA Accounts:")
    for name in vault.keys():
        print(f"  - {name}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Aura Sovereign 2FA/TOTP Engine")
        print("------------------------------")
        print("Commands:")
        print("  add <name> <secret>  - Encrypt and store a new base32 TOTP secret")
        print("  get <name>           - Generate the current 6-digit code")
        print("  list                 - List all protected accounts")
        sys.exit(0)

    cmd = sys.argv[1]
    if cmd == "add" and len(sys.argv) == 4:
        add_totp(sys.argv[2], sys.argv[3])
    elif cmd == "get" and len(sys.argv) == 3:
        get_totp(sys.argv[2])
    elif cmd == "list":
        list_totp()
    else:
        print("Invalid command or arguments.")
