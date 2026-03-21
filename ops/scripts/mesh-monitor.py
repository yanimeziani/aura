import time
import json
import os
import subprocess
from datetime import datetime

# Aura Mesh Background Monitor
# Tracks health of: VPS, Z Fold 5, Jetson, and local nodes.

STATUS_FILE = "/root/vault/mesh_status.json"
NODES = {
    "vps-primary": "127.0.0.1",
    "z-fold-5": "100.64.0.5",  # Placeholder for Tailscale IP
    "jetson-edge": "100.64.0.10", # Placeholder
    "rtx-server": "100.64.0.20"  # Placeholder
}

def check_node(ip):
    try:
        # Fast ping: 1 packet, 1 second timeout
        subprocess.check_output(["ping", "-c", "1", "-W", "1", ip])
        return "online"
    except:
        return "offline"

def monitor_mesh():
    print(f"🚀 Starting Aura Mesh Monitor (PID: {os.getpid()})")
    
    while True:
        status = {
            "last_update": datetime.now().isoformat(),
            "nodes": {}
        }
        
        for name, ip in NODES.items():
            state = check_node(ip)
            status["nodes"][name] = {
                "ip": ip,
                "status": state,
                "last_seen": datetime.now().isoformat() if state == "online" else "N/A"
            }
            
        # Write to vault
        os.makedirs(os.path.dirname(STATUS_FILE), exist_ok=True)
        with open(STATUS_FILE, "w") as f:
            json.dump(status, f, indent=2)
            
        time.sleep(60) # Run every minute

if __name__ == "__main__":
    monitor_mesh()
