#!/bin/bash
source /home/yani/ai_agency_wealth/venv_agency/bin/activate
exec uvicorn prod_payment_server:app --host 0.0.0.0 --port 8000
