#!/usr/bin/env python3
"""
Sovereign Calendar MCP Server
Local, encrypted (simple), and ICS-compatible.
"""

import json
import os
import sys
from datetime import datetime, timedelta
from pathlib import Path

# Paths
CALENDAR_DIR = Path(os.path.expanduser("~/.sovereign"))
DB_FILE = CALENDAR_DIR / "calendar.json.enc"
KEY_FILE = CALENDAR_DIR / "vault.key"

def ensure_setup():
    if not CALENDAR_DIR.exists():
        CALENDAR_DIR.mkdir(parents=True)
    if not KEY_FILE.exists():
        with open(KEY_FILE, "w") as f:
            f.write(os.urandom(32).hex())

def get_key():
    with open(KEY_FILE, "r") as f:
        return bytes.fromhex(f.read())

def simple_crypt(data: bytes, key: bytes) -> bytes:
    """Simple XOR 'encryption' for local privacy without external deps."""
    return bytes(b ^ key[i % len(key)] for i, b in enumerate(data))

def load_db():
    if not DB_FILE.exists():
        return []
    with open(DB_FILE, "rb") as f:
        encrypted_data = f.read()
    try:
        decrypted_data = simple_crypt(encrypted_data, get_key())
        return json.loads(decrypted_data.decode('utf-8'))
    except:
        return []

def save_db(data):
    json_data = json.dumps(data).encode('utf-8')
    encrypted_data = simple_crypt(json_data, get_key())
    with open(DB_FILE, "wb") as f:
        f.write(encrypted_data)

def add_event(title, start_iso, end_iso=None, description=""):
    db = load_db()
    event_id = str(len(db) + 1)
    if not end_iso:
        # Default 30 mins
        start_dt = datetime.fromisoformat(start_iso)
        end_iso = (start_dt + timedelta(minutes=30)).isoformat()
    
    event = {
        "id": event_id,
        "title": title,
        "start": start_iso,
        "end": end_iso,
        "description": description,
        "created_at": datetime.now().isoformat()
    }
    db.append(event)
    save_db(db)
    return event

def list_events():
    return load_db()

def export_ics():
    db = load_db()
    lines = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//Sovereign//Calendar//EN"]
    for e in db:
        start = e['start'].replace("-", "").replace(":", "").split(".")[0]
        end = e['end'].replace("-", "").replace(":", "").split(".")[0]
        lines.append("BEGIN:VEVENT")
        lines.append(f"UID:{e['id']}@sovereign")
        lines.append(f"DTSTAMP:{datetime.now().strftime('%Y%m%dT%H%M%SZ')}")
        lines.append(f"DTSTART:{start}")
        lines.append(f"DTEND:{end}")
        lines.append(f"SUMMARY:{e['title']}")
        lines.append(f"DESCRIPTION:{e['description']}")
        lines.append("END:VEVENT")
    lines.append("END:VCALENDAR")
    return "\n".join(lines)

def handle_tool_call(name, args):
    if name == "add_event":
        return add_event(**args)
    elif name == "list_events":
        return list_events()
    elif name == "export_ics":
        return export_ics()
    return {"error": "Unknown tool"}

TOOLS = [
    {
        "name": "add_event",
        "description": "Add a new event to the local encrypted calendar.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "title": {"type": "string"},
                "start_iso": {"type": "string", "description": "ISO format date string"},
                "end_iso": {"type": "string", "description": "Optional ISO format date string"},
                "description": {"type": "string"}
            },
            "required": ["title", "start_iso"]
        }
    },
    {
        "name": "list_events",
        "description": "List all events in the local encrypted calendar.",
        "inputSchema": {"type": "object", "properties": {}}
    },
    {
        "name": "export_ics",
        "description": "Export the calendar to ICS format string.",
        "inputSchema": {"type": "object", "properties": {}}
    }
]

def run_stdio_server():
    def write_msg(msg):
        content = json.dumps(msg)
        sys.stdout.write(f"Content-Length: {len(content)}\r\n\r\n{content}")
        sys.stdout.flush()

    def read_msg():
        line = sys.stdin.readline()
        if not line: return None
        length = int(line.split(":")[1].strip())
        sys.stdin.readline() # skip blank
        return json.loads(sys.stdin.read(length))

    ensure_setup()
    while True:
        msg = read_msg()
        if not msg: break
        method = msg.get("method")
        msg_id = msg.get("id")
        if method == "initialize":
            write_msg({"jsonrpc":"2.0","id":msg_id,"result":{"protocolVersion":"2024-11-05","capabilities":{"tools":{}},"serverInfo":{"name":"sovereign-calendar","version":"1.0.0"}}})
        elif method == "tools/list":
            write_msg({"jsonrpc":"2.0","id":msg_id,"result":{"tools":TOOLS}})
        elif method == "tools/call":
            params = msg.get("params", {})
            res = handle_tool_call(params.get("name"), params.get("arguments", {}))
            write_msg({"jsonrpc":"2.0","id":msg_id,"result":{"content":[{"type":"text","text":json.dumps(res)}]}})

if __name__ == "__main__":
    if "--stdio" in sys.argv:
        run_stdio_server()
    else:
        # Simple test
        ensure_setup()
        print("Sovereign Calendar Active.")
        if "test" in sys.argv:
            add_event("Onboarding Mounir", datetime.now().isoformat(), description="15 min sync")
            print(list_events())
