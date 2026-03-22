# Zig version lock (Nexa first-party)

**Pinned compiler:** **0.13.0** (exact). Verify with `zig version`.

**Scope (first-party, no package deps):**

- `core/nexa-gateway/`
- `core/nexa-lb/`
- `core/aura-mcp/`

Each of the above must:

- declare `.minimum_zig_version = "0.13.0"` in `build.zig.zon`;
- keep `.dependencies = .{}` (no `zig fetch` / no external Zig packages—**std only**).

**Out of scope for this pin:** vendored third-party trees (e.g. `core/cerberus/runtime/cerberus-core`) remain on their upstream toolchain until explicitly ported.

Repository markers: `.zig-version` at repo root; `STACK.md`; `docs/AGENTS.md`.
