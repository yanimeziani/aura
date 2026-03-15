# Aura: Sovereign Agentic Monorepo

> **"Hardware is ephemeral. Sovereignty is persistent."**

Aura is a holistic, decentralized framework for AI research, deployment, and autonomous agent orchestration. It provides a secure technical layer for hosting specialized personas with absolute sovereignty and human-in-the-loop (HITL) coordination.

---

## 🏛 The Ephemeral Hardware Manifesto

In the Aura ecosystem, physical devices are treated as disposable. Whether a developer drops their phone in a river or it is confiscated at a border, the protocol dictates that a **brand new off-the-shelf device** must be capable of being **fully restored to a sovereign state within exactly ten minutes.**

This is achieved through:
- **Dotfile Sovereignty**: All environment configurations are version-controlled and portable.
- **Agentic Recovery**: Automated scripts to rebuild the entire stack (Web, Mobile, Runtime) from source truth.
- **Cloud-Edge Parity**: Seamless deployment between local hardware and remote VPS infrastructure.

---

## 🚀 Quick Start: 0 to Sovereignty in 10 Min

### 1. Initialize Memory (30s)
```bash
bash core/cerberus/scripts/init-career-twin-memory.sh
bash core/cerberus/scripts/init-sdr-memory.sh
```

### 2. Build the Cerberus Runtime (1m)
```bash
cd core/cerberus/runtime/cerberus-core
zig build -Doptimize=ReleaseSmall
```

### 3. Deploy the Aura Web Dashboard (3m)
```bash
cd apps/web
npm install && npm run build
```

### 4. Provision Fresh VPS (5m)
```bash
bash ops/scripts/deploy-fresh-vps.sh
```

---

## 🧩 Core System Components

| Component | Tech Stack | Role |
|-----------|------------|------|
| **[Aura Web](./apps/web)** | Next.js 16, React 19, Tailwind 4 | High-throughput telemetry & control dashboard |
| **[Pegasus](./apps/mobile)** | Android (Kotlin), Jetpack Compose | Mobile mission control & HITL approvals |
| **[Cerberus Runtime](./core/cerberus)** | Zig (Native) | High-performance agent execution engine (<1MB binary) |
| **[Ops](./ops)** | Bash, Ansible | Infrastructure automation & 10-minute recovery scripts |

---

## 🤖 Specialized Agent Personas

1.  **Career-Twin Agent**: Autonomous professional profile management, inquiry handling, and interview scheduling.
2.  **SDR Agent**: Automated B2B sales development, prospect research, and personalized outreach sequences.

---

## 🛠 System Conventions

- **Vibe Coding**: High-velocity development through AI-orchestrated workflows.
- **Three-Tap Rule**: Any operation on Pegasus requiring >3 taps is a failure of automation.
- **Strict Zero-Trust**: Every network is assumed hostile. Sovereignty is maintained through local-first memory and encrypted transport.

---

## 📂 Repository Map

```text
/
├── apps/
│   ├── web/        # Aura Web Dashboard (Next.js)
│   └── mobile/     # Pegasus Mobile (Android/Kotlin)
├── core/
│   └── cerberus/   # Cerberus Engine & Persona Logic (Zig)
├── ops/            # 10-Minute Deployment & Recovery Scripts
├── docs/           # Technical Specs & Architecture Truth
└── research/       # Scientific Manifestos & LaTeX Sources
```

---

## 📈 Project Status

- **Supabase Schema**: ✅ Career-Twin & SDR tables initialized (2026-03-03).
- **Core Runtime**: ✅ Zig engine functional with multi-channel support.
- **Deployment**: ✅ `deploy-fresh-vps.sh` fully automated.
- **Security**: 🛠 TOR/IPFS integration (Planned/In-Progress).

---

## 📜 License

MIT License. See [LICENSE](./LICENSE) for details.
