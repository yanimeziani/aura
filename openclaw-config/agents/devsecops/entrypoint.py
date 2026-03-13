#!/usr/bin/env python3
"""
OpenClaw Agent Entrypoint — BMAD v6 / Dragun.app

Uses Claude Code CLI (claude -p) for inference via Claude Pro OAuth.
No Anthropic API key required — auth is via claude auth login on the host.
"""

import json
import logging
import os
import re
import signal
import subprocess
import sys
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

import requests
import yaml

# ── Configuration ─────────────────────────────────────────────────────────────
AGENT_ID      = os.environ["AGENT_ID"]
CONFIG_PATH   = Path(os.getenv("AGENT_CONFIG", "/app/config/config.yaml"))
SYSTEM_MD     = Path("/app/config/prompts/system.md")
ORCHESTRATOR  = os.getenv("OPENCLAW_ORCHESTRATOR_URL", "http://openclaw:8080")
ARTIFACTS_DIR = Path(f"/data/openclaw/artifacts/{AGENT_ID}")
TASK_QUEUE    = Path(f"/data/openclaw/task-queue/{AGENT_ID}.jsonl")

ARTIFACTS_DIR.mkdir(parents=True, exist_ok=True)
TASK_QUEUE.parent.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format=f"[%(asctime)s] [{AGENT_ID}] %(levelname)s %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%SZ",
    stream=sys.stdout,
)
log = logging.getLogger(AGENT_ID)

# ── Load agent config ─────────────────────────────────────────────────────────
cfg          = yaml.safe_load(CONFIG_PATH.read_text())
SCHEDULE     = cfg["agent"]["schedule"]
DAILY_CAP    = cfg["cost_caps"]["daily_usd"]
PER_TASK_CAP = cfg["cost_caps"]["per_task_usd"]
MODEL_MAP    = {
    "cheap": cfg["model_routing"]["cheap"]["model"],
    "mid":   cfg["model_routing"]["mid"]["model"],
    "top":   cfg["model_routing"]["top"]["model"],
}
SYSTEM_PROMPT = SYSTEM_MD.read_text() if SYSTEM_MD.exists() else (
    f"You are the {AGENT_ID} agent for Dragun.app. Follow BMAD v6 doctrine."
)

# ── Tool call protocol ────────────────────────────────────────────────────────
TOOLS_DESC = """
## Tool Protocol

When you need to use a tool, output a single JSON object on its own line with no other text around it:

{"tool":"shell","command":"<bash command>","timeout":<seconds, default 60>}
{"tool":"read_file","path":"<absolute path>"}
{"tool":"write_file","path":"<absolute path>","content":"<file content>"}
{"tool":"request_hitl","action":"<one-line desc>","blast_radius":"local|staging|production|data","reversible":true|false,"diff_preview":"<diff>","risk_note":"<what could go wrong>","risk_label":"SAFE|REVIEW|BLOCKED"}
{"tool":"http_get","url":"<url>"}
{"tool":"done","summary":"<what was accomplished>"}

Rules:
- Exactly one tool call per response (a JSON line), OR a plain text analysis step.
- ALWAYS call request_hitl BEFORE any destructive, production-affecting, or externally-visible action.
- ALWAYS call done when the task is complete or you cannot proceed further.
- Never include secret values in commands or diffs.
"""


# ── Orchestrator helpers ──────────────────────────────────────────────────────

def _orch(method: str, path: str, **kwargs) -> Optional[dict]:
    try:
        r = requests.request(method, f"{ORCHESTRATOR}{path}", timeout=10, **kwargs)
        r.raise_for_status()
        return r.json()
    except Exception as e:
        log.warning(f"Orchestrator {method} {path} failed: {e}")
        return None


def heartbeat(status: str = "idle", task_id: Optional[str] = None):
    params = {"status": status}
    if task_id:
        params["task_id"] = task_id
    _orch("POST", f"/agents/{AGENT_ID}/heartbeat", params=params)


def check_panic() -> bool:
    r = _orch("GET", "/panic")
    return bool(r and r.get("panic"))


def check_cost_cap() -> bool:
    r = _orch("GET", "/costs/status")
    if not r:
        return False
    return r.get("agents", {}).get(AGENT_ID, {}).get("status") == "exceeded"


def record_cost(task_id: str, model: str, cost_usd: float):
    _orch("POST", "/costs/record", json={
        "agent_id": AGENT_ID,
        "task_id":  task_id,
        "model":    model,
        "cost_usd": cost_usd,
    })


def submit_hitl(task_id: str, action: str, blast_radius: str, reversible: bool,
                diff_preview: str = None, risk_note: str = None,
                risk_label: str = None) -> str:
    r = _orch("POST", "/hitl/submit", json={
        "task_id":      task_id,
        "agent_id":     AGENT_ID,
        "action":       action,
        "blast_radius": blast_radius,
        "reversible":   reversible,
        "diff_preview": diff_preview,
        "risk_note":    risk_note,
        "risk_label":   risk_label,
    })
    item_id = (r or {}).get("id", task_id)
    log.info(f"HITL submitted — id={item_id} action={action}")
    return item_id


