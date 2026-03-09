#!/bin/bash
# 🛡️ Sovereign AI Wealth Agency - INFINITE AUTOPILOT MODE 🛡️

cd /home/yani/ai_agency_wealth
source venv_agency/bin/activate

LOG_FILE="agency_metrics.log"
WATCHDOG_LOG="watchdog_status.log"

echo "================================================="
echo "🚀 AUTOPILOT INITIALIZED AT $(date) 🚀"
echo "================================================="

while true; do
    echo "[$(date)] 🔄 STARTING NEW ORCHESTRATION CYCLE..." | tee -a $LOG_FILE
    
    # 1. Run the Master Orchestrator
    ./automation_master.sh >> $LOG_FILE 2>&1
    
    # 2. Run the Watchdog & Log Cleaner
    echo "[$(date)] 🛡️  RUNNING HEALTH CHECK & LOG CLEANUP..." | tee -a $LOG_FILE
    python3 log_watchdog.py >> $WATCHDOG_LOG 2>&1
    
    # 3. Check Watchdog Status
    STATUS=$(grep "🏥 SYSTEM STATUS:" $WATCHDOG_LOG | tail -n 1)
    echo "[$(date)] $STATUS" | tee -a $LOG_FILE
    
    echo "[$(date)] ✅ Cycle Complete. Resting for 10 minutes..." | tee -a $LOG_FILE
    echo "-------------------------------------------------" >> $LOG_FILE
    
    # Sleep 600s (10 mins) to balance market agility with API/Compute cost
    sleep 600
done
