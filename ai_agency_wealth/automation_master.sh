#!/bin/bash
source ~/ai_agency_wealth/venv_agency/bin/activate
echo "================================================"
echo "🛡️  AUTONOMOUS MASTER ORCHESTRATOR BOOTING  🛡️"
echo "================================================"

echo "[1/7] Running Global Yield & Market Research..."
python3 ~/ai_agency_wealth/main.py

echo "[2/7] Running Algeria SMB Automation Strategy..."
python3 ~/ai_agency_wealth/algeria_smb_dept.py

echo "[3/7] Running LLM Engineering & R&D Strategy..."
python3 ~/ai_agency_wealth/llm_engineering_dept.py

echo "[4/7] Running Wealthsimple USD Growth Strategy..."
python3 ~/ai_agency_wealth/wealthsimple_dept.py

echo "[5/7] Running Private Health (HSA) Strategy..."
python3 ~/ai_agency_wealth/health_dept.py

echo "[6/7] Running Nomadic Operations & eSim Strategy..."
python3 ~/ai_agency_wealth/nomad_ops_dept.py

echo "[7/10] Running Virtual Accountant (Payroll/Paystub)..."
python3 ~/ai_agency_wealth/accounting_dept.py

echo "[8/10] Hunting for New High-Value Leads..."
python3 ~/ai_agency_wealth/lead_gen_dept.py

echo "[9/10] Executing Automated Outreach Engine..."
python3 ~/ai_agency_wealth/outreach_engine.py

echo "[10/10] Generating Disruptive Global Newsletter..."
python3 ~/ai_agency_wealth/global_newsletter_dept.py

echo "================================================"
echo "✅ Sovereign Nomad Orchestration Cycle Complete."
echo "================================================"