def wait_for_hitl(item_id: str, poll_s: int = 30, timeout_s: int = 86400) -> str:
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        r = _orch("GET", f"/hitl/{item_id}")
        if r:
            status = r.get("status", "pending")
            if status in ("approved", "rejected"):
                log.info(f"HITL {item_id} → {status}")
                return status
        heartbeat("waiting_hitl", task_id=item_id)
        time.sleep(poll_s)
    return "timeout"


# ── Tool execution ────────────────────────────────────────────────────────────

def run_tool(call: dict, task_id: str) -> str:
    name = call.get("tool", "")

    if name == "shell":
        cmd     = call["command"]
        timeout = int(call.get("timeout", 60))
        log.info(f"shell: {cmd[:120]}")
        try:
            r = subprocess.run(
                cmd, shell=True, capture_output=True, text=True,
                timeout=timeout, env=os.environ.copy(),
            )
            out = (r.stdout + r.stderr).strip()
            return out[:8000] if len(out) > 8000 else out or "(no output)"
        except subprocess.TimeoutExpired:
            return f"ERROR: timed out after {timeout}s"
        except Exception as e:
            return f"ERROR: {e}"

    if name == "read_file":
        try:
            return Path(call["path"]).read_text()[:8000]
        except Exception as e:
            return f"ERROR: {e}"

    if name == "write_file":
        try:
            p = Path(call["path"])
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(call["content"])
            return f"Written {len(call['content'])} chars to {p}"
        except Exception as e:
            return f"ERROR: {e}"

    if name == "request_hitl":
        item_id = submit_hitl(
            task_id=task_id,
            action=call["action"],
            blast_radius=call["blast_radius"],
            reversible=call["reversible"],
            diff_preview=call.get("diff_preview"),
            risk_note=call.get("risk_note"),
            risk_label=call.get("risk_label"),
        )
        result = wait_for_hitl(item_id)
        return f"HITL {item_id}: {result}"

    if name == "http_get":
        try:
            r = requests.get(call["url"], headers=call.get("headers", {}), timeout=15)
            return json.dumps({"status": r.status_code, "body": r.text[:4000]})
        except Exception as e:
            return f"ERROR: {e}"

    return f"ERROR: unknown tool {name!r}"


# ── Model selection ───────────────────────────────────────────────────────────

def pick_model(description: str) -> tuple[str, str]:
    d       = description.lower()
    top_kw  = {"incident", "production", "p1", "architecture", "threat", "complex", "redesign"}
    mid_kw  = {"bug", "security", "scan", "pipeline", "scraper", "ab_test", "analytics",
                "experiment", "investigation", "funnel"}
    if any(w in d for w in top_kw):
        return MODEL_MAP["top"], "top"
    if any(w in d for w in mid_kw):
        return MODEL_MAP["mid"], "mid"
    return MODEL_MAP["cheap"], "cheap"


# ── Claude CLI ────────────────────────────────────────────────────────────────

_TOOL_RE = re.compile(r'^\s*(\{[^{}\n]*"tool"\s*:[^{}\n]*\})\s*$', re.MULTILINE)


MCP_CONFIG = Path("/app/mcp-servers.json")


def _claude_env() -> dict:
    env = os.environ.copy()
    if "CLAUDE_CONFIG_DIR" not in env:
        env["CLAUDE_CONFIG_DIR"] = str(Path.home() / ".claude")
    env["CLAUDE_SKIP_AUTO_UPDATE"] = "1"
    return env


def _call_claude(conversation: list[dict], model: str) -> tuple[str, float]:
    """
    Build a single prompt from the conversation history and call claude -p.
    Returns (response_text, cost_usd).
    conversation: [{"role":"user"|"assistant","content":"..."}]
    """
    parts = []
    for msg in conversation:
        label = "User" if msg["role"] == "user" else "Assistant"
        parts.append(f"[{label}]\n{msg['content']}")
    prompt = "\n\n".join(parts)

    cmd = [
        "claude", "-p", prompt,
        "--system-prompt", SYSTEM_PROMPT + "\n\n" + TOOLS_DESC,
        "--model", model,
        "--output-format", "json",
    ]

    if MCP_CONFIG.exists():
        cmd.extend(["--mcp-config", str(MCP_CONFIG)])

    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=180, env=_claude_env(),
        )
        if result.returncode != 0:
            err = (result.stderr or result.stdout)[:500]
            log.warning(f"claude exit {result.returncode}: {err}")
            return f"[claude error: {err}]", 0.0
        try:
            data = json.loads(result.stdout.strip())
            return data.get("result", result.stdout), float(data.get("cost_usd", 0.0))
        except json.JSONDecodeError:
            return result.stdout.strip(), 0.0
    except subprocess.TimeoutExpired:
        return "[claude timeout after 180s]", 0.0
    except FileNotFoundError:
        return "[claude CLI not found — complete 'claude auth login' on VPS host]", 0.0


