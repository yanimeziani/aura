# Nexa Sovereign Scaffolding Guide

**Status**: ACTIVE / MANDATORY
**Version**: 1.0.0
**Philosophy**: All In-House, All Tailored. No external boilerplates.

This document unifies the scaffolding procedures across the Nexa ecosystem. All new components must follow the protocol architecture in [ARCHITECTURE.md](/root/docs/ARCHITECTURE.md), [PROTOCOL.md](/root/docs/PROTOCOL.md), [TRUST_MODEL.md](/root/docs/TRUST_MODEL.md), and [THREAT_MODEL.md](/root/docs/THREAT_MODEL.md) before implementation details are chosen.

---

## 1. Core Principles
- **BMAD (Build, Monitor, Automate, Document)**: No feature exists without documentation and a monitoring plan.
- **Never Launch Alone**: All scaffolding plans must be reviewed by a Co-Pilot.
- **Sovereign-First**: Use local-only tools (Ollama/litllm) for generation where possible.
- **Brutalist**: Data-dense, high-signal, zero-fluff code and docs.
- **Protocol-First**: New scaffolds should strengthen identity, trust, transport, recovery, or operator control.

---

## 2. Agent Scaffolding (Cerberus)
To launch a new autonomous agent in the Cerberus runtime:

### Step 2.1: Configuration (`/core/cerberus/configs/`)
Create `{agent-name}-agent.json` following the `audit-agent.json` pattern:
```json
{
  "agents": {
    "{agent-name}": {
      "name": "Bespoke {Name} Agent",
      "model": { "primary": "ollama/llama-3.3-70b", "fallback": "litllm/mistral-nemo" },
      "system_prompt_file": "prompts/{agent_name}_prompt.txt",
      "tools": ["web_research", "file_write", "shell_command"],
      "memory": { "profile": "{agent_memory_profile}", "auto_save": true }
    }
  },
  "channels": { "web": { "enabled": true, "port": 30XX } },
  "gateway": { "port": 30YY, "host": "127.0.0.1" }
}
```

### Step 2.2: Persona (`/core/cerberus/runtime/cerberus-core/prompts/`)
Create `{agent_name}_prompt.txt`. Must include:
- **Core Mandates**: Mandatory Authorization & Never Launch Alone.
- **Mission Objectives**: Precise, measurable goals.
- **Style Guidelines**: Brutalist, data-dense.

### Step 2.3: Memory Initialization
Create `/core/cerberus/scripts/init-{agent-name}-memory.sh` to scaffold the `~/.cerberus/memory/{agent-name}/` directory structure.

---

## 3. Web Component Scaffolding (Dragun-app)
Next.js 16 / React 19 / Tailwind 4 / DaisyUI 5.

### Step 3.1: Page Structure
Create `/apps/web/app/[locale]/{feature}/page.tsx`.
- Use **Server Components** by default.
- Implement **RLS (Row-Level Security)** checks at the data layer.

### Step 3.2: Components
Scaffold shared components in `/apps/web/components/{feature}/`.
- Strictly typed TypeScript.
- DaisyUI/Tailwind 4 for styling.

### Step 3.3: API Routes
Scaffold in `/apps/web/app/api/{feature}/route.ts`.
- Use Zod for input validation.
- Return standard JSON error shapes.

---

## 4. Mobile Component Scaffolding (Pegasus)
Kotlin / Jetpack Compose / Material 3.

### Step 4.1: UI Screens
Scaffold in `/apps/mobile/ui/screens/`.
- High-contrast, one-handed navigation.
- Night-ops optimized colors.

### Step 4.2: Domain Logic
Scaffold in `/apps/mobile/domain/core/`.
- Strictly typed network models.
- Offline-first cache support (30-day).

---

## 5. Infrastructure Scaffolding (Ops)
Ansible / Debian 12.

### Step 5.1: Roles
Scaffold new roles in `/ops/ansible/roles/{role-name}/`.
- Tasks must be idempotent.
- Handlers for service restarts.

### Step 5.2: Deployment
Update `/docs/DEPLOY.md` with new service requirements and ports.

---

## 6. Documentation Scaffolding (Docs Maid)
Every new scaffolded component MUST be registered in:
1. `docs/PROJECT_SUMMARY.md` (High-level overview)
2. `docs/PROTOCOL.md` and `docs/TRUST_MODEL.md` (if it affects sovereign infrastructure)
3. `vault/roster/CHANNEL.md` (Operational log)

**"We do not front; we build, deploy, and own the results."**
