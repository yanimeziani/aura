#!/usr/bin/env python3
"""
Virtuo HR Schedule - MCP (Model Context Protocol) Server

Provides tools for AI assistants to query your Virtuo work schedule.

Tools:
  - get_schedule: Fetch current schedule (from cache or live)
  - get_today_shift: Get today's shift info
  - get_week_schedule: Get this week's shifts
  - get_next_shift: Get your next upcoming shift
  - refresh_schedule: Force re-fetch schedule from Virtuo
  - generate_ics: Generate an ICS calendar file

Run: python virtuo_mcp_server.py
"""

import asyncio
import json
import os
import subprocess
import sys
import time
import random
import hashlib
from datetime import datetime, timedelta, date
from pathlib import Path

CACHE_FILE = Path("/tmp/virtuo_schedule_entries.json")
ICS_OUTPUT = Path(os.path.expanduser("~/virtuo-calendar/virtuo_schedule.ics"))
TIMEZONE = "America/Toronto"
BASE_URL = "https://virtuo.ciussscn.rtss.qc.ca"
USERNAME = "517910"
PASSWORD = "tvt-B6!4$nekGGX"
CACHE_MAX_AGE_HOURS = 12


def load_cached_schedule():
    if CACHE_FILE.exists():
        age = time.time() - CACHE_FILE.stat().st_mtime
        with open(CACHE_FILE) as f:
            entries = json.load(f)
        return entries, age / 3600
    return None, None


def format_entry(entry):
    return {
        "date": entry.get("date", "")[:10],
        "day": entry.get("day", ""),
        "start": entry.get("startDate", ""),
        "end": entry.get("endDate", ""),
        "time_range": entry.get("timeRangeDisplay", ""),
        "shift_type": entry.get("scheduleCodeDescription", ""),
        "department": entry.get("departmentDisplay", ""),
        "job_title": entry.get("jobTitleDescription", ""),
        "location": entry.get("establishmentDisplay", ""),
        "site": entry.get("establishmentAbbreviation", ""),
        "total_hours": entry.get("totalHours", 0),
        "position": entry.get("position", ""),
        "is_holiday": entry.get("isRegularHoliday", False),
        "annotation": entry.get("annotation", ""),
    }


def get_schedule_handler(start_date=None, end_date=None):
    """Get schedule entries, optionally filtered by date range."""
    entries, age = load_cached_schedule()
    if not entries:
        return {"error": "No cached schedule. Run refresh_schedule first."}

    if start_date:
        entries = [e for e in entries if e.get("date", "")[:10] >= start_date]
    if end_date:
        entries = [e for e in entries if e.get("date", "")[:10] <= end_date]

    formatted = [format_entry(e) for e in entries]
    return {
        "entries": formatted,
        "count": len(formatted),
        "cache_age_hours": round(age, 1) if age else None,
    }


def get_today_shift_handler():
    """Get today's shift information."""
    today = date.today().isoformat()
    result = get_schedule_handler(start_date=today, end_date=today)
    if not result.get("entries"):
        return {"message": f"No shift scheduled for today ({today})", "date": today}
    return {
        "date": today,
        "shifts": result["entries"],
        "message": f"{len(result['entries'])} shift(s) today"
    }


def get_week_schedule_handler(week_offset=0):
    """Get schedule for the current week (or offset weeks from now)."""
    today = date.today() + timedelta(weeks=week_offset)
    start = today - timedelta(days=today.weekday())  # Monday
    end = start + timedelta(days=6)  # Sunday
    result = get_schedule_handler(
        start_date=start.isoformat(),
        end_date=end.isoformat()
    )
    total_hours = sum(e.get("total_hours", 0) for e in result.get("entries", []))
    work_days = len(result.get("entries", []))
    return {
        "week_start": start.isoformat(),
        "week_end": end.isoformat(),
        "entries": result.get("entries", []),
        "work_days": work_days,
        "total_hours": round(total_hours, 2),
        "week_offset": week_offset,
    }


def get_next_shift_handler():
    """Get the next upcoming shift."""
    now = datetime.now()
    entries, _ = load_cached_schedule()
    if not entries:
        return {"error": "No cached schedule."}

    for entry in sorted(entries, key=lambda e: e.get("startDate", "")):
        start = datetime.fromisoformat(entry["startDate"])
        if start > now:
            formatted = format_entry(entry)
            delta = start - now
            hours_until = delta.total_seconds() / 3600
            formatted["hours_until"] = round(hours_until, 1)
            formatted["starts_in"] = f"{int(hours_until)}h {int((hours_until % 1) * 60)}m"
            return formatted

    return {"message": "No upcoming shifts found in schedule."}


def generate_ics_handler(output_path=None):
    """Generate an ICS calendar file from cached schedule."""
    entries, _ = load_cached_schedule()
    if not entries:
        return {"error": "No cached schedule."}

    output = output_path or str(ICS_OUTPUT)

    from virtuo_sync import generate_ics
    generate_ics(entries, output)

    return {
        "output_path": output,
        "events": len(entries),
        "message": f"Generated ICS with {len(entries)} events at {output}"
    }


def refresh_schedule_handler(months=2):
    """Force refresh schedule from Virtuo (requires browser)."""
    script_dir = Path(__file__).parent
    sync_script = script_dir / "virtuo_sync.py"

    result = subprocess.run(
        [sys.executable, str(sync_script), "--months", str(months), "--output", str(ICS_OUTPUT)],
        capture_output=True, text=True, timeout=300,
        env={**os.environ, "PLAYWRIGHT_BROWSERS_PATH": "/tmp/pw-browsers"}
    )

    if result.returncode == 0:
        entries, _ = load_cached_schedule()
        return {
            "success": True,
            "entries_count": len(entries) if entries else 0,
            "ics_path": str(ICS_OUTPUT),
            "stdout": result.stdout[-500:],
        }
    return {
        "success": False,
        "error": result.stderr[-500:],
        "stdout": result.stdout[-500:],
    }


