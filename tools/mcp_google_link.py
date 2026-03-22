#!/usr/bin/env python3
import os
import subprocess
import sys
from pathlib import Path

def get_nexa_root():
    return Path(__file__).resolve().parents[1]

def run_server():
    root = get_nexa_root()
    google_mcp_dir = root / "core" / "google-mcp"
    
    if not google_mcp_dir.exists():
        print("❌ Google MCP directory not found at core/google-mcp")
        return 1

    # Check for credentials in environment or vault
    client_id = os.environ.get("GOOGLE_OAUTH_CLIENT_ID")
    client_secret = os.environ.get("GOOGLE_OAUTH_CLIENT_SECRET")
    
    if not client_id or not client_secret:
        print("⚠️  Google OAuth Credentials missing.")
        print("Please set GOOGLE_OAUTH_CLIENT_ID and GOOGLE_OAUTH_CLIENT_SECRET in your environment.")
        print("You can get them from: https://console.cloud.google.com/")
        print("Create 'Desktop Application' credentials.")
        return 1

    print(f"🚀 Starting Google Workspace MCP for identity: yani@meziani.ai / mezianiyani0@gmail.com")
    
    env = os.environ.copy()
    env["MCP_ENABLE_OAUTH21"] = "true"
    
    # Run using uv
    try:
        cmd = [
            "uv", "run", "main.py",
            "--transport", "streamable-http",
            "--tool-tier", "complete"
        ]
        return subprocess.run(cmd, cwd=google_mcp_dir, env=env).returncode
    except FileNotFoundError:
        print("❌ 'uv' not found. Please install uv: https://github.com/astral-sh/uv")
        return 1

if __name__ == "__main__":
    sys.exit(run_server())
