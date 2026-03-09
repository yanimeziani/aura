---
name: aura-mcp-builder
description: Build MCP tools that fit Aura: internal-only, AURA_ROOT confinement, no external install links.
---

## Objective

Add new MCP capabilities in-repo (Zig or Python) without breaking Aura’s “sovereign + safe” model.

## What “good” looks like in Aura

- **In-repo implementation** (no external “pip install this MCP server” links in the registry).
- **Confinement**: file tools must respect **AURA_ROOT**; never allow path traversal outside.
- **Stable tool surface**: small, composable tools (read/list/status/run/build), not huge monoliths.
- **Auditable**: deterministic inputs/outputs; logs to `vault/` when useful.

## Where to hook it

- **Python MCP**: `mcp/server.py` (Aura tools like `mesh_status`, `aura_status`, registry export).
- **Zig MCP**: `aura-mcp/` (stdio JSON-RPC tools like `read_file`, `list_dir`, `ping`).
- **Registry**: `vault/mcp_registry.json` (internal registry; no external links).

## Recipe

1. Define the tool contract (name, args, return shape).
2. Implement server-side logic.
3. Add tests (or at least a deterministic smoke command).
4. Update docs (`docs/sovereign-mcp.md`) and, if relevant, the registry.
