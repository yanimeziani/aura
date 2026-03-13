import os
import subprocess
import time
import json
from datetime import datetime

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)

# Layer 0 — Zig compiler runtime
ZIGGYC_BIN = os.path.join(REPO_ROOT, "ziggy-compiler", "zig-out", "bin", "ziggyc")

LOG_FILES = {
    # Prefer the actual uvicorn log file name in this repo.
    "payment_server": os.path.join(SCRIPT_DIR, "server.log"),
    # Legacy/alternate name (some deployments use this).
    "payment_server_debug": os.path.join(SCRIPT_DIR, "server_debug.log"),
    "agency_metrics": os.path.join(SCRIPT_DIR, "agency_metrics.log"),
    "n8n": os.path.join(SCRIPT_DIR, "n8n.log"),
    "fulfiller": os.path.join(SCRIPT_DIR, "fulfiller.log"),
}

WATCHDOG_STATE = os.path.join(SCRIPT_DIR, "watchdog_state.json")

def clean_log(file_path, max_lines=1000):
    if not os.path.exists(file_path):
        return
    try:
        with open(file_path, 'r') as f:
            lines = f.readlines()
        if len(lines) > max_lines:
            with open(file_path, 'w') as f:
                f.writelines(lines[-max_lines:])
            print(f"🧹 Cleaned {file_path}: truncated to last {max_lines} lines.")
    except Exception as e:
        print(f"❌ Failed to clean {file_path}: {e}")

def _read_tail(path: str, *, max_lines: int = 400) -> str:
    if not os.path.exists(path):
        return ""
    try:
        with open(path, "r") as f:
            lines = f.readlines()
        return "".join(lines[-max_lines:])
    except Exception:
        return ""

def check_zig_layer() -> dict | None:
    """Layer 0: verify ziggyc binary is present and responsive.
    Returns an issue dict on failure, None on pass."""
    if not os.path.isfile(ZIGGYC_BIN):
        return {"layer": 0, "component": "ziggyc", "severity": "CRITICAL",
                "msg": f"ziggyc binary missing at {ZIGGYC_BIN}"}
    if not os.access(ZIGGYC_BIN, os.X_OK):
        return {"layer": 0, "component": "ziggyc", "severity": "CRITICAL",
                "msg": "ziggyc binary not executable"}
    try:
        result = subprocess.run(
            [ZIGGYC_BIN],
            capture_output=True, timeout=5
        )
        # ziggyc exits non-zero when given no file — that's expected.
        # A crash (signal, timeout, or unexpected stderr) is what we flag.
        stderr = result.stderr.decode(errors="replace")
        if result.returncode < 0:          # killed by signal
            return {"layer": 0, "component": "ziggyc", "severity": "CRITICAL",
                    "msg": f"ziggyc terminated by signal {-result.returncode}"}
    except subprocess.TimeoutExpired:
        return {"layer": 0, "component": "ziggyc", "severity": "CRITICAL",
                "msg": "ziggyc health probe timed out (>5s)"}
    except Exception as e:
        return {"layer": 0, "component": "ziggyc", "severity": "CRITICAL",
                "msg": f"ziggyc probe failed: {e}"}
    return None  # healthy


def validate_logs():
    health_report = {
        "timestamp": datetime.now().isoformat(),
        "status": "HEALTHY",
        "issues": []
    }

    # ── Layer 0: Zig compiler runtime ──────────────────────────────────────
    zig_issue = check_zig_layer()
    if zig_issue:
        health_report["status"] = "CRITICAL"
        health_report["issues"].append(zig_issue)
        return health_report  # halt — no point checking higher layers

    # 1. Check Payment Server (Stripe)
    for key in ("payment_server", "payment_server_debug"):
        path = LOG_FILES.get(key)
        if path and os.path.exists(path):
            content = _read_tail(path)
            if "ERROR" in content or "traceback" in content.lower() or " 500 " in content:
                health_report["status"] = "WARNING"
                health_report["issues"].append(f"Payment Server log indicates errors ({os.path.basename(path)}).")
                break

    # 2. Check Fulfiller (Missing modules, etc)
    if os.path.exists(LOG_FILES["fulfiller"]):
        with open(LOG_FILES["fulfiller"], 'r') as f:
            content = f.read()
            if "MODULE_NOT_FOUND" in content:
                health_report["status"] = "DEGRADED"
                health_report["issues"].append("Fulfiller module is missing.")

    # 3. Check Agency Metrics (end-to-end orchestrator errors)
    if os.path.exists(LOG_FILES["agency_metrics"]):
        content = _read_tail(LOG_FILES["agency_metrics"])
        low = content.lower()
        if "traceback (most recent call last)" in low:
            health_report["status"] = "DEGRADED"
            health_report["issues"].append("Orchestrator crashed (Traceback in agency_metrics.log).")
        elif "modulenotfounderror" in low:
            health_report["status"] = "DEGRADED"
            health_report["issues"].append("Orchestrator missing Python dependencies (ModuleNotFoundError).")
        elif "keyerror" in low:
            health_report["status"] = "WARNING"
            health_report["issues"].append("Orchestrator encountered schema mismatch (KeyError).")

    # 3. Check n8n
    if os.path.exists(LOG_FILES["n8n"]):
        with open(LOG_FILES["n8n"], 'r') as f:
            content = f.read()
            if "port 5678 is already in use" in content:
                health_report["status"] = "DEGRADED"
                health_report["issues"].append("n8n port conflict detected.")

    return health_report

if __name__ == "__main__":
    print(f"🛡️  WATCHDOG STARTING: {datetime.now()}")
    
    report = validate_logs()
    print(f"🏥 SYSTEM STATUS: {report['status']}")
    for issue in report['issues']:
        print(f"  - ⚠️ {issue}")

    with open(WATCHDOG_STATE, 'w') as f:
        json.dump(report, f, indent=4)

    # Auto-Cleaning Cycle
    for log_name, path in LOG_FILES.items():
        clean_log(path)
