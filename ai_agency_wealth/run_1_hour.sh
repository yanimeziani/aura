#!/bin/bash
echo "================================================"
echo "⏳ STARTING 1-HOUR AGENCY ENDURANCE RUN ⏳"
echo "================================================"

LOG_FILE="/home/yani/ai_agency_wealth/agency_metrics.log"
echo "Agency Run Started at $(date)" > $LOG_FILE

END_TIME=$(($(date +%s) + 3600))
CYCLE_COUNT=1

while [ $(date +%s) -lt $END_TIME ]; do
    echo "================================================" >> $LOG_FILE
    echo "🔄 INITIATING CYCLE $CYCLE_COUNT AT $(date)" >> $LOG_FILE
    echo "================================================" >> $LOG_FILE
    
    # Run the master orchestrator
    /home/yani/ai_agency_wealth/automation_master.sh >> $LOG_FILE 2>&1
    
    echo "✅ Cycle $CYCLE_COUNT Complete." >> $LOG_FILE
    echo "💤 Agents resting for 5 minutes before next market scan..." >> $LOG_FILE
    
    # Sleep for 5 minutes (300 seconds) between cycles to not overload Ollama/APIs
    sleep 300 
    ((CYCLE_COUNT++))
done

echo "================================================" >> $LOG_FILE
echo "🛑 1-HOUR RUN COMPLETE AT $(date). TOTAL CYCLES: $CYCLE_COUNT" >> $LOG_FILE
echo "================================================" >> $LOG_FILE
