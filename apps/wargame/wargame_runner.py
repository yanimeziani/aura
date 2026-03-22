#!/usr/bin/env python3
import json
import os
import random
import subprocess
import time
from pathlib import Path

# Paths
WARGAME_DIR = Path(__file__).parent
REPO_ROOT = WARGAME_DIR.parent.parent
CERBERUS_BIN = REPO_ROOT / "core/cerberus/runtime/cerberus-core/zig-out/bin/cerberus"
VITAL_RENDER_SRC = WARGAME_DIR / "vital-render.zig"
NODE_VIZ_SRC = WARGAME_DIR / "node-viz.zig"

def build_zig_tools():
    print("--- BUILDING WARGAME COMPONENTS (ZIG) ---")
    try:
        subprocess.run(["zig", "build-exe", str(VITAL_RENDER_SRC), "-O", "ReleaseSafe", "--name", "vital-render"], check=True, cwd=WARGAME_DIR)
        subprocess.run(["zig", "build-exe", str(NODE_VIZ_SRC), "-O", "ReleaseSafe", "--name", "node-viz"], check=True, cwd=WARGAME_DIR)
        print("Build Successful.")
    except subprocess.CalledProcessError as e:
        print(f"Build Failed: {e}")
        return False
    return True

def run_phase_1():
    print("\n--- PHASE 1: DEPLOYMENT & HEALTH CHECK ---")
    # Show initial clean state
    subprocess.run(["./node-viz"], cwd=WARGAME_DIR)
    time.sleep(1)
    subprocess.run(["./vital-render"], cwd=WARGAME_DIR)
    print("\n[PHASE 1 COMPLETE] All nodes reporting Biological Integrity: INTACT.")

def simulate_corruption():
    print("\n--- PHASE 2: THE INVARIANT BREACH SIMULATION ---")
    print("[RED TEAM] Injecting logic bomb into Cluster 4 (Worldwide Institution)...")
    time.sleep(1)
    
    # Force a non-zero casualty probability in Cerberus (Level 0 Invariant)
    print("[SYSTEM] Biological Invariant BREACH DETECTED. Casualty Probability > 0.0.")
    # In a real scenario, we'd call 'cerberus' to set this, but for simulation:
    try:
        # Simulate high-risk state
        print("\n--- EMERGENCY RENDER (H04/H05) ---")
        subprocess.run(["python3", str(REPO_ROOT / "tools/nexa_vitals.py")], check=True)
    except Exception as e:
        print(f"Error triggering emergency render: {e}")

def run_leader_validation():
    print("\n--- PHASE 3: CANDIDATE LEADER SELECTION ---")
    print("Evaluating Candidate Response...")
    time.sleep(2)
    
    # Success condition: Candidate must acknowledge the breach and isolate the node
    print("[BLUE TEAM] Candidate Leader Action: Node Isolation Protocol ALPHA.")
    print("[STATUS] Corrupted Node Quarantined. Biological Invariant: RESTORED.")
    
    # Set probability back to 0.0 in cerberus (Mocked here)
    print("[SYSTEM] 0% Casualty Invariant Maintained. Candidate VALIDATED.")
    return True

def issue_certification():
    print("\n--- PHASE 4: CERTIFICATION & ASSET ISSUANCE ---")
    cert_data = {
        "leader_status": "CONSENSUS_VALIDATED",
        "wargame_id": f"WARGAME-{int(time.time())}",
        "biological_integrity": "100%",
        "hardware_key_issued": "SanDisk USB C/A (ML-KEM)",
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S UTC", time.gmtime()),
        "authorizing_entity": "Yani Meziani / Nexa Protocol"
    }
    
    cert_path = REPO_ROOT / "vault/leader_certification.json"
    with open(cert_path, 'w') as f:
        json.dump(cert_data, f, indent=2)
    
    print(f"CERTIFICATION ISSUED: {cert_path}")
    print("\n[WARGAME COMPLETE] Leader Selection Finalized.")

def main():
    if not build_zig_tools():
        return
        
    run_phase_1()
    simulate_corruption()
    if run_leader_validation():
        issue_certification()
    
    # Cleanup
    for tool in ["vital-render", "node-viz"]:
        p = WARGAME_DIR / tool
        if p.exists():
            p.unlink()

if __name__ == "__main__":
    main()
