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
- [Unified access (a11y + neurodiversity + age-friendly)](./docs/UNIFIED_ACCESS.md)
- [Montessori-friendly frontend skills](./docs/MONTESSORI_FRONTEND_SKILLS.md)
- [License Memory](./LICENSE.md)

## Releases

- [CHANGELOG.md](./CHANGELOG.md) — version history and tagged milestones.
- **Submodules:** after clone, run `git submodule update --init --recursive` so `core/google-mcp` is populated.

## Root Governance Anchors

- [PRD](./PRD.md)
- [Security](./SECURITY.md)
- [Legal](./LEGAL.md)
- [Stack](./STACK.md)
- [Tasks](./TASKS.md)
- [Marketing](./MARKETING.md)
- [ICP](./ICP.md)

## Model Alignment

All AI interactions are grounded via the **Zig Framework Plugin** (`core/aura-mcp`):
- Forces context to align with the [RAG Manifest](./docs/RAG_CORPUS_MANIFEST.md)
- Zero-external-runtime MCP server for high-fidelity grounding
- Standardizes protocol adherence across Gemini, Claude, and Codex

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

Business-side work (commercial narrative, campaign assets tied to Death to Stock projects, non-runtime business code) lives in the **Sovar** GitHub repo, not in this tree. See [MARKETING.md](./MARKETING.md).

## Release Gate

```bash
make verify-release
```
