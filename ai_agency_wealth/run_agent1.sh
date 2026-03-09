#!/bin/bash

# Activate the agency virtual environment
source /home/yani/ai_agency_wealth/venv_agency/bin/activate

LOG_FILE="/home/yani/ai_agency_wealth/agent1_final.log"
echo "Agent 1 Loop Started at $(date)" > $LOG_FILE

while true; do
    echo "================================================" >> $LOG_FILE
    echo "▶️ INITIATING AGENT 1 TASK AT $(date)" >> $LOG_FILE
    echo "================================================" >> $LOG_FILE
    
    # Run the Agent 1 task
    python3 /home/yani/ai_agency_wealth/agent1_legality_dept.py >> $LOG_FILE 2>&1
    
    echo "✅ Task Complete. Agent 1 initiating 30-minute delay (1800s)..." >> $LOG_FILE
    
    # 30 minute delay
    sleep 1800
done
