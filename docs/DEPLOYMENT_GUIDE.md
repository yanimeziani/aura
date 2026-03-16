# Nexa: Deployment & Configuration Guide

This guide provides the necessary procedures for deploying and configuring Nexa components on a Linux-based system or VPS.

Deployment decisions should follow the protocol architecture and trust assumptions in [ARCHITECTURE.md](/root/docs/ARCHITECTURE.md), [PROTOCOL.md](/root/docs/PROTOCOL.md), [TRUST_MODEL.md](/root/docs/TRUST_MODEL.md), and [THREAT_MODEL.md](/root/docs/THREAT_MODEL.md), especially for exposed services, transport routing, and recovery paths.

## Prerequisites

- **Zig Compiler**: Required for building the Cerberus runtime.
- **Node.js 22+ & npm**: Required for Aura Web.
- **Supabase**: Backend database and RLS management.
- **Android SDK**: Required for Pegasus mobile client.
- **API Access**: Access to OpenRouter or specific LLM providers (e.g., Claude, Llama).

---

## 1. System Initialization

### Initialize Agent Memory
```bash
cd /root/ops/scripts
bash init-career-twin-memory.sh
bash init-sdr-memory.sh
```

These scripts create local-first memory structures in `~/.cerberus/memory/`.

### Configuration Management
Create the following environment files in `~/.cerberus/`:

**`career-twin.env`**:
```bash
OPENROUTER_API_KEY=your_key_here
CERBERUS_AGENT=career_twin
CERBERUS_CONFIG=/root/core/cerberus/configs/career-twin-agent.json
```

**`sdr.env`**:
```bash
OPENROUTER_API_KEY=your_key_here
RESEND_API_KEY=your_key_here
CERBERUS_AGENT=sdr
CERBERUS_CONFIG=/root/core/cerberus/configs/sdr-agent.json
```

---

## 2. Core Runtime Deployment (Cerberus)

### Build the Runtime
```bash
cd /root/core/cerberus/runtime/cerberus-core
zig build -Doptimize=ReleaseSmall
```

### Run in CLI Mode (Testing)
```bash
./zig-out/bin/cerberus --config /root/core/cerberus/configs/career-twin-agent.json --cli
```

### Production Service (systemd)
```ini
[Unit]
Description=Cerberus Agent Runtime
After=network.target

[Service]
Type=simple
WorkingDirectory=/root/core/cerberus/runtime/cerberus-core
EnvironmentFile=/root/.cerberus/career-twin.env
ExecStart=/root/core/cerberus/runtime/cerberus-core/zig-out/bin/cerberus --config /root/core/cerberus/configs/career-twin-agent.json
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

---

## 3. Aura Web Deployment (Dashboard)

### Database Migration
```bash
cd /root/apps/web
npm install
npm run db:check
```

### Build & Start
```bash
npm run build
npm run start
```

---

## 4. Mobile Client Initialization (Pegasus)

### Build APK
```bash
cd /root/apps/mobile
./gradlew assembleDebug
```

---

## 5. Security Checklist

- [ ] **RLS Policies**: Verify all database tables have Row-Level Security enabled.
- [ ] **HITL Verification**: Ensure `CERBERUS_AGENT_MODE` is set to include HITL gates.
- [ ] **Secrets Hygiene**: Confirm no `.env` files are tracked in version control.
- [ ] **Audit Logging**: Verify `/root/.cerberus/logs/audit.log` is receiving agent telemetry.

---

## Troubleshooting & Maintenance

### Logs
- **Systemd Logs**: `sudo journalctl -u cerberus-* -f`
- **Dashboard Logs**: `npm run start` output or pm2 logs.
- **Agent Memory**: Examine `~/.cerberus/memory/` for data persistence status.

### Performance Monitoring
- **Token Budget**: Monitor `cost.log` for provider expenditures.
- **Binary Footprint**: Verify the Cerberus binary remains <1MB for optimal performance.
