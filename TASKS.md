# TASKS.md

Status legend: `todo` | `in_progress` | `blocked` | `done`

## Active Workboard

| ID | Task | Status | Owner | Links |
|----|------|--------|-------|-------|
| NX-001 | Formalize neurodiverse-friendly architecture memory | done | agents | `docs/UNIFIED_ACCESS.md`, `docs/SEED.md`, `docs/AGENTS.md` |
| NX-002 | Implement Layer-0 RAG retrieval anchors and workflow rules | in_progress | agents | `docs/SEED.md`, `docs/AGENTS.md` |
| NX-003 | Keep canonical RAG corpus strict and current | in_progress | docs/research | `docs/RAG_CORPUS_MANIFEST.md` |
| NX-004 | Align PRD, stack, and architecture docs after major edits | todo | architects | `PRD.md`, `docs/SEED.md` |
| NX-005 | Validate release and verify-release gate | todo | release | `README.md`, `Makefile` |
| NX-006 | Maintain canonical business/context docs | in_progress | strategy | `STACK.md`, `MARKETING.md`, `ICP.md`, `LEGAL.md` |
| NX-007 | Evolve architecture distill and world model | in_progress | architects | `docs/ARCHITECTURE_DISTILL.md`, `docs/MESH_WORLD_MODEL.md`, `docs/SEED.md` |
| NX-008 | Launch multi-client Digital Studio outreach (SDR) | in_progress | growth | `tools/lead_manager.py`, `tools/import_leads.py`, `apps/ai_agency_wealth/resend_handler.py` |
| NX-009 | Establish Bunkerised External MCP Bridge (n8n/HubSpot/LinkedIn/Cal.com) | done | devsecops | `vault/vault_manager.py`, `tools/mcp_n8n_bridge.py`, `core/cerberus/deploy/meziani-dragun/config.roster.json` |
| NX-010 | Operationalize compliant Media Gen AI Forge | done | growth | `docs/MEZIANI_AI_AUDIT_MEDIA_GEN_AI_FORGE.md`, `tools/media_audit_filter.py` |
| NX-011 | Zero-Friction Cinematic & Arts Pipeline | in_progress | growth | `tools/cinematic_forge.py`, `docs/MEZIANI_AI_AUDIT_MEDIA_GEN_AI_FORGE.md` |
| NX-012 | Link Digital Metaverse Identity (Google Workspace) | done | identity | `tools/mcp_google_link.py`, `docs/GOOGLE_IDENTITY.md` |

## Trigger Checklist (Per Significant Edit)

- [ ] If architecture changed, update `docs/SEED.md` ASCII + Mermaid maps
- [ ] If retrieval topology changed, update `docs/RAG_CORPUS_MANIFEST.md` and `docs/SEED.md`
- [ ] If product scope changed, update `PRD.md` and `docs/SEED.md`
- [ ] If stack changed, update `STACK.md` and stack baseline in `docs/SEED.md`
- [ ] If messaging changed, update `MARKETING.md` and `docs/SEED.md`
- [ ] If operator or public UX/copy standards changed, update `docs/UNIFIED_ACCESS.md` and verify `docs/RAG_CORPUS_MANIFEST.md`
- [ ] If calm-workflow or Montessori-aligned UI patterns changed, update `docs/MONTESSORI_FRONTEND_SKILLS.md` and cross-check `docs/UNIFIED_ACCESS.md`
- [ ] If brand identity changed, update `media/logos/` and visual assets
- [ ] If stock-photo workflow or Sovar repo boundary changed, update `MARKETING.md` and `README.md` (related-work note)
- [ ] If collaborator profile changed, update `ICP.md` and `docs/SEED.md`
- [ ] If security policy changed, update `SECURITY.md` and `docs/SEED.md`
- [ ] If legal terms changed, update `LICENSE`, `LEGAL.md`, and `docs/SEED.md`
- [ ] If a Québec public enterprise NEQ or legal name was verified at REQ, update `specs/quebec_req_public_identity.json` and cross-check `specs/grid_vital_lock.json`
- [ ] If canonical docs boundaries changed, update `docs/RAG_CORPUS_MANIFEST.md`

## Architecture coverage scaffold (full Nexa stack)

Cross-cutting backlog to close the loop from **machine specs** → **runtime** → **operator UI**. Status starts at `todo`; adjust as slices land.

### Layer 0 — Memory, RAG, governance

| ID | Task | Status | Owner | Links |
|----|------|--------|-------|-------|
| NX-013 | Close NX-002/NX-003: Layer-0 retrieval checks in CI or scripted audit | todo | agents | `docs/AGENTS.md`, `docs/RAG_CORPUS_MANIFEST.md` |
| NX-014 | Keep `docs/SEED.md` ASCII map in sync with `ARCHITECTURE.md` Mermaid | todo | architects | `docs/SEED.md`, `ARCHITECTURE.md` |

### JSON specs (`specs/`)

