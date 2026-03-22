# Changelog

All notable changes to this repository are documented in this file.

## [1.1.0] — 2026-03-22

### Added

- Canonical docs: media/news/translation contract, UX distill (Laws of UX + Frontend Cloud patterns), expanded RAG manifest entries.
- `tools/media/` package (audit, forge, paths) with CLI shims; tests under `tools/tests/`.
- Cerberus **translation** agent config and prompt; media agent roster updates.
- `core/google-mcp` as a **git submodule** ([google_workspace_mcp](https://github.com/taylorwilsdon/google_workspace_mcp)); see `.gitmodules` and `git submodule update --init --recursive`.
- Architecture task scaffold in `TASKS.md` (specs → runtime → portal).

### Changed

- `docs/MESH_WORLD_MODEL.md`: Kotlin mesh portal as GUI north star; interim surfaces explicit.
- `PRD.md`, `docs/ARCHITECTURE_DISTILL.md`, governance and marketing anchors aligned with current mission.
- Nexa CLI: restored `deploy-mesh` handler; removed duplicate `smoke-test` definition (smoke-test → `smoke-test-mesh.sh`).

### Repository hygiene

- `.gitignore`: local `vault/leads.db`, `vault/media_staging/`, scratch `test_list.zig`.

[1.1.0]: https://github.com/mezianiai/nexa/releases/tag/v1.1.0
