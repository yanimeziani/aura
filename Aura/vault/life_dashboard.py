import json
import os
import sys
import subprocess
import webbrowser
from datetime import datetime
from pathlib import Path
from shutil import get_terminal_size


BASE_DIR = Path("/home/yani/Aura/vault")
GOALS_FILE = BASE_DIR / "goals.json"
PROFILE_FILE = BASE_DIR / "aura_owner_profile.json"
VAULT_JSON = BASE_DIR / "aura-vault.json"
ENV_TARGETS = [
    Path("/home/yani/Aura/ai_agency_wealth/.env"),
    Path("/home/yani/.n8n/.env"),
]


def load_json(path: Path):
    try:
        if not path.exists():
            return None
        with path.open("r") as f:
            return json.load(f)
    except Exception:
        return None


def format_timestamp(ts: str | None) -> str:
    if not ts:
        return "unknown"
    try:
        dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
        return dt.strftime("%Y-%m-%d %H:%M")
    except Exception:
        return ts


def hr(char: str = "─") -> str:
    width = max(60, get_terminal_size((80, 20)).columns)
    return char * width


def section(title: str) -> str:
    return f"\n{title}\n{hr()}"


def get_mode(goals: dict, profile: dict) -> str:
    # Prefer explicit operating mode if you ever add it, else fall back to a strong default.
    mode = (
        goals.get("operating_mode")
        or profile.get("operating_mode")
        or "BUILD / DEPLOY / LEARN"
    )
    return str(mode)


def get_today_focus(goals: dict) -> list[str]:
    # Optional key in goals.json; gracefully falls back.
    today = goals.get("today") or goals.get("today_focus") or []
    if isinstance(today, str):
        return [today]
    if isinstance(today, list):
        return [str(item) for item in today]
    return []


def _file_status(path: Path) -> str:
    if path.exists():
        size = path.stat().st_size
        if size > 0:
            return "OK"
        return "EMPTY"
    return "MISSING"


def _service_status(name: str) -> str:
    try:
        result = subprocess.run(
            ["systemctl", "is-active", name],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=2,
        )
        out = (result.stdout or "").strip()
        if out == "active":
            return "active"
        if out == "inactive":
            return "inactive"
        if out == "failed":
            return "failed"
        return out or "unknown"
    except Exception:
        return "unknown"