def _parse_tool(text: str) -> Optional[dict]:
    for match in _TOOL_RE.finditer(text):
        try:
            obj = json.loads(match.group(1))
            if "tool" in obj:
                return obj
        except json.JSONDecodeError:
            pass
    return None


# ── Agentic task loop ─────────────────────────────────────────────────────────

def run_task(task: dict) -> dict:
    task_id     = task.get("id", str(uuid.uuid4())[:8])
    description = task.get("description", "No description")
    model, tier = pick_model(description)

    log.info(f"Task {task_id} start | model={tier}({model}) | {description[:80]}")
    heartbeat("running", task_id=task_id)

    conversation = [{"role": "user", "content": description}]
    total_cost   = 0.0
    final_text   = ""

    for step in range(20):
        response, cost = _call_claude(conversation, model)
        total_cost += cost
        log.info(f"Step {step+1} | ~${total_cost:.4f} | {response[:120]}")

        # Per-task cost guard
        if total_cost > PER_TASK_CAP:
            log.warning(f"Task {task_id} hit per-task cap ${PER_TASK_CAP}")
            final_text = f"[STOPPED: per-task cost cap ${PER_TASK_CAP} at ~${total_cost:.4f}]"
            break

        tool_call = _parse_tool(response)

        if not tool_call:
            # Plain analysis step — append and continue
            conversation.append({"role": "assistant", "content": response})
            conversation.append({"role": "user", "content": "Continue."})
            final_text = response
            continue

        if tool_call["tool"] == "done":
            final_text = tool_call.get("summary", response)
            log.info(f"Task {task_id} done: {final_text[:120]}")
            break

        # Execute tool
        tool_result = run_tool(tool_call, task_id)
        log.info(f"Tool {tool_call['tool']} → {tool_result[:120]}")

        conversation.append({"role": "assistant", "content": response})
        conversation.append({"role": "user", "content": f"[tool result]\n{tool_result}"})

    else:
        final_text = "Task reached max steps (20)."

    # Record cost + write artifact
    record_cost(task_id, model, total_cost)
    ts       = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S")
    artifact = ARTIFACTS_DIR / f"{task_id}_{ts}.md"
    artifact.write_text(
        f"# Task: {description}\n\n**ID:** {task_id}  \n**Agent:** {AGENT_ID}  \n"
        f"**Model:** {model}  \n**Cost:** ~${total_cost:.4f}\n\n---\n\n{final_text}"
    )
    log.info(f"Task {task_id} complete | ~${total_cost:.4f} | artifact={artifact.name}")
    heartbeat("idle")

    return {"task_id": task_id, "model": model, "cost_usd": total_cost, "artifact": str(artifact)}


# ── Task queue ────────────────────────────────────────────────────────────────

def pop_task() -> Optional[dict]:
    if not TASK_QUEUE.exists():
        return None
    lines = [l for l in TASK_QUEUE.read_text().splitlines() if l.strip()]
    if not lines:
        return None
    task = json.loads(lines[0])
    TASK_QUEUE.write_text("\n".join(lines[1:]))
    return task


# ── Signal handling ───────────────────────────────────────────────────────────

_SHUTDOWN = False


def _handle_signal(sig, _frame):
    global _SHUTDOWN
    log.info(f"Signal {sig} — draining and shutting down")
    _SHUTDOWN = True


signal.signal(signal.SIGTERM, _handle_signal)
signal.signal(signal.SIGINT,  _handle_signal)


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    log.info(f"Starting — schedule={SCHEDULE} daily_cap=${DAILY_CAP} per_task=${PER_TASK_CAP}")

    env_task = os.getenv("AGENT_TASK")
    if env_task:
        if check_panic():
            log.error("Panic mode active — refusing task"); sys.exit(1)
        if check_cost_cap():
            log.error("Daily cap exceeded — refusing task"); sys.exit(1)
        run_task({"id": str(uuid.uuid4())[:8], "description": env_task})
        sys.exit(0)

    poll_s = 30 if SCHEDULE == "always_on" else 300

    while not _SHUTDOWN:
        heartbeat("idle")

        if check_panic():
            log.warning("Panic mode — sleeping 60s")
            time.sleep(60)
            continue

        if check_cost_cap():
            action = cfg["cost_caps"].get("hard_cap_action", "pause_agent_and_alert")
            log.warning(f"Daily cap exceeded — {action}, sleeping 300s")
            time.sleep(300)
            continue

        task = pop_task()
        if task:
            try:
                run_task(task)
            except Exception as exc:
                log.error(f"Task failed: {exc}", exc_info=True)
                heartbeat("error")
        else:
            time.sleep(poll_s)

    log.info("Shutdown complete")


if __name__ == "__main__":
    main()
