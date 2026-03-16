# Nexa Monorepo

**⚠️ [Disclaimer and responsible use](./DISCLAIMER.md)** — This software is provided "as is." You may not use it for illegal, harmful, or dangerous purposes. See [DISCLAIMER.md](./DISCLAIMER.md) before use.

Nexa is a monorepo for mesh-oriented deployment, operator tooling, agent runtime components, and supporting infrastructure. It includes HTTP services, web interfaces, deployment scripts, and protocol documentation.

The repository root is intentionally kept thin: primary entrypoints live here, while implementation utilities are grouped under `tools/` and longer-form references or reports live under `docs/`.

## Protocol Direction

Nexa should be read first as protocol and infrastructure documentation, not as a single application.

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

## Recovery Model

The repository is organized around reproducible setup and recovery:
- versioned environment and deployment configuration
- scripted service provisioning
- consistent local and VPS deployment paths

---

## 🚀 Quick Start

See **[docs/QUICKSTART.md](docs/QUICKSTART.md)** for the standard local and VPS setup path. Primary entry points are the `nexa` CLI and `make` targets such as `make deploy-mesh`, `make demo`, and `make verify-release`. For offline or local-mesh development, see **[docs/DISTRIBUTED_INFERENCE_VISION.md](docs/DISTRIBUTED_INFERENCE_VISION.md)**.
For the fully manual VPS + phone persistence path, see **[docs/MANUAL_DEPLOY_TO_VPS_AND_PHONE_MESH.md](docs/MANUAL_DEPLOY_TO_VPS_AND_PHONE_MESH.md)**.

### Basic Setup

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

### 3. Build the Nexa Web Interface (3m)
```bash
cd apps/web
npm ci --workspace apps/web && npm run build --workspace apps/web
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
| **[Nexa Operator UI](./apps/aura-dashboard)** | Next.js, React, TypeScript | Operator interface and mesh telemetry |
| **[Nexa Static Site](./apps/aura-landing-next)** | Next.js, next-intl | Static HTTP entrypoint and data intake |
| **[Nexa Gateway](./ops/gateway)** | FastAPI, Python | Vault-backed routing, session sync, HITL, Tor/IPFS transport |
| **[Core Runtime](./core)** | Zig, Python | Native services, mesh utilities, recovery primitives |
| **[Ops](./ops)** | Bash, systemd, nginx | Deployment, backup, restore, thin-stack automation |

---

## Agent Workloads

1.  **Career-Twin Agent**: Autonomous professional profile management, inquiry handling, and interview scheduling.
2.  **SDR Agent**: Automated B2B sales development, prospect research, and personalized outreach sequences.

## Model Baseline

- Shared OSS collaboration default: `Qwen3-Coder`
- Edge/mobile fallback: `Qwen2.5-Coder-7B-Instruct`
- Android phone runtime target: `MLC Engine + Vulkan`

---

## Operating Assumptions

- deployment and recovery should be scriptable
- mobile and remote clients should reconnect without becoming the source of truth
- network boundaries should be treated as untrusted by default

---

## 📂 Repository Map

```text
/
├── apps/
│   ├── aura-dashboard/    # Operator UI
│   ├── aura-landing-next/ # Static site
│   └── web/               # Next.js web workspace
├── core/
│   ├── cerberus/          # Agent/runtime engine
│   ├── aura-api/          # Native API service
│   └── vault/             # Portable operator state and recovery data
├── ops/            # 10-Minute Deployment & Recovery Scripts
├── docs/           # Technical Specs & Architecture Truth
├── tools/          # Secondary CLIs, local utilities, and export helpers
└── research/       # Research notes and source files
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
