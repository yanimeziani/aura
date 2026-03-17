#!/usr/bin/env python3
import json
import socket
import os
import subprocess
from pathlib import Path

def get_ip():
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
        try:
            s.connect(("8.8.8.8", 80))
            return s.getsockname()[0]
        except OSError:
            return "127.0.0.1"

def main():
    config_path = Path.home() / ".cerberus" / "config.json"
    if not config_path.exists():
        print(f"Error: {config_path} not found. Run 'cerberus onboard' first.")
        return 1

    with open(config_path, "r") as f:
        config = json.load(f)

    # Use Groq API key (or fall back to vault token)
    token = config.get("models", {}).get("providers", {}).get("groq", {}).get("api_key")
    if not token or "${" in token:
        token = os.environ.get("NEXA_ACTIVATION_TOKEN", "")
    if not token:
        print("Warning: No API key found. Set NEXA_ACTIVATION_TOKEN or configure groq.api_key.")
        return 1
    
    ip = get_ip()
    port = config.get("gateway", {}).get("port", 3004)

    qr_data = f"nexo://activate?ip={ip}&port={port}&token={token}"

    print(f"\n--- NEXO OPERATOR ACTIVATION (LEVEL -1 ANCHOR) ---")
    print(f"Cell IP: {ip}")
    print(f"Gateway Port: {port}")
    print(f"\nScan this in your Pegasus app to pair this device:")
    print("-" * 40)
    
    try:
        subprocess.run(["qrencode", "-t", "UTF8", qr_data], check=True)
    except FileNotFoundError:
        print("(Note: 'qrencode' not found. Printing URI only.)")
    
    print("-" * 40)
    print(f"\nURI: {qr_data}\n")
    return 0

if __name__ == "__main__":
    exit(main())
