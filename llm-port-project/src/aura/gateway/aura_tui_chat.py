#!/usr/bin/env python3
"""
Minimalist TUI chat with Aura agent (Groq via gateway).
Uses RAG-style context: loads Aura docs (AGENTS, AURA_PRO_GUIDE, ONBOARDING) and
optional session sync so the agent has full project context.
Usage: python aura_tui_chat.py
Requires: gateway running (uvicorn gateway.app:app --port 8765)
Env: AURA_GATEWAY_URL, AURA_ROOT (repo root for docs), AURA_CHAT_WORKSPACE (sync key)
"""
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

DEFAULT_URL = os.environ.get("AURA_GATEWAY_URL", "http://127.0.0.1:8765").rstrip("/")
LOG_TOKEN = os.environ.get("AURA_LOG_TOKEN", "")
AURA_ROOT = Path(os.environ.get("AURA_ROOT", "/home/yani/Aura"))
WORKSPACE_ID = os.environ.get("AURA_CHAT_WORKSPACE", "aura")
# Cap total doc context to avoid token overflow (~5k tokens)
MAX_CONTEXT_CHARS = 24_000

BASE_SYSTEM = (
    "You are Aura, a concise assistant for Meziani AI Labs. "
    "You help with sovereign digitalisation, automation, and focused execution. "
    "Keep replies clear and to the point unless asked for depth. "
    "Use the project context below to answer about this codebase, commands, and principles."
)


def _load_doc(path: Path, max_chars: int) -> str:
    if not path.exists():
        return ""
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            return f.read(max_chars)
    except OSError:
        return ""


def load_aura_context() -> str:
    """Load key Aura docs and optional session sync into a single context string."""
    docs_dir = AURA_ROOT / "docs"
    # Order matters: principles and onboarding first, then pro guide
    doc_files = ["AGENTS.md", "ONBOARDING.md", "AURA_PRO_GUIDE.md", "README.md"]
    remaining = MAX_CONTEXT_CHARS
    parts = []
    for name in doc_files:
        if remaining <= 0:
            break
        path = docs_dir / name
        chunk = _load_doc(path, remaining)
        if chunk:
            parts.append(f"--- {name} ---\n{chunk}")
            remaining -= len(chunk)
    context = "\n\n".join(parts)

    # Optional: session sync from gateway (shared IDE/TUI context)
    try:
        req = urllib.request.Request(
            f"{DEFAULT_URL}/sync/session/{WORKSPACE_ID}",
            headers={"Accept": "application/json"},
            method="GET",
        )
        with urllib.request.urlopen(req, timeout=5.0) as r:
            data = json.loads(r.read().decode())
        payload = data.get("payload")
        if payload and isinstance(payload, dict) and payload:
            session_blob = json.dumps(payload, indent=0)[:2000]
            context = (context + "\n\n--- Synced session (IDE/TUI) ---\n" + session_blob).strip()
    except Exception:
        pass

    return context.strip()


def build_system_prompt() -> str:
    context = load_aura_context()
    if not context:
        return BASE_SYSTEM
    return BASE_SYSTEM + "\n\n--- Project context (use for commands, principles, repo layout) ---\n\n" + context


def chat(messages: list[dict], timeout: float = 120.0) -> str:
    payload = {
        "model": os.environ.get("OPENAI_MODEL_NAME"),
        "messages": messages,
        "stream": False,
        "max_tokens": 2048,
    }
    payload = {k: v for k, v in payload.items() if v is not None}
    req = urllib.request.Request(
        f"{DEFAULT_URL}/v1/chat/completions",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            out = json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        body = e.read().decode() if e.fp else str(e)
        return f"[Error {e.code}] {body}"
    except urllib.error.URLError as e:
        return f"[Connection error] {e.reason}"
    except TimeoutError:
        return "[Timeout]"
    choices = out.get("choices") or []
    if not choices:
        return "[No response]"
    msg = choices[0].get("message") or {}
    return (msg.get("content") or "").strip()


def fetch_logs(name: str = "", n: int = 40) -> str:
    """Fetch log tail from gateway and format for terminal display."""
    token_param = f"&token={LOG_TOKEN}" if LOG_TOKEN else ""
    if name:
        url = f"{DEFAULT_URL}/logs/tail/{name}?n={n}{token_param}"
    else:
        url = f"{DEFAULT_URL}/logs/tail?n={n}{token_param}"
    try:
        req = urllib.request.Request(url, headers={"Accept": "application/json"})
        with urllib.request.urlopen(req, timeout=10.0) as r:
            data = json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        return f"[Log error {e.code}] {e.read().decode()}"
    except Exception as e:
        return f"[Log fetch failed] {e}"

    lines_out = []
    if name:
        # Single log response: {"name":…,"lines":[…]}
        for line in data.get("lines", []):
            lines_out.append(line)
    else:
        # All logs: {"agency":[lines…], …}
        for log_name, lines in data.items():
            if lines:
                lines_out.append(f"\n--- {log_name} ---")
                lines_out.extend(lines[-20:])  # cap per-log display

    return "\n".join(lines_out) if lines_out else "(no log output)"


def main() -> None:
    print("Aura — minimal chat (agent0)")
    print("Gateway:", DEFAULT_URL)
    print("Context: Aura docs + session sync from", AURA_ROOT)
    print("Commands: /quit  /clear  /reload  /logs [name]  /stream <name>")
    print("-" * 40)

    def fresh_messages():
        return [{"role": "system", "content": build_system_prompt()}]

    messages = fresh_messages()

    while True:
        try:
            line = input("You: ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\nBye.")
            sys.exit(0)

        if not line:
            continue
        if line.lower() in ("/quit", "/exit", "/q"):
            print("Bye.")
            sys.exit(0)
        if line.lower() == "/clear":
            messages = [messages[0]]  # keep system, drop conversation
            print("(conversation cleared)")
            continue
        if line.lower() == "/reload":
            messages = fresh_messages()
            print("(context reloaded from docs + session)")
            continue
        if line.lower().startswith("/logs"):
            parts = line.split()
            log_name = parts[1] if len(parts) > 1 else ""
            print(fetch_logs(log_name))
            print()
            continue
        if line.lower().startswith("/stream"):
            parts = line.split()
            if len(parts) < 2:
                print("Usage: /stream <name>  (e.g. /stream agency)")
                print("Known logs: agency, server, fulfiller, watchdog, flow, maid, n8n")
                print()
                continue
            log_name = parts[1]
            token_param = f"?token={LOG_TOKEN}" if LOG_TOKEN else ""
            stream_url = f"{DEFAULT_URL}/logs/stream/{log_name}{token_param}"
            print(f"Streaming {log_name} from {stream_url}")
            print("Press Ctrl+C to stop.\n")
            try:
                req = urllib.request.Request(stream_url)
                with urllib.request.urlopen(req, timeout=None) as r:
                    while True:
                        raw = r.readline()
                        if not raw:
                            break
                        decoded = raw.decode("utf-8", errors="replace").strip()
                        if decoded.startswith("data: "):
                            print(decoded[6:])
            except KeyboardInterrupt:
                print("\n(stream stopped)")
            except Exception as e:
                print(f"[Stream error] {e}")
            print()
            continue

        messages.append({"role": "user", "content": line})
        reply = chat(messages)
        messages.append({"role": "assistant", "content": reply})
        print("Aura:", reply)
        print()


if __name__ == "__main__":
    main()
