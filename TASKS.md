# TASKS.md

Status legend: `todo` | `in_progress` | `blocked` | `done`

## Active Workboard

| ID | Task | Status | Owner | Links |
|----|------|--------|-------|-------|
| NX-001 | Formalize neurodiverse-friendly architecture memory | in_progress | agents | `docs/SEED.md`, `docs/AGENTS.md` |
| NX-002 | Implement Layer-0 RAG retrieval anchors and workflow rules | in_progress | agents | `docs/SEED.md`, `docs/AGENTS.md` |
| NX-003 | Keep canonical RAG corpus strict and current | in_progress | docs/research | `docs/RAG_CORPUS_MANIFEST.md` |
| NX-004 | Align PRD, stack, and architecture docs after major edits | todo | architects | `PRD.md`, `docs/SEED.md` |
| NX-005 | Validate release and verify-release gate | todo | release | `README.md`, `Makefile` |
| NX-006 | Maintain canonical business/context docs | in_progress | strategy | `STACK.md`, `MARKETING.md`, `ICP.md`, `LEGAL.md` |
| NX-007 | Evolve architecture distill and world model | in_progress | architects | `docs/ARCHITECTURE_DISTILL.md`, `docs/MESH_WORLD_MODEL.md`, `docs/SEED.md` |

## Trigger Checklist (Per Significant Edit)

- [ ] If architecture changed, update `docs/SEED.md` ASCII + Mermaid maps
- [ ] If retrieval topology changed, update `docs/RAG_CORPUS_MANIFEST.md` and `docs/SEED.md`
- [ ] If product scope changed, update `PRD.md` and `docs/SEED.md`
- [ ] If stack changed, update `STACK.md` and stack baseline in `docs/SEED.md`
- [ ] If messaging changed, update `MARKETING.md` and `docs/SEED.md`
- [ ] If collaborator profile changed, update `ICP.md` and `docs/SEED.md`
- [ ] If security policy changed, update `SECURITY.md` and `docs/SEED.md`
- [ ] If legal terms changed, update `LICENSE`, `LEGAL.md`, and `docs/SEED.md`
- [ ] If canonical docs boundaries changed, update `docs/RAG_CORPUS_MANIFEST.md`

## Open Decisions

- Preferred implementation path for deeper Layer-0 RAG indexing (`specs` first vs full-repo indexing)
- Granularity for per-subsystem Mermaid charts in addition to global system map