def render_life_dashboard() -> str:
    goals = load_json(GOALS_FILE) or {}
    profile = load_json(PROFILE_FILE) or {}

    owner = goals.get("owner") or profile.get("owner") or "Unknown owner"
    last_updated = format_timestamp(profile.get("last_updated"))

    primary_objectives = goals.get("primary_objectives", [])
    high_signal_entities = goals.get("high_signal_entities", [])
    auto_archive_categories = goals.get("auto_archive_categories", [])

    bookmarks = profile.get("bookmarks", [])
    quick_links = bookmarks[:10]

    mode = get_mode(goals, profile)
    today_focus = get_today_focus(goals)

    lines: list[str] = []

    banner_line = f"AURA / LIFE STACK – {owner}".upper()
    width = max(len(banner_line) + 4, 60)

    # Header
    lines.append("═" * width)
    lines.append(f"║ {banner_line.center(width - 4)} ║")
    lines.append("═" * width)

    # Mode / Identity
    lines.append(section("MODE"))
    lines.append(f"Owner:        {owner}")
    lines.append(f"Operating:    {mode}")
    lines.append(f"Profile sync: {last_updated}")

    # Today focus
    lines.append(section("TODAY – TOP FLOW ITEMS"))
    if today_focus:
        for i, item in enumerate(today_focus, start=1):
            lines.append(f"[ ] {i:2}. {item}")
    else:
        lines.append("No explicit `today` focus in goals.json – default to primary objectives below.")

    # Objectives
    lines.append(section("PIPELINE – PRIMARY OBJECTIVES"))
    if primary_objectives:
        for i, obj in enumerate(primary_objectives, start=1):
            lines.append(f"{i:2}. {obj}")
    else:
        lines.append("No primary objectives defined in goals.json.")

    # High-signal entities
    lines.append(section("SIGNAL – HIGH-SIGNAL ENTITIES"))
    if high_signal_entities:
        lines.append(", ".join(high_signal_entities))
    else:
        lines.append("None defined.")

    # Inbox / attention hygiene
    lines.append(section("ATTENTION HYGIENE – AUTO-ARCHIVE"))
    if auto_archive_categories:
        for cat in auto_archive_categories:
            lines.append(f"- {cat}")
    else:
        lines.append("No auto-archive categories defined.")

    # System status
    lines.append(section("SYSTEM STATUS – MISSION CONTROL"))
    lines.append("Vault + env:")
    lines.append(f"  - aura-vault.json:   {_file_status(VAULT_JSON)}")
    for target in ENV_TARGETS:
        lines.append(f"  - {str(target)}: {_file_status(target)}")
    lines.append("")
    lines.append("Services (systemd):")
    for svc in ("ai_pay", "aura_autopilot"):
        lines.append(f"  - {svc}: { _service_status(svc) }")

    # Quick links as launchers
    lines.append(section("LAUNCHERS – QUICK LINKS"))
    if quick_links:
        for i, bm in enumerate(quick_links, start=1):
            name = bm.get("name", "<no name>")
            url = bm.get("url", "<no url>")
            source = bm.get("source", "")
            suffix = f" [{source}]" if source else ""
            lines.append(f"{i:2}. {name}{suffix}")
            lines.append(f"    {url}")
    else:
        lines.append("No bookmarks available in aura_owner_profile.json.")

    # Operations toolbox: the core commands to operate the machine.
    lines.append(section("OPERATIONS TOOLBOX"))
    lines.append("Core vault + ops commands:")
    lines.append("  - Dashboard:        python /home/yani/Aura/vault/life_dashboard.py")
    lines.append("  - Vault setup:      python /home/yani/Aura/vault/vault_manager.py")
    lines.append("  - Vault sync/env:   python /home/yani/Aura/vault/vault_manager.py sync")
    lines.append("")
    lines.append("Agency / wealth machine:")
    lines.append("  - Run full agency:  python /home/yani/Aura/ai_agency_wealth/main.py")
    lines.append("  - Payments server:  python /home/yani/Aura/ai_agency_wealth/prod_payment_server.py")
    lines.append("  - Log watchdog:     python /home/yani/Aura/ai_agency_wealth/log_watchdog.py")
    lines.append("")
    lines.append("Newsletter + content:")
    lines.append("  - Latest newsletter: less /home/yani/Aura/ai_agency_wealth/latest_newsletter.md")
    lines.append("")
    lines.append("NotebookLM streams (logs → packet → audio/video):")
    lines.append("  - Packet (agency):  python /home/yani/Aura/vault/log2notebooklm.py --source agency_metrics --tail 1500")
    lines.append("  - Packet (payments):python /home/yani/Aura/vault/log2notebooklm.py --source payment_server --tail 1500")
    lines.append("  - With AV stream:   python /home/yani/Aura/vault/log2notebooklm.py --source agency_metrics --tail 1500 --audio")
    lines.append("")
    lines.append("Mission Control GUI (fluid state view):")
    lines.append("  - Start GUI:        uvicorn mission_control_gui:app --host 127.0.0.1 --port 8787")
    lines.append("  - Open GUI:         python /home/yani/Aura/vault/life_dashboard.py open-gui")
    lines.append("")
    lines.append("Quick actions:")
    lines.append("  - Open launcher N:  python /home/yani/Aura/vault/life_dashboard.py open N")

    lines.append("")
    return "\n".join(lines)


def open_quick_link(index: int) -> bool:
    profile = load_json(PROFILE_FILE) or {}
    bookmarks = profile.get("bookmarks", [])
    if not bookmarks:
        return False
    if index < 1 or index > len(bookmarks):
        return False
    url = bookmarks[index - 1].get("url")
    if not url:
        return False
    try:
        webbrowser.open(url)
        return True
    except Exception:
        return False


def main(argv: list[str] | None = None):
    if argv is None:
        argv = sys.argv[1:]

    if len(argv) >= 1 and argv[0] == "open":
        if len(argv) < 2:
            print("Usage: life_dashboard.py open <index>")
            return
        try:
            idx = int(argv[1])
        except ValueError:
            print("Index must be an integer.")
            return
        if open_quick_link(idx):
            print(f"Launched quick link {idx}.")
        else:
            print(f"Could not launch quick link {idx}. Check index and bookmarks.")
        return

    if len(argv) >= 1 and argv[0] == "open-gui":
        # Best-effort; assumes uvicorn is on PATH (it is in this environment).
        try:
            webbrowser.open("http://127.0.0.1:8787/")
            print("Opened GUI in browser: http://127.0.0.1:8787/")
        except Exception:
            print("GUI URL: http://127.0.0.1:8787/")
        return

    print(render_life_dashboard())


if __name__ == "__main__":
    main()

