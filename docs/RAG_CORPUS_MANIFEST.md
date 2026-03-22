# RAG_CORPUS_MANIFEST.md

Status: Rigid canonical manifest for all `docs/` memory artifacts.

## 1) Purpose

This file binds the entire `docs/` folder into the canonical RAG framework.

Hard rule:
- only files listed in this manifest are allowed in `docs/`
- no silent additions
- retrieval and planning must consult this manifest first

## 2) Canonical Docs Set

These are the only in-bounds markdown files in `docs/`:

- `docs/SEED.md`
- `docs/AGENTS.md`
- `docs/FORGE_24H_PLAN.md`
- `docs/MESH_WORLD_MODEL.md`
- `docs/GOVERNANCE_MODEL.md`
- `docs/RAG_CORPUS_MANIFEST.md`
- `docs/ARCHITECTURE_DISTILL.md`
- `docs/MEZIANI_AI_AUDIT_MEDIA_GEN_AI_FORGE.md`
- `docs/UNIFIED_ACCESS.md`
- `docs/MONTESSORI_FRONTEND_SKILLS.md`
- `docs/CANONICAL_MEDIA_NEWS_AND_TRANSLATION.md`
- `docs/UX_DISTILL_LAWS_OF_UX_AND_FRONTEND_CLOUD.md`

## 3) Retrieval Contract

For every non-trivial task:
1. load `docs/SEED.md`, `docs/AGENTS.md`, and `docs/RAG_CORPUS_MANIFEST.md`
2. load `docs/FORGE_24H_PLAN.md` for execution cadence
3. load `docs/MESH_WORLD_MODEL.md` and `docs/ARCHITECTURE_DISTILL.md` for architecture context
4. for any user-facing UI, copy, or onboarding, load `docs/UNIFIED_ACCESS.md` and apply its checklist; for calm, self-directed, or instruction-adjacent flows, also load `docs/MONTESSORI_FRONTEND_SKILLS.md`
5. for studio, news, radio, or cross-language distribution, load `docs/CANONICAL_MEDIA_NEWS_AND_TRANSLATION.md` and treat it as the linguistic and quantitative contract (core language first, translation second)
6. for UX, layout, performance-perception tradeoffs, or frontend architecture patterns, load `docs/UX_DISTILL_LAWS_OF_UX_AND_FRONTEND_CLOUD.md` (Laws of UX + Frontend Cloud distill)
7. cite consulted paths in plan/output
8. write back changes to canonical docs only

## 4) Drift Control

When a new markdown file is proposed under `docs/`:
- reject by default
- only allow with explicit architectural justification
- add it to this manifest in the same change

If this manifest is stale, the RAG framework is considered out of compliance.

## 5) Root Markdown Boundary

To keep the repository root architecturally clean, only these root markdown files are in-bounds:
- `README.md`
- `PRD.md`
- `TASKS.md`
- `STACK.md`
- `MARKETING.md`
- `ICP.md`
- `LEGAL.md`
- `SECURITY.md`
- `GOVERNANCE.md`
- `PHILOSOPHY.md`
- `CONTRIBUTING.md`
- `CODE_OF_CONDUCT.md`
- `SUPPORT.md`
- `DISCLAIMER.md`
- `COLLABORATORS.md`
- `ULAVAL_ONBOARDING_SUMMARY.md`
- `LICENSE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`

Any other root `.md` file is out-of-bounds and should be purged or relocated.

## 6) Visual Asset Boundary

The following directories are reserved for non-markdown brand and media assets:
- `media/logos/*`: Official brand identity images
- `ops/media/*`: Technical outreach and distribution materials (markdown)
