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
GRID_VITAL_LOCK = REPO_ROOT / "specs/grid_vital_lock.json"
OUTPUT_JSON = REPO_ROOT / "vault/static/vitals.json"
OUTPUT_HTML = REPO_ROOT / "vault/static/vitals.html"


def validate_grid_vital_lock(mesh: dict, lock: dict) -> tuple[str, list[str], dict[str, str]]:
    """
    Ensure each mesh node declares grid_id and appears under that grid's mesh_nodes in the lock manifest.
    Returns (compliance, violations, node_to_grid).
    """
    violations: list[str] = []
    node_to_grid: dict[str, str] = {}
    grids = lock.get("grids") or []
    grid_nodes: dict[str, set[str]] = {}
    for g in grids:
        gid = g.get("grid_id")
        if not gid:
            continue
        nodes = (g.get("vital_infrastructure") or {}).get("mesh_nodes") or []
        grid_nodes[gid] = set(nodes)

    nodes_obj = mesh.get("nodes") or {}
    for node_id, rec in nodes_obj.items():
        if not isinstance(rec, dict):
            violations.append(f"node {node_id}: record must be an object")
            continue
        gid = rec.get("grid_id")
        if not gid:
            violations.append(f"node {node_id}: missing grid_id")
            continue
        node_to_grid[node_id] = gid
        if gid not in grid_nodes:
            violations.append(f"node {node_id}: unknown grid_id {gid}")
            continue
        if node_id not in grid_nodes[gid]:
            violations.append(
                f"node {node_id}: not listed under grid {gid} vital_infrastructure.mesh_nodes in specs/grid_vital_lock.json"
            )

    for gid, allowed in grid_nodes.items():
        for required in allowed:
            if required not in nodes_obj:
                violations.append(
                    f"grid {gid}: locked mesh_node {required} missing from vault/mesh_status.json"
                )

    compliance = "COMPLIANT" if not violations else "DRIFT_DETECTED"
    return compliance, violations, node_to_grid

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

    lock_block: dict = {}
    try:
        with open(GRID_VITAL_LOCK, "r", encoding="utf-8") as f:
            lock = json.load(f)
        compliance, violations, node_to_grid = validate_grid_vital_lock(mesh, lock)
        lock_block = {
            "spec_version": lock.get("version"),
            "compliance": compliance,
            "violations": violations,
            "node_grid_map": node_to_grid,
        }
    except OSError as e:
        lock_block = {
            "spec_version": None,
            "compliance": "LOCK_FILE_MISSING",
            "violations": [str(e)],
            "node_grid_map": {},
        }
    except json.JSONDecodeError as e:
        lock_block = {
            "spec_version": None,
            "compliance": "LOCK_FILE_INVALID",
            "violations": [str(e)],
            "node_grid_map": {},
        }

    vitals["grid_vital_lock"] = lock_block
    strict = os.environ.get("NEXA_GRID_LOCK_STRICT", "").strip() in ("1", "true", "yes")

    # Combine data
    vitals["mesh"] = mesh
    vitals["pushed_at"] = time.strftime("%Y-%m-%d %H:%M:%S UTC", time.gmtime())
    
    # Save JSON
    with open(OUTPUT_JSON, 'w') as f:
        json.dump(vitals, f, indent=2)
    
    print(f"Vitals pushed to {OUTPUT_JSON}")
    if lock_block.get("compliance") != "COMPLIANT":
        print(f"grid_vital_lock: {lock_block.get('compliance')} — {lock_block.get('violations')}")
        if strict:
            raise SystemExit(1)
    
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
