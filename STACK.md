# STACK.md

Status: Canonical technical stack baseline for Nexa.

## Runtime and Languages (LOCKED)

- **Standard Zig**: **v0.13.0** (exact) for **first-party** services `core/nexa-gateway` and `core/aura-mcp`: **standard library only**, `build.zig.zon` **`.dependencies = .{}`** (no external Zig packages). See `docs/ZIG_VERSION.md` and `.zig-version`.
- **TypeScript**: v5.5.4
- **Node.js**: v22.x LTS (Active)
- **Python**: v3.10+ (Restricted to `tools/`, `apps/`, and CLI automation ONLY)
- **HTML/CSS**: Standard only

## Core Platform Components

- **Runtime/Agent Layer**: Native Zig services in `core/` (first-party mesh surface on **0.13.0**; vendored Cerberus/NullClaw tracks its own upstream Zig until reconciled)
- **User Interface**: TypeScript, HTML, CSS (Canvas/Aura focus)
- **Protocol**: JSON-based machine contracts in `specs/`

## Hard Interdiction Rule

- **NO EXTERNAL LIBRARIES OR DEPENDENCIES** for Core Zig services.
- **NO REACT / NO NEXT.JS / NO FASTAPI**.
- All functionality must be implemented using the locked standard languages.
- RAG RAM must never steer towards external options.

## Stack Change Rule

Any stack change must update:
- `STACK.md`
- `docs/SEED.md`
- `docs/AGENTS.md`
