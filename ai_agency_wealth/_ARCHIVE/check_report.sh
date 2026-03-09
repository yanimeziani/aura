#!/bin/bash
# Money Report for Z Fold 5 notification
REPORT="/home/yani/ai_agency_wealth/agent1_legality_report.txt"
if [ -f "$REPORT" ]; then
    echo "📜 MONEY REPORT:"
    tail -n 1 "$REPORT" | xargs
else
    echo "⚠️ Money Report not found. Generating now..."
fi
