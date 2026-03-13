# Community packages and gradual privatisation

We **keep support for community packages** and **slowly privatise** our own versions of everything we need, using best practices and our architecture.

## Principles

1. **No external deps for Zig stack.** For the Aura sovereign stack (aura-edge, aura-tailscale, aura-mcp, ziggy-compiler, tui): **no external dependencies** except the Zig language and its standard library (core libs). No C libs, no zig packages from outside the repo. This is a hard rule for new Zig work.

2. **Community stays supported (non-Zig).** For non-Zig components (frontend, Python backend, etc.), use npm, pip, and other ecosystem packages where they fit. No big-bang removal. The Zig stack is dependency-free; the rest can use community packages until we privatise.

3. **Gradual privatisation.** Over time, we replace selected dependencies with **our own in-repo implementations** when that serves sovereignty, control, or architecture. We do not fork the ecosystem; we reimplement surfaces and behaviour in our repo (Zig, Python, or our stack) and follow our conventions (vault, registry, one Zig version, safe ops, escalation).

4. **Best practices and our architecture.** Every private replacement must:
   - Live in our repo (e.g. `aura-mcp/`, `ziggy-compiler/`, `aura-tailscale/`).
   - Follow our layout: docs in `docs/`, config/state in `vault/`, build with our locked Zig where applicable (see `docs/ZIG_VERSION.md`).
   - Match or improve on the surface we replace (API, behaviour, or protocol) so migration is predictable.
   - Be documented as the canonical implementation in our registry or docs (e.g. `vault/mcp_registry.json`, `docs/sovereign-mcp.md`).

5. **No forced cutover.** We do not remove a community package until our private version is ready and we choose to switch. Both can coexist during the transition (e.g. optional use of our MCP server vs a community one).

## What “privatise” means here

- **Private** = our own implementation, in this repo, under our architecture.
- **Privatise** = introduce and then adopt our implementation for a capability that today is fulfilled by a community package (or will be).
- We do **not** mean “close source” or “remove all external deps.” We mean “own the implementation” for the capabilities we care about, while still allowing community packages elsewhere.

## How we prioritise what to privatise

- **Critical path / sovereignty:** Mesh (Tailscale-like), edge, MCP tools, crypto, auth — we prefer our own implementations so we own the lifecycle.
- **Protocol or API we rely on:** Reimplement the surface (e.g. MCP tools, WireGuard constants) in our stack so we are not tied to a third-party runtime.
- **Tooling we build on:** Compiler (Ziggy), test harness, docs maid — we own these in-repo.
- **Non-critical or one-off:** Community packages are fine (e.g. UI libs, parsers, drivers) until we have a reason to bring them in-house.

## How we do it (best practices)

1. **Decide the surface.** Define the API or behaviour we need (from the community package or spec).
2. **Implement in-repo.** Add a module or project (Zig/Python/our stack) that implements that surface. Follow `docs/AGENTS.md`, `docs/aura-zig-network-stack.md`, and `docs/ZIG_VERSION.md`.
3. **Register and document.** Point our internal registry or docs at our implementation (e.g. `vault/mcp_registry.json`, `docs/sovereign-mcp.md`). Document “community vs ours” in the relevant doc (e.g. “We use our own MCP server; community servers are reference only.”).
4. **Migrate when ready.** Switch call sites or config to use our implementation when it is ready and we choose to cut over. Keep the old dependency optional or remove it in the same change.
5. **No destructive rush.** We do not delete or break community usage until our replacement is in place and tested. Safe ops only (see `docs/AGENTS.md`).

## Current state (examples)

| Capability     | Community / today              | Our private version              | Status        |
|----------------|---------------------------------|----------------------------------|---------------|
| Mesh VPN       | Tailscale (external)           | `aura-tailscale/` (Zig)          | In progress   |
| MCP servers    | modelcontextprotocol/servers   | `aura-mcp/` (Zig), `mcp/server.py`| Adopted       |
| MCP registry   | N/A                             | `vault/mcp_registry.json`        | Internal only |
| Compiler       | zig (upstream)                  | `ziggy-compiler/` (Ziggy)        | In progress   |
| Edge / HTTP    | Caddy, Cloudflare               | `aura-edge/` (Zig)               | In progress   |
| Frontend       | React, Vite, npm                | —                                | Community     |
| Backend agents | CrewAI, LangChain, pip          | —                                | Community     |

We keep React, Vite, CrewAI, LangChain, and other community packages where they are. When we introduce a private alternative (e.g. a future Zig or in-repo agent runtime), we document it and migrate gradually.

## Where this is documented

- **Sovereign MCP:** `docs/sovereign-mcp.md` — our MCP servers and registry; community as reference only.
- **Zig stack and Ziggy:** `docs/aura-zig-network-stack.md`, `docs/ziggy-compiler.md`, `docs/ZIG_VERSION.md` — our Zig/Ziggy toolchain and lock policy.
- **Guidelines:** `docs/AGENTS.md` — principles, roster, safe ops, escalation, build commands.
- **This doc:** strategy for community support and gradual privatisation with best practices and our architecture.

Summary: **support community packages; slowly privatise with our own implementations, our architecture, and no forced cutover.**
