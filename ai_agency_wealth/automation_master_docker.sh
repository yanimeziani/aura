#!/bin/bash
echo "================================================"
echo "🛡️  AUTONOMOUS MASTER ORCHESTRATOR BOOTING (DOCKER) 🛡️"
echo "================================================"

echo "[1/5] Running Global Yield & Market Research..."
python3 main.py

echo "[2/5] Running Algeria SMB Automation Strategy..."
python3 algeria_smb_dept.py

echo "[3/5] Running LLM Engineering & R&D Strategy..."
python3 llm_engineering_dept.py

echo "[4/5] Running Wealthsimple USD Growth Strategy..."
python3 wealthsimple_dept.py

echo "[5/5] Running Virtual Accountant (Payroll/Paystub)..."
python3 accounting_dept.py

echo "================================================"
echo "✅ Orchestration Cycle Complete."
echo "================================================"