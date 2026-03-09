#!/bin/bash
# Check Agent 1 Status for Z Fold 5 notification
LOG="/home/yani/ai_agency_wealth/agent1_loop.log"
if [ -f "$LOG" ]; then
    echo "🤖 AGENT 1 STATUS:"
    tail -n 2 "$LOG" | sed 's/===*//g' | xargs
else
    echo "⚠️ Agent 1 Log not found."
fi
