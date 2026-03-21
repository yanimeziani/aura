# Nexa Monorepo

**⚠️ [Disclaimer and responsible use](./DISCLAIMER.md)** — This software is provided "as is." You may not use it for illegal, harmful, or dangerous purposes.

Nexa is a protocol-first monorepo for mesh operations, agent orchestration, and resilient deployment.

## Canonical RAG Memory

The `docs/` folder is intentionally strict and contains only canonical memory:

- [Layer-0 Seed](./docs/SEED.md)
- [Agent Protocol](./docs/AGENTS.md)
- [24h Forge Plan](./docs/FORGE_24H_PLAN.md)
- [World Model (Mermaid)](./docs/MESH_WORLD_MODEL.md)
- [Architecture Distill](./docs/ARCHITECTURE_DISTILL.md)
- [RAG Corpus Manifest](./docs/RAG_CORPUS_MANIFEST.md)
- [License Memory](./LICENSE.md)

## Root Governance Anchors

- [PRD](./PRD.md)
- [Security](./SECURITY.md)
- [Legal](./LEGAL.md)
- [Stack](./STACK.md)
- [Tasks](./TASKS.md)
- [Marketing](./MARKETING.md)
- [ICP](./ICP.md)

## Repository Shape

```text
/
├── apps/      # Product surfaces
├── core/      # Runtime and protocol implementation
├── ops/       # Deployment and operations automation
├── specs/     # Machine-readable contracts
├── tools/     # Utility scripts
├── vault/     # Operational state and generated artifacts
└── docs/      # Canonical RAG memory only
```

## Release Gate

```bash
make verify-release
```
