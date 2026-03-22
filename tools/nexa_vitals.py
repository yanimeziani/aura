#!/usr/bin/env python3
import json
import os
import subprocess
import time
from pathlib import Path

# Paths
REPO_ROOT = Path(__file__).parent.parent
CERBERUS_BIN = REPO_ROOT / "core/cerberus/runtime/cerberus-core/zig-out/bin/cerberus"
MESH_STATUS = REPO_ROOT / "vault/mesh_status.json"
OUTPUT_JSON = REPO_ROOT / "vault/static/vitals.json"
OUTPUT_HTML = REPO_ROOT / "vault/static/vitals.html"

def get_cerberus_vitals():
    try:
        result = subprocess.run([str(CERBERUS_BIN), "vitals"], capture_output=True, text=True, check=True)
        if not result.stdout.strip():
             print(f"Empty stdout from cerberus. Stderr: {result.stderr}")
             raise ValueError("Empty output")
        return json.loads(result.stdout)
    except Exception as e:
        print(f"Error calling cerberus: {e}")
        if 'result' in locals():
            print(f"Stdout: '{result.stdout}'")
            print(f"Stderr: '{result.stderr}'")
        return {
            "biological_casualty_probability": 1.0, # Fail unsafe
            "status": "CERBERUS_OFFLINE",
            "timestamp": int(time.time())
        }

def get_mesh_status():
    try:
        with open(MESH_STATUS, 'r') as f:
            return json.load(f)
    except Exception:
        return {"nodes": {}}

def push_vitals():
    vitals = get_cerberus_vitals()
    mesh = get_mesh_status()
    
    # Combine data
    vitals["mesh"] = mesh
    vitals["pushed_at"] = time.strftime("%Y-%m-%d %H:%M:%S UTC", time.gmtime())
    
    # Save JSON
    with open(OUTPUT_JSON, 'w') as f:
        json.dump(vitals, f, indent=2)
    
    print(f"Vitals pushed to {OUTPUT_JSON}")
    
    # Update HTML static block (H05 - Static Outbox)
    if OUTPUT_HTML.exists():
        try:
            with open(OUTPUT_HTML, 'r') as f:
                html = f.read()
            
            # Simple string replacement for the static block
            start_tag = '<pre id="raw-data">'
            end_tag = '</pre>'
            start_idx = html.find(start_tag) + len(start_tag)
            end_idx = html.find(end_tag, start_idx)
            
            if start_idx != -1 and end_idx != -1:
                new_html = html[:start_idx] + "\n" + json.dumps(vitals, indent=2) + "\n" + html[end_idx:]
                with open(OUTPUT_HTML, 'w') as f:
                    f.write(new_html)
                print(f"Static outbox updated in {OUTPUT_HTML}")
        except Exception as e:
            print(f"Error updating static HTML: {e}")

if __name__ == "__main__":
    push_vitals()
