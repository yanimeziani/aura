import os
import time
import json
from datetime import datetime

LOG_FILES = {
    "payment_server": "/home/yani/ai_agency_wealth/server_debug.log",
    "agency_metrics": "/home/yani/ai_agency_wealth/agency_metrics.log",
    "n8n": "/home/yani/n8n.log",
    "fulfiller": "/home/yani/fulfiller.log"
}

WATCHDOG_STATE = "/home/yani/ai_agency_wealth/watchdog_state.json"

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

def validate_logs():
    health_report = {
        "timestamp": datetime.now().isoformat(),
        "status": "HEALTHY",
        "issues": []
    }

    # 1. Check Payment Server (Stripe)
    if os.path.exists(LOG_FILES["payment_server"]):
        with open(LOG_FILES["payment_server"], 'r') as f:
            content = f.read()
            if "ERROR" in content or "traceback" in content.lower():
                health_report["status"] = "WARNING"
                health_report["issues"].append("Payment Server has errors.")

    # 2. Check Fulfiller (Missing modules, etc)
    if os.path.exists(LOG_FILES["fulfiller"]):
        with open(LOG_FILES["fulfiller"], 'r') as f:
            content = f.read()
            if "MODULE_NOT_FOUND" in content:
                health_report["status"] = "DEGRADED"
                health_report["issues"].append("Fulfiller module is missing.")

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
