#!/bin/bash
watch -t -n 2 "
echo '========================================================================'
echo '                   🛡️ AI WEALTH AGENCY COMMAND CENTER 🛡️'
echo '========================================================================'
echo '⏱️  SYSTEM TIME:' \$(date)
echo '------------------------------------------------------------------------'
echo '🧠 OLLAMA BRAIN LOAD:'
top -b -n 1 | head -n 12 | grep -E 'PID|ollama' || echo 'No active Ollama operations right now.'
echo '------------------------------------------------------------------------'
echo '📄 LIVE AGENCY ACTIVITY (Last 20 Log Events):'
tail -n 20 /home/yani/Aura/ai_agency_wealth/agency_metrics.log || echo 'Waiting for logs...'
echo '========================================================================'
"