def handle_tool_call(tool_name, arguments):
    handlers = {
        "get_schedule": get_schedule_handler,
        "get_today_shift": get_today_shift_handler,
        "get_week_schedule": get_week_schedule_handler,
        "get_next_shift": get_next_shift_handler,
        "generate_ics": generate_ics_handler,
        "refresh_schedule": refresh_schedule_handler,
    }

    handler = handlers.get(tool_name)
    if not handler:
        return {"error": f"Unknown tool: {tool_name}"}

    try:
        return handler(**arguments)
    except Exception as e:
        return {"error": str(e)}


TOOLS = [
    {
        "name": "get_schedule",
        "description": "Get work schedule from Virtuo HR portal. Returns shifts with date, time, location, department. Optionally filter by date range.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "start_date": {"type": "string", "description": "Start date filter (YYYY-MM-DD)"},
                "end_date": {"type": "string", "description": "End date filter (YYYY-MM-DD)"},
            }
        }
    },
    {
        "name": "get_today_shift",
        "description": "Get today's work shift details including start time, end time, location, and department.",
        "inputSchema": {"type": "object", "properties": {}}
    },
    {
        "name": "get_week_schedule",
        "description": "Get the work schedule for a given week. Use week_offset=0 for current week, 1 for next week, etc.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "week_offset": {"type": "integer", "description": "Week offset from current week (0=this week, 1=next, -1=last)"}
            }
        }
    },
    {
        "name": "get_next_shift",
        "description": "Get the next upcoming work shift with countdown.",
        "inputSchema": {"type": "object", "properties": {}}
    },
    {
        "name": "generate_ics",
        "description": "Generate an ICS/iCal calendar file for Google Calendar import.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "output_path": {"type": "string", "description": "Output file path for ICS"}
            }
        }
    },
    {
        "name": "refresh_schedule",
        "description": "Force re-fetch schedule from Virtuo HR portal (opens browser, takes ~60s).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "months": {"type": "integer", "description": "Months ahead to fetch (default 2)"}
            }
        }
    },
]


def run_stdio_server():
    """Run as MCP server using stdio transport."""
    import select

    def write_message(msg):
        content = json.dumps(msg)
        header = f"Content-Length: {len(content)}\r\n\r\n"
        sys.stdout.write(header + content)
        sys.stdout.flush()

    def read_message():
        headers = {}
        while True:
            line = sys.stdin.readline()
            if not line or line.strip() == "":
                break
            if ":" in line:
                key, val = line.split(":", 1)
                headers[key.strip()] = val.strip()

        length = int(headers.get("Content-Length", 0))
        if length == 0:
            return None
        body = sys.stdin.read(length)
        return json.loads(body)

    # Initialize
    while True:
        msg = read_message()
        if not msg:
            break

        method = msg.get("method", "")
        msg_id = msg.get("id")

        if method == "initialize":
            write_message({
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {"tools": {}},
                    "serverInfo": {
                        "name": "virtuo-schedule",
                        "version": "1.0.0"
                    }
                }
            })

        elif method == "notifications/initialized":
            pass

        elif method == "tools/list":
            write_message({
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": {"tools": TOOLS}
            })

        elif method == "tools/call":
            params = msg.get("params", {})
            tool_name = params.get("name", "")
            arguments = params.get("arguments", {})
            result = handle_tool_call(tool_name, arguments)
            write_message({
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": {
                    "content": [
                        {"type": "text", "text": json.dumps(result, indent=2, ensure_ascii=False, default=str)}
                    ]
                }
            })

        elif method == "resources/list":
            write_message({
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": {"resources": []}
            })

        elif msg_id:
            write_message({
                "jsonrpc": "2.0",
                "id": msg_id,
                "error": {"code": -32601, "message": f"Method not found: {method}"}
            })


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--test":
        print("=== Virtuo Schedule MCP Server - Test Mode ===\n")

        print("--- get_today_shift ---")
        print(json.dumps(get_today_shift_handler(), indent=2, ensure_ascii=False, default=str))

        print("\n--- get_next_shift ---")
        print(json.dumps(get_next_shift_handler(), indent=2, ensure_ascii=False, default=str))

        print("\n--- get_week_schedule ---")
        print(json.dumps(get_week_schedule_handler(), indent=2, ensure_ascii=False, default=str))

        print("\n--- get_schedule (next 7 days) ---")
        today = date.today()
        end = today + timedelta(days=7)
        result = get_schedule_handler(start_date=today.isoformat(), end_date=end.isoformat())
        print(json.dumps(result, indent=2, ensure_ascii=False, default=str))

    elif len(sys.argv) > 1 and sys.argv[1] == "--stdio":
        run_stdio_server()

    else:
        print("Virtuo Schedule MCP Server")
        print()
        print("Usage:")
        print(f"  {sys.argv[0]} --stdio    Run as MCP server (stdio transport)")
        print(f"  {sys.argv[0]} --test     Test tools locally")
        print()
        print("MCP Config (add to cursor/claude settings):")
        print(json.dumps({
            "mcpServers": {
                "virtuo-schedule": {
                    "command": "python3",
                    "args": [str(Path(__file__).resolve()), "--stdio"],
                }
            }
        }, indent=2))


if __name__ == "__main__":
    main()
