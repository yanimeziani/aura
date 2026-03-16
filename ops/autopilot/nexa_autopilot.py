#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import signal
import subprocess
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path


RUNNING = True


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def root_dir() -> Path:
    return Path(os.environ.get("NEXA_ROOT", os.environ.get("AURA_ROOT", Path(__file__).resolve().parents[2])))


def state_dir() -> Path:
    path = root_dir() / ".aura" / "autopilot"
    path.mkdir(parents=True, exist_ok=True)
    return path


def state_path() -> Path:
    return state_dir() / "state.json"


def gateway_log_path() -> Path:
    return state_dir() / "nexa-gateway.log"


def load_state() -> dict:
    try:
        return json.loads(state_path().read_text(encoding="utf-8"))
    except Exception:
        return {}


def save_state(payload: dict) -> None:
    state_path().write_text(json.dumps(payload, indent=2), encoding="utf-8")


def port() -> str:
    return os.environ.get("NEXA_GATEWAY_PORT", os.environ.get("AURA_GATEWAY_PORT", "9080"))


def gateway_url() -> str:
    return f"http://127.0.0.1:{port()}"


def health_url() -> str:
    return gateway_url() + "/api/health"


def health_ok() -> bool:
    try:
        with urllib.request.urlopen(health_url(), timeout=1.5) as response:
            payload = json.loads(response.read().decode("utf-8"))
        return payload.get("status") == "ok"
    except Exception:
        return False


def run_command(cmd: list[str], *, cwd: Path | None = None) -> tuple[int, str]:
    result = subprocess.run(
        cmd,
        cwd=str(cwd or root_dir()),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    return result.returncode, result.stdout[-4000:]


def ensure_gateway_binary() -> tuple[bool, str]:
    gateway_dir = root_dir() / "core" / "nexa-gateway"
    rc, output = run_command(["zig", "build", "-Doptimize=ReleaseSafe"], cwd=gateway_dir)
    return rc == 0, output


def start_gateway() -> tuple[bool, str]:
    gateway_bin = root_dir() / "core" / "nexa-gateway" / "zig-out" / "bin" / "nexa-gateway"
    if not gateway_bin.exists():
        return False, "gateway binary missing"
    log_file = gateway_log_path().open("a", encoding="utf-8")
    subprocess.Popen(
        [str(gateway_bin)],
        cwd=str(gateway_bin.parent.parent.parent),
        env={**os.environ, "NEXA_GATEWAY_PORT": port()},
        stdout=log_file,
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )
    for _ in range(20):
        time.sleep(0.5)
        if health_ok():
            return True, "gateway started"
    return False, "gateway failed health check after start"


def maybe_run_docs_bundle(state: dict) -> tuple[bool, str]:
    interval = int(os.environ.get("NEXA_DOCS_INTERVAL_SEC", "1800"))
    last = float(state.get("docs_bundle_ts") or 0.0)
    if time.time() - last < interval:
        return True, "docs bundle not due"
    rc, output = run_command(["python3", str(root_dir() / "ops" / "scripts" / "build-nexa-docs-bundle.py")])
    if rc == 0:
        state["docs_bundle_ts"] = time.time()
        return True, "docs bundle refreshed"
    return False, output


def maybe_run_ops_cast(state: dict) -> tuple[bool, str]:
    interval = int(os.environ.get("NEXA_OPS_CAST_INTERVAL_SEC", "3600"))
    last = float(state.get("ops_cast_ts") or 0.0)
    if time.time() - last < interval:
        return True, "ops cast not due"
    source = os.environ.get("NEXA_OPS_CAST_SOURCE", "agency_metrics")
    provider = os.environ.get("NEXA_OPS_CAST_PROVIDER", "local")
    model = os.environ.get("NEXA_OPS_CAST_MODEL", "qwen2.5:14b-instruct")
    cmd = [
        "python3",
        str(root_dir() / "core" / "vault" / "ops_cast.py"),
        "--source",
        source,
        "--provider",
        provider,
        "--model",
        model,
        "--target-minutes",
        os.environ.get("NEXA_OPS_CAST_MINUTES", "60"),
        "--target-words",
        os.environ.get("NEXA_OPS_CAST_WORDS", "7000"),
    ]
    if os.environ.get("NEXA_OPS_CAST_AUDIO", "0") in {"1", "true", "yes", "on"}:
        cmd.append("--audio")
    rc, output = run_command(cmd)
    if rc == 0:
        state["ops_cast_ts"] = time.time()
        return True, output.strip() or "ops cast generated"
    return False, output


def maybe_run_backup(state: dict) -> tuple[bool, str]:
    if os.environ.get("NEXA_AUTOPILOT_BACKUP", "0") not in {"1", "true", "yes", "on"}:
        return True, "backup automation disabled"
    interval = int(os.environ.get("NEXA_BACKUP_INTERVAL_SEC", "86400"))
    last = float(state.get("backup_ts") or 0.0)
    if time.time() - last < interval:
        return True, "backup not due"
    rc, output = run_command(["bash", str(root_dir() / "ops" / "scripts" / "backup-dynamic-then-delete.sh")])
    if rc == 0:
        state["backup_ts"] = time.time()
        return True, "backup completed"
    return False, output


def run_cycle() -> int:
    state = load_state()
    state["last_cycle_at"] = utc_now()
    state["gateway_url"] = gateway_url()
    state["critical_actions_require_hitl"] = True

    ok, output = ensure_gateway_binary()
    state["build_ok"] = ok
    state["build_output"] = output
    if not ok:
        state["last_error"] = "gateway build failed"
        save_state(state)
        return 1

    if not health_ok():
        ok, output = start_gateway()
        state["gateway_started"] = ok
        state["gateway_start_output"] = output
        if not ok:
            state["last_error"] = output
            save_state(state)
            return 1
    else:
        state["gateway_started"] = True
        state["gateway_start_output"] = "gateway already healthy"

    task_results = {}
    for name, fn in (
        ("docs_bundle", maybe_run_docs_bundle),
        ("ops_cast", maybe_run_ops_cast),
        ("backup", maybe_run_backup),
    ):
        ok, output = fn(state)
        task_results[name] = {"ok": ok, "output": output}
        if not ok:
            state["last_error"] = f"{name} failed"

    state["tasks"] = task_results
    state["healthy"] = health_ok()
    state["last_success_at"] = utc_now() if state["healthy"] else state.get("last_success_at")
    save_state(state)
    return 0 if state["healthy"] else 1


def loop(interval: int) -> int:
    global RUNNING
    while RUNNING:
        run_cycle()
        for _ in range(max(interval, 5)):
            if not RUNNING:
                break
            time.sleep(1)
    return 0


def show_status() -> int:
    print(json.dumps(load_state(), indent=2))
    return 0


def stop_handler(_signum, _frame) -> None:
    global RUNNING
    RUNNING = False


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Nexa autopilot control loop.")
    sub = parser.add_subparsers(dest="cmd", required=True)

    run_cmd = sub.add_parser("run-once", help="Run one automation cycle.")
    run_cmd.add_argument("--interval", type=int, default=60)

    loop_cmd = sub.add_parser("loop", help="Run continuous automation loop.")
    loop_cmd.add_argument("--interval", type=int, default=60)

    sub.add_parser("status", help="Print autopilot state.")

    args = parser.parse_args(argv)

    signal.signal(signal.SIGTERM, stop_handler)
    signal.signal(signal.SIGINT, stop_handler)

    if args.cmd == "run-once":
        return run_cycle()
    if args.cmd == "loop":
        return loop(args.interval)
    return show_status()


if __name__ == "__main__":
    sys.exit(main())
