# Aura MCP — Implement Our Own Server

We run **our own** MCP servers in **our own repo**. This directory holds the Python MCP (Aura mesh, registry); the Zig MCP server (filesystem, etc.) lives in **`aura-mcp/`**.

## Example: implement our own server

**Protocol reference (we implement; we do not depend on these at runtime):**

- [Model Context Protocol — specification](https://github.com/modelcontextprotocol/specification) (transport, JSON-RPC, `initialize`, `tools/list`, `tools/call`).
- [modelcontextprotocol/servers](https://github.com/modelcontextprotocol/servers) — example servers (filesystem, git, fetch, etc.). Use only as **reference** for behaviour; **we implement our own** in this repo.

**Our implementations:** (Zig = **0.15.2** only; see `docs/ZIG_VERSION.md`, `.zig-version`)

| What        | Where in this repo   | How to run                    |
|------------|----------------------|-------------------------------|
| Zig MCP    | `aura-mcp/`          | `cd aura-mcp && zig build && ./zig-out/bin/aura-mcp` |
| Python MCP | `mcp/server.py`      | `python mcp/server.py` (stdio) |

- **Zig server** (`aura-mcp/`): our own implementation of MCP over stdio; tools: `read_file`, `list_dir`. Add more tools (git, fetch, etc.) there — see `docs/sovereign-mcp.md`.
- **Python server** (`mcp/server.py`): Aura-specific tools (mesh, status, internal registry). Requires `pip install mcp`.

## For all capabilities

Every capability in our internal toolbelt is (or will be) implemented in **our own repo**:

- Filesystem → `aura-mcp/` (Zig)
- Git, fetch, postgres, memory, etc. → extend `aura-mcp/` or add modules in this repo; see `vault/mcp_registry.json` and `docs/sovereign-mcp.md`.

No external MCP server packages required for sovereign use; etc. for all.
