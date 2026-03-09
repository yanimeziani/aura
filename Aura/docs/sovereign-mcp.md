# Sovereign MCP: Our Own Servers, Our Own Repo

We implement **our own** MCP servers in **our own repo** (Aura). Zig code uses **Zig 0.15.2** (see `docs/ZIG_VERSION.md`, `.zig-version`). No dependency on external MCP packages for core capabilities. Same idea as [Vinext](https://blog.cloudflare.com/vinext/): reimplement the surface (MCP protocol + tools) ourselves; code, test, repeat in Zig (or internal stack only).

## Protocol reference (for implementing our own server)

- **MCP specification:** [modelcontextprotocol/specification](https://github.com/modelcontextprotocol/specification) — transport (stdio/newline-delimited JSON), JSON-RPC methods (`initialize`, `tools/list`, `tools/call`).
- **Example public servers (for behaviour reference only; we do not use them at runtime):** [modelcontextprotocol/servers](https://github.com/modelcontextprotocol/servers) — e.g. filesystem, git, fetch. We use these only as protocol/tool-shape examples; **we implement our own** in this repo.

## Our repo: capability → implementation

| Capability        | Our server (this repo)        | Status   |
|-------------------|------------------------------|----------|
| Filesystem        | `aura-mcp/` (Zig)            | Done     |
| Git               | `aura-mcp/` (Zig, extend)    | Planned  |
| Fetch             | `aura-mcp/` (Zig, extend)    | Planned  |
| Postgres          | `aura-mcp/` or dedicated Zig | Planned  |
| Supabase          | Internal gateway / Zig       | Planned  |
| Sentry            | Internal gateway / Zig       | Planned  |
| Memory            | `aura-mcp/` or vault-backed  | Planned  |
| Sequential think  | `aura-mcp/` (Zig)            | Planned  |
| Puppeteer         | Isolated Zig/runner          | Planned  |
| Aura (mesh, etc.) | `mcp/server.py`              | Done     |

**All** of the above are (or will be) implemented in **our own repo**; no external MCP server runtimes required for sovereign use.

## Where to implement

- **Zig MCP server (stdio, tools):** `aura-mcp/` — single binary `aura-mcp`; add tools here (read_file, list_dir already; add git, fetch, etc.).
- **Python MCP (Aura CLI/mesh, registry):** `mcp/server.py` — mesh_status, aura_status, get_internal_mcp_registry.
- **Registry (no external links):** `vault/mcp_registry.json` — lists capabilities and points to our implementations only.

## How to add a new “our own” server / tool

1. **New tool on existing server:** Add a handler in `aura-mcp/src/main.zig` (e.g. `git_status`, `fetch_url`), register in `handleToolsList`, implement in `handleToolsCall`. Run `zig build` in `aura-mcp/`.
2. **New dedicated server (if needed):** Create e.g. `aura-mcp-git/` or extend `aura-mcp/` with another Zig module; same stdio JSON-RPC loop. Document in this table and in `vault/mcp_registry.json` under the capability’s `implementation` field.
3. **Protocol compliance:** Follow [MCP specification](https://github.com/modelcontextprotocol/specification) (initialize, tools/list, tools/call); use [modelcontextprotocol/servers](https://github.com/modelcontextprotocol/servers) only as an example for request/response shape — **implement in our repo**, do not depend on those packages.

## Example: implement our own server (minimal)

See `mcp/README.md` for a minimal “implement our own server” example. The canonical implementation in this repo is `aura-mcp/` (Zig):

```bash
cd aura-mcp && zig build
./zig-out/bin/aura-mcp   # stdio; speaks MCP JSON-RPC
```

Tools currently implemented in our own server: `read_file`, `list_dir` (both scoped to AURA_ROOT), and `ping` (liveness; returns `pong`).

## AURA_ROOT and venv-style root

`AURA_ROOT` is the single root directory under which MCP tools (e.g. `read_file`, `list_dir`) are allowed to operate. Paths are resolved and checked so the process cannot escape this root.

**Good example of a venv root:** **rootless proot**. Use a rootless proot environment as `AURA_ROOT` to get a confined, virtualized root without real root: same idea as a Python venv (isolated environment), but for the filesystem and process view. Set `AURA_ROOT` to the proot guest root (e.g. the directory you `proot -S .` into); then the MCP server and tools only see and touch that tree. No external packages required; proot is widely available and safe for this use.
