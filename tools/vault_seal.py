import sys
import os
import subprocess

# Sovereign Vault Seal
# Use this to encrypt your keys/seeds before moving them to the SanDisk.
# Requires: gpg (Standard on Debian/Ubuntu)

def seal_file(file_path, passphrase):
    """Encrypts a file using AES-256 via GPG."""
    if not os.path.exists(file_path):
        print(f"❌ File not found: {file_path}")
        return

    output_path = file_path + ".sealed"
    try:
        # Using GPG for military-grade symmetric encryption
        cmd = [
            "gpg", "--symmetric", "--batch", "--yes",
            "--passphrase", passphrase,
            "--cipher-algo", "AES256",
            "-o", output_path,
            file_path
        ]
        subprocess.check_call(cmd)
        print(f"✅ Vault Sealed: {output_path}")
        print("⚠️ MOVE THIS FILE TO YOUR SANDISK DRIVE AND DELETE THE ORIGINAL.")
    except Exception as e:
        print(f"❌ Sealing failed: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 vault_seal.py <file_to_seal> <strong_passphrase>")
    else:
        seal_file(sys.argv[1], sys.argv[2])
