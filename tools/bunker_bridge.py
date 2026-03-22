#!/usr/bin/env python3
import os
import re
import sys
import json
import requests
import subprocess
from pathlib import Path

# Resolve root
ROOT_DIR = Path(__file__).resolve().parent.parent
TASKS_MD = ROOT_DIR / "TASKS.md"

def parse_tasks():
    if not TASKS_MD.exists():
        print(f"✗ TASKS.md not found at {TASKS_MD}")
        return []
    
    with open(TASKS_MD, "r") as f:
        content = f.read()
    
    # Extract the Active Workboard table
    table_match = re.search(r"## Active Workboard\n\n(.*?)\n\n", content, re.DOTALL)
    if not table_match:
        # Try finding until end of file if no double newline
        table_match = re.search(r"## Active Workboard\n\n(.*?)$", content, re.DOTALL)
        
    if not table_match:
        print("✗ Could not find 'Active Workboard' table in TASKS.md")
        return []
    
    lines = table_match.group(1).strip().split("\n")
    if len(lines) < 3:
        return []
    
    # Skip header and separator
    data_lines = lines[2:]
    tasks = []
    
    for line in data_lines:
        parts = [p.strip() for p in line.strip("|").split("|")]
        if len(parts) >= 3:
            tasks.append({
                "id": parts[0],
                "task": parts[1],
                "status": parts[2],
                "owner": parts[3] if len(parts) > 3 else "unassigned",
                "links": parts[4] if len(parts) > 4 else ""
            })
    return tasks

def sync_to_clickup(tasks):
    api_key = os.environ.get("CLICKUP_API_KEY")
    list_id = os.environ.get("CLICKUP_LIST_ID")
    
    if not api_key or not list_id:
        print("ℹ ClickUp sync skipped (CLICKUP_API_KEY or CLICKUP_LIST_ID missing)")
        return
    
    print(f"🚀 Syncing {len(tasks)} tasks to ClickUp List {list_id}...")
    
    # 1. Get existing tasks to avoid duplicates
    url = f"https://api.clickup.com/api/v2/list/{list_id}/task"
    headers = {"Authorization": api_key}
    res = requests.get(url, headers=headers)
    
    existing_custom_ids = []
    if res.status_code == 200:
        existing_tasks = res.json().get("tasks", [])
        for et in existing_tasks:
            # We look for the NX-xxx pattern in the title or custom fields
            match = re.search(r"(NX-\d+)", et.get("name", ""))
            if match:
                existing_custom_ids.append(match.group(1))
    
    for task in tasks:
        if task["id"] in existing_custom_ids:
            print(f"  - {task['id']} already exists, skipping.")
            continue
        
        print(f"  + Creating {task['id']}: {task['task']}")
        create_url = f"https://api.clickup.com/api/v2/list/{list_id}/task"
        payload = {
            "name": f"[{task['id']}] {task['task']}",
            "description": f"Owner: {task['owner']}\nStatus: {task['status']}\nLinks: {task['links']}\n\nSync from Bunker.",
            "status": "to do" if task["status"] == "todo" else "in progress" if task["status"] == "in_progress" else "complete"
        }
        requests.post(create_url, headers=headers, json=payload)

def trigger_notebooklm():
    print("📦 Building NotebookLM documentation bundle...")
    try:
        # Use make docs-bundle if available, or call the script directly
        subprocess.run(["make", "docs-bundle"], cwd=ROOT_DIR, check=True)
        print("✅ Documentation bundle created: nexa-docs-notebooklm.txt")
        
        notebook_url = os.environ.get("NOTEBOOKLM_NOTEBOOK_URL")
        if notebook_url:
            print("🌐 NOTEBOOKLM_NOTEBOOK_URL detected. You can now use 'nexa notebooklm-upload' to sync via Playwright.")
        else:
            print("ℹ NotebookLM upload skipped (NOTEBOOKLM_NOTEBOOK_URL missing).")
            
    except Exception as e:
        print(f"✗ Failed to build docs bundle: {e}")

def main():
    print("=== BUNKER BRIDGE: Cloud Sync ===")
    
    # 1. Tasks -> ClickUp
    tasks = parse_tasks()
    if tasks:
        sync_to_clickup(tasks)
    
    # 2. Docs -> NotebookLM
    trigger_notebooklm()
    
    print("🏁 Sync complete.")

if __name__ == "__main__":
    main()
