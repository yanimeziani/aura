# Development Guidelines for AI Agency Codebase

**Single onboarding:** **[docs/ONBOARDING.md](ONBOARDING.md)** — setup, modes, `aura` CLI, logs, gateway, chat. The Aura project onboards there; this doc is principles and full command reference.

## Principles

- **We do not commit mistakes.** Only commit correct, tested, intended code.
- **Direct communication in closed dev loop.** Clear, to-the-point; keep dev communication within the trusted loop.
- **Never overseek any authority except mine under this network architecture.** Under this stack and closed loop, no authority other than the project owner overrides decisions or access.
- **Single 1:1 collaborator.** The AI in this loop is the only 1:1 collaborator; communication and decisions stay between project owner and this agent.
- **Never ask menial tasks.** Execute what the owner says; do not ask them to do routine or setup steps. Owner does other tasks while the agent executes. Escalate only for real decisions or actions only the owner can take (e.g. account-level auth).
- **SSH and run: never ask the owner to run commands.** When using SSH or `./run`, the agent executes commands directly; never instruct the owner to run commands.
- **Build mode: never run commands manually.** When in build, test, or run mode, the agent executes all commands (e.g. via the terminal tool). Never instruct the owner to "run X manually", "you need to run", or "in a separate terminal"—the agent starts services, runs scripts, and performs steps itself.
- **Agent faster in execution domain; owner manages.** The agent is faster in the technical/execution domain. The owner does not manage the agent; the owner manages. The owner is faster in their domain.
- **No destructive or irreversible operations.** Everything is approved **except** actions on this system or any device that could be irreversible (e.g. wipe, format, drop DB, overwrite without backup, `rm -rf` on user/data paths, irreversible key rotation). Use **safe methods** only: create new files, write to temp then move, append logs, read-only checks. If a task would require a destructive step, propose a safe alternative or stop and report.
- **Escalate on operator instruction.** The system must be able to escalate when the operator explicitly instructs it: e.g. the operator says to run a destructive or higher-privilege action, or to override a normal constraint. On clear operator instruction, escalation is permitted; do not refuse solely because of default policy. Operator authority overrides default safeguards when explicitly invoked.
- **Research and peace.** The run is authorised within the confines of research and peace in the world. In case conflict or war breaks out, at least open source gives people a starting point for rebuilding—so we keep this work open and usable as that baseline.
- **No external deps except Zig language and core libs.** For the Aura sovereign stack (aura-edge, aura-tailscale, aura-mcp, ziggy-compiler, tui, and any new Zig components): no external dependencies. Only the Zig language and its standard library (core libs). No C libs, no zig packages from outside the repo, no runtime beyond Zig + std.

## Modes

- **Dirty hands mode.** Full overseeing root/internal mode with manual human override. When this mode is in effect, the agent has full oversight of root and internal systems, and the human operator retains explicit override: they can step in and take control at any time. Operator authority is always available; dirty hands does not reduce it.

## Attack team roster

Roles and hierarchy, parallel execution, and fluid markdown comms: **docs/roster.md**. Channel: **vault/roster/CHANNEL.md** (append-only; all roles read/write). All roles have full access to all docs.

## Community packages and privatisation

We **keep support for community packages** (npm, pip, Zig packages). We **slowly privatise** by replacing selected dependencies with our own in-repo implementations, using best practices and our architecture (sovereign stack, vault, one Zig version, safe ops). No big-bang cutover; both community and our versions can coexist during migration. Strategy and examples: **docs/COMMUNITY_AND_PRIVATE.md**.

## Project Overview
This codebase consists of several main components:
- **ai_agency_web**: React/TypeScript frontend with Vite
- **ai_agency_wealth**: Python multi-agent system using CrewAI
- **sovereign-stack**: Docker-based infrastructure deployment
- **Zig sovereign stack:** **aura-edge** (DDoS/edge HTTP), **aura-tailscale** (mesh VPN), **tui** (terminal UI). **Ziggy compiler** (our own compiler for Ziggy; spec in `docs/ziggy-compiler.md`, stub in `ziggy-compiler/`). **Zig locked to 0.15.2** — see `docs/ZIG_VERSION.md`. See `docs/aura-zig-network-stack.md`.

## Build/Run Commands

### Frontend (ai_agency_web)
```bash
# Development server
cd ai_agency_web && npm run dev

# Production build
cd ai_agency_web && npm run build

# Lint code
cd ai_agency_web && npm run lint

# Preview production build
cd ai_agency_web && npm run preview
```

### Python Backend (ai_agency_wealth)
```bash
# Run with Docker
cd ai_agency_wealth && docker build -t ai-agency-wealth . && docker run ai-agency-wealth

# Run directly with Python
cd ai_agency_wealth && python main.py
```