| ID | Task | Status | Owner | Links |
|----|------|--------|-------|-------|
| NX-015 | `protocol.json`: document every field; align gateway + Cerberus transports | todo | protocol | `specs/protocol.json`, `core/nexa-gateway/` |
| NX-016 | `trust.json`: map to vault + pairing flows; acceptance tests | todo | security | `specs/trust.json`, `vault/` |
| NX-017 | `recovery.json`: runbooks linked from ops scripts | todo | devsecops | `specs/recovery.json`, `ops/scripts/` |
| NX-018 | `grid_vital_lock.json`: trace to vitals UI and org registry | todo | ops | `specs/grid_vital_lock.json`, `vault/static/` |
| NX-019 | `quebec_req_public_identity.json`: REQ sync process + trigger checklist | todo | legal/ops | `specs/quebec_req_public_identity.json`, `TASKS.md` |

### Cerberus specs (`core/cerberus/specs/`)

| ID | Task | Status | Owner | Links |
|----|------|--------|-------|-------|
| NX-020 | 001 platform charter → runtime boundaries accepted | todo | cerberus | `core/cerberus/specs/001-platform-charter.md` |
| NX-021 | 002 agent contract → tool + policy matrix | todo | cerberus | `core/cerberus/specs/002-agent-contract.md` |
| NX-022 | 003 VPS cutover → deploy-mesh + smoke-test evidence | todo | devsecops | `core/cerberus/specs/003-vps-cutover.md`, `ops/scripts/deploy-mesh.sh` |
| NX-023 | 004 nullclaw refactor / rebrand parity | todo | cerberus | `core/cerberus/specs/004-nullclaw-refactor-rebrand.md` |
| NX-024 | 005 meziani-dragun roster deploy reproducible | todo | devsecops | `core/cerberus/specs/005-meziani-dragun-roster-deploy.md` |
| NX-025 | 006 Pegasus mission control UX ↔ Kotlin portal contract | todo | product | `core/cerberus/specs/006-pegasus-mission-control-ux.md`, `docs/MESH_WORLD_MODEL.md` |
| NX-026 | SDR + career twin specs → agent configs tested | todo | growth | `core/cerberus/specs/sdr-agent.md`, `career-digital-twin.md` |

### Core runtime

| ID | Task | Status | Owner | Links |
|----|------|--------|-------|-------|
| NX-027 | `nexa-gateway`: health API, systemd, port config documented | todo | runtime | `core/nexa-gateway/`, `ops/config/nexa-gateway.service` |
| NX-028 | `aura-api` + electro-spatial: public API surface + tests | todo | runtime | `core/aura-api/` |
| NX-029 | `aura-mcp`: `get_canonical_framework` parity with manifest | todo | agents | `core/aura-mcp/`, `docs/RAG_CORPUS_MANIFEST.md` |
| NX-030 | `cerberus-core`: agent loop + configs (media, translation) integration-tested | todo | cerberus | `core/cerberus/runtime/cerberus-core/`, `core/cerberus/configs/` |

### Integrations & bridges

| ID | Task | Status | Owner | Links |
|----|------|--------|-------|-------|
| NX-031 | `google-mcp`: install/run docs + least-privilege scope review | todo | identity | `core/google-mcp/`, `docs/GOOGLE_IDENTITY.md` |
| NX-032 | Bunker / n8n / external MCP bridges: secrets + rotation | todo | devsecops | `tools/mcp_n8n_bridge.py`, `tools/bunker_bridge.py` |

### Operator surfaces

| ID | Task | Status | Owner | Links |
|----|------|--------|-------|-------|
| NX-033 | `tools/nexa.py` CLI: command matrix documented in README | todo | ops | `tools/nexa.py`, `README.md` |
| NX-034 | Apps (`ai_agency_wealth`, wargame, nexa-lite): boundaries + SPEC alignment | todo | apps | `apps/` |
| NX-035 | **Kotlin multiplatform mesh portal** (north star): repo scaffold + API contract | todo | product | `docs/MESH_WORLD_MODEL.md` §2, `PRD.md` |

### Media / forge

| ID | Task | Status | Owner | Links |
|----|------|--------|-------|-------|
| NX-036 | Media package: pytest in CI; forge steps behind feature flags | todo | growth | `tools/media/`, `tools/tests/` |
| NX-037 | Translation agent: handoff schema (core hash → locales) | todo | growth | `docs/CANONICAL_MEDIA_NEWS_AND_TRANSLATION.md` |

### UX & docs pipeline

| ID | Task | Status | Owner | Links |
|----|------|--------|-------|-------|
| NX-038 | Apply Laws-of-UX / Frontend-Cloud distill to portal + vitals reviews | todo | design | `docs/UX_DISTILL_LAWS_OF_UX_AND_FRONTEND_CLOUD.md` |
| NX-039 | NotebookLM / docs bundle: automated build in release gate | todo | docs | `ops/scripts/build-aura-docs-bundle.py`, `Makefile` |

## Open Decisions

- Preferred implementation path for deeper Layer-0 RAG indexing (`specs` first vs full-repo indexing)
- Granularity for per-subsystem Mermaid charts in addition to global system map
