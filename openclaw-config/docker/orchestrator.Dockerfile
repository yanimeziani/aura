# orchestrator.Dockerfile — OpenClaw Orchestrator
# Minimal FastAPI service: health, HITL queue, cost tracking, panic mode
FROM python:3.12-slim

WORKDIR /app

# Install curl (needed for healthcheck) + Python deps
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*
COPY orchestrator/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy app
COPY orchestrator/main.py .

# Run as UID 1001 to match host openclaw user (owns /data/openclaw)
RUN groupadd -g 1001 openclaw && useradd -u 1001 -g 1001 openclaw
USER openclaw

EXPOSE 8080
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080", "--log-level", "info"]
