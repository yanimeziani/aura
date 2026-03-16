# Nexa: Sovereign Agentic Monorepo

> **"Hardware is ephemeral. Sovereignty is persistent."**

**⚠️ [Disclaimer and responsible use](./DISCLAIMER.md)** — This software is provided "as is." You may not use it for illegal, harmful, or dangerous purposes. See [DISCLAIMER.md](./DISCLAIMER.md) before use.

Nexa is a holistic, decentralized framework for AI research, deployment, and autonomous agent orchestration. It provides a secure technical layer for hosting specialized personas with sovereignty and human-in-the-loop (HITL) coordination.

## Protocol Direction

Nexa should be read first as protocol infrastructure for human and AI collaboration under hostile conditions, not as a single app stack.

Canonical architecture docs:

- [Architecture](./docs/ARCHITECTURE.md)
- [Protocol](./docs/PROTOCOL.md)
- [Trust Model](./docs/TRUST_MODEL.md)
- [Threat Model](./docs/THREAT_MODEL.md)

Machine-readable specs:

- [specs/protocol.json](./specs/protocol.json)
- [specs/trust.json](./specs/trust.json)
- [specs/recovery.json](./specs/recovery.json)

Model defaults:

- [Model Policy](./docs/MODEL_POLICY.md)

## Community

- [Contributing](./CONTRIBUTING.md)
- [Code of Conduct](./CODE_OF_CONDUCT.md)
- [Security Policy](./SECURITY.md)
- [Support](./SUPPORT.md)
- [Governance](./GOVERNANCE.md)
- [Legacy Policy](./docs/LEGACY_POLICY.md)

---

## 🏛 The Ephemeral Hardware Manifesto

In the Nexa ecosystem, physical devices are treated as disposable. Whether a developer drops their phone in a river or it is confiscated at a border, the protocol dictates that a **brand new off-the-shelf device** must be capable of being **fully restored to a sovereign state within exactly ten minutes.**

This is achieved through:
- **Dotfile Sovereignty**: All environment configurations are version-controlled and portable.
- **Agentic Recovery**: Automated scripts to rebuild the entire stack (Web, Mobile, Runtime) from source truth.
- **Cloud-Edge Parity**: Seamless deployment between local hardware and remote VPS infrastructure.

---

## 🚀 Quick Start

**99% of tasks are automated** — safe, efficient, standardized. See **[docs/QUICKSTART.md](docs/QUICKSTART.md)** for the full path: **instant demo** (`nexa demo`) then **onboarding** (vault → deploy). One entry point: `nexa` CLI or `make` (e.g. `make deploy-mesh`, `make demo`, `make verify-release`). For **offline / local-mesh coding** (e.g. Z Fold with no WiFi or WiFi without internet, using org-wide distributed OSS inference), see **[docs/DISTRIBUTED_INFERENCE_VISION.md](docs/DISTRIBUTED_INFERENCE_VISION.md)**.

### 0 to Sovereignty (10 min)

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

### 3. Deploy the Nexa Mission Control Dashboard (3m)
```bash
cd apps/web
npm install && npm run build
```

### 4. Provision Fresh VPS (5m)
```bash
export VPS_IP=your-vps-ip
export VPS_DOMAIN=your-domain.example
./ops/bin/nexa deploy-mesh
```

---

## 🧩 Core System Components

| Component | Tech Stack | Role |
|-----------|------------|------|
| **[Nexa Dashboard](./apps/aura-dashboard)** | Next.js, React, TypeScript | Operator mission control and mesh telemetry |
| **[Nexa Landing](./apps/aura-landing-next)** | Next.js, next-intl | Public ingress, lead capture, telemetry intake |
| **[Nexa Gateway](./ops/gateway)** | FastAPI, Python | Vault-backed routing, session sync, HITL, Tor/IPFS transport |
| **[Core Runtime](./core)** | Zig, Python | Native services, mesh utilities, recovery primitives |
| **[Ops](./ops)** | Bash, systemd, nginx | Deployment, backup, restore, thin-stack automation |

---

## 🤖 Specialized Agent Personas

1.  **Career-Twin Agent**: Autonomous professional profile management, inquiry handling, and interview scheduling.
2.  **SDR Agent**: Automated B2B sales development, prospect research, and personalized outreach sequences.

## Model Baseline

- Shared OSS collaboration default: `Qwen3-Coder`
- Edge/mobile fallback: `Qwen2.5-Coder-7B-Instruct`
- Android phone runtime target: `MLC Engine + Vulkan`

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
│   ├── aura-dashboard/    # Mission Control dashboard
│   ├── aura-landing-next/ # Public landing and intake
│   └── web/               # Legacy web workspace / adjacent apps
├── core/
│   ├── cerberus/          # Agent/runtime engine
│   ├── aura-api/          # Native API service
│   └── vault/             # Portable operator state and recovery data
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

## Release Gate

Run the hermetic production verification gate before pushing or deploying:

```bash
make verify-release
```

That builds a clean Docker image, installs workspace dependencies inside it, then runs Python compile checks, shell syntax checks, frontend typechecks, lint, production builds, and a production dependency audit away from host-local `node_modules` drift.

---

## 📜 License

MIT License. See [LICENSE](./LICENSE) for details.