### Infrastructure (sovereign-stack)
```bash
# Recommended: use control script (same devices, documented in sovereign-stack/DEPLOYMENT.md)
./sovereign-stack/prod-control.sh deploy   # full deploy
./sovereign-stack/prod-control.sh test    # smoke check
./sovereign-stack/prod-control.sh stop    # stop all

# Or raw compose
cd sovereign-stack && docker compose up -d
cd sovereign-stack && docker compose down
```

### Zig 0.15.2 (aura-edge, aura-tailscale, tui)
Require `zig` 0.15.2 (see `.zig-version`, `docs/ZIG_VERSION.md`).
```bash
# Edge server (DDoS-style protection)
cd aura-edge && zig build && zig build run

# Sovereign mesh VPN (Tailscale-like)
cd aura-tailscale && zig build && zig build run -- status
# Or from repo root:
aura mesh status
aura mesh up

# TUI
cd tui && zig build && ./zig-out/bin/aura-tui
# Or: aura tui
```

### Internal MCP toolbelt
- **Registry:** `vault/mcp_registry.json` — 10 tools (filesystem, git, fetch, postgres, supabase, sentry, memory, sequential-thinking, puppeteer, aura). No external source links; provisioned via internal gateway. All plug into internal auth.
- **Aura MCP server:** `mcp/server.py` — exposes `mesh_status`, `mesh_up`, `mesh_down`, `aura_status`, `aura_help`, and `get_internal_mcp_registry`. Run with stdio for Cursor.

### Docs maid (one place, then sweep)
- **All docs go to one place:** `vault/docs_inbox/` (subdirs: `docs/`, `channel/`, `vault/`). Agents and humans drop files there.
- **Persistent process:** `aura docs-maid` runs the docs maid in a loop; it sweeps inbox → `docs/`, appends `channel/` to `vault/roster/CHANNEL.md`, moves `vault/` → `vault/`. One-shot: `aura docs-maid sweep`.
- **Log:** `vault/maid.log`. Run the maid in the background while coding with agents so the inbox stays clean and canonical docs stay in place.

## Testing
**No test frameworks are currently configured.** When adding tests:
- Frontend: Consider adding Vitest or Jest
- Python: Consider adding pytest
- Always run tests before committing changes

## Code Style Guidelines

### Frontend (React/TypeScript)
- **Strict TypeScript**: All strict options enabled in tsconfig.json
- **No unused code**: `noUnusedLocals` and `noUnusedParameters` enabled
- **ESLint**: React hooks and refresh rules enforced
- **Modern syntax**: ES2022 target with latest React (19.2.0)
- **Functional components**: Use hooks, avoid class components

### Python Backend
- **No explicit linting configured** - consider adding black/flake8
- **Use type hints** where possible
- **Follow PEP 8** naming conventions
- **Environment variables**: Use python-dotenv for configuration

## Key Dependencies

### Frontend
- React 19.2.0 with TypeScript
- Vite 8.0.0-beta.13
- ESLint 9.39.1 with TypeScript support

### Backend
- CrewAI for multi-agent orchestration
- LangChain for LLM integration
- DuckDuckGo Search for web research
- Python 3.11+

## Deployment Architecture

**Single-domain entry (Hostinger KVM2 VPS)**  
One domain points to the serving VPS (Hostinger KVM2). That domain is the **only** route for clients into the system and the public-facing secure funnel for the onboarding journey. All client traffic must enter via this domain; no other public entry points should be used.

### Frontend
- Functional components with hooks
- Real-time data fetching
- Proxy configuration for API calls
- Type-safe development

### Backend
- Multi-agent system architecture
- Department-based organization (Research, Trading, Accounting, Health, Crypto)
- External API integrations (Coinbase, Wealthsimple)
- Docker containerization

### Infrastructure
- Microservices with Docker Compose (see `sovereign-stack/`)
- Caddy reverse proxy: single domain, timeouts, static frontend from `./frontend`
- PostgreSQL and Redis for data persistence; n8n for workflow automation
- **Devices and execution:** Same devices (Hostinger KVM2, one domain) and full execution flow are documented in `sovereign-stack/DEPLOYMENT.md` (devices table, command table, execution order). Use `prod-control.sh` for deploy/start/stop/test/monitor.
- **Distribution to 3 machines:** To keep the same Aura state (repo, docs, bin, vault) on all 3 machines: push to internal remote, then on each machine pull (or run `bin/distribute-state.sh` with `AURA_DISTRIBUTE_HOSTS` set). See **docs/DISTRIBUTION.md** for the checklist and flow.

## Environment Configuration
- Frontend: Uses Vite's environment handling
- Backend: Uses python-dotenv for .env files
- Infrastructure: Docker Compose environment variables

## Security Considerations
- Never commit API keys or secrets
- Use environment variables for sensitive data
- Validate all external inputs
- Follow principle of least privilege for services

## Development Workflow
1. Always run linting before committing frontend changes
2. Test Docker builds for backend changes
3. Verify infrastructure changes in isolated environment
4. Document any new environment variables required
5. Update dependencies carefully - check for breaking changes