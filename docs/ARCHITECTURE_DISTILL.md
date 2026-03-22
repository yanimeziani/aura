# ARCHITECTURE_DISTILL.md

Status: Distilled architecture memory for the canonical minimal docs corpus.

## 1) Source Inputs

This distill is derived from:
- current repository structure (`apps`, `core`, `ops`, `tools`, `specs`, `vault`)
- canonical memory files in `docs/`
- root policy/product anchors (`PRD.md`, `SECURITY.md`, `LEGAL.md`)

## 2) Distilled Architecture Model

Nexa currently remains compatible with a six-layer protocol model:
1. identity and trust
2. transport and routing
3. state and recovery
4. execution and coordination
5. applied sovereignty domains
6. operator interfaces

This maps cleanly onto the canonical memory framework:
- strategic memory and planning in `docs/SEED.md` and `docs/FORGE_24H_PLAN.md`
- agent rules in `docs/AGENTS.md`
- world and governance mapping in `docs/MESH_WORLD_MODEL.md`
- machine contracts in `specs/*.json`

## 3) Compatibility Checks

### Architecture to RAG compatibility

- protocol-first orientation is preserved
- trust and HITL constraints remain explicit
- recovery and continuity requirements remain first-order constraints
- multi-provider execution is now normalized via versioned forge packets

### Potential mismatch zones

- legacy narrative docs with stale branding or one-off project framing
- duplicate architecture visual files not aligned with current world model
- large export artifacts that are not maintainable as canonical memory

## 4) Daily Distill (2026-03-21)

The architecture has been unified under the **Aura Mesh Protocol**:
- **Consolidation**: Root and `docs/` anchors have been prioritized for all RAG retrieval.
- **Protocol Adoption**: BMAD v6 (Analysis-Plan-Solution-Implementation) is now the required agent workflow.
- **Loop Breaking**: The Ralph Wiggum Safeguard is enforced to prevent stagnant or infinite markdown generation.
- **Mesh GUI north star**: Full-fleet **Kotlin multiplatform portal** is the canonical end-state GUI for all mesh device classes; until it ships, CLI/web/Pegasus-style surfaces are interim and must not fork trust or policy semantics (`docs/MESH_WORLD_MODEL.md` §2).
- **Zig OCI distill**: Path for **distilled Zig artifacts** uses a **single OCI engine** in automation (see `ops/verify/Containerfile.zig-distill`, `make zig-docker-distill` / `ops/scripts/zig-docker-distill.sh`). `make verify-release` builds a verification image the same way. Mesh transport should assume **full-cone NAT** where direct UDP hole punching matters; document **listen-space (l-space)** per node in `docs/NETWORKING_INGRESS_EGRESS.md`.
- **Lightness**: Memory plane is strictly limited to canonical anchors defined in `docs/RAG_CORPUS_MANIFEST.md`.
- **Identity**: SSH (ED25519) for git forge access and hardware-partitioned key material for tripartite trust (see `specs/trust.json`, vault attestations).
- **Stack Lockdown**: Hard interdiction on external deps. Stack locked to **Zig 0.13.0, TypeScript 5.5.4, and Node.js 22 LTS**.
- **Invariant: Replicability**: Codified the absolute rule that no work is performed in non-replicable environments. Workspace state is synchronized to `MezianiAI/.dotfiles`.
- **Supply Chain Purge**: Permanently removed all Node.js/Next.js apps and Python services with external pip dependencies to enforce a zero-CVE, sovereign technical baseline.

## 5) Canonical Decision

Canonical architecture memory now uses:
- `docs/MESH_WORLD_MODEL.md` for exhaustive system map
- `docs/ARCHITECTURE_DISTILL.md` for compatibility distillation

Non-canonical duplicates should be removed or archived outside the canonical docs set.
