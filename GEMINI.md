# Aura: Sovereign Agentic Monorepo — System Specification

Aura is a holistic, decentralized framework for AI research, deployment, and autonomous agent orchestration. It provides a secure, technical layer for hosting specialized personas with absolute sovereignty and human-in-the-loop (HITL) coordination.

## Core System Components

- **[`/apps/web`](./apps/web) (Aura Web)**: A Next.js 16 / React 19 dashboard for high-throughput data visualization, telemetry, and agent control.
- **[`/apps/mobile`](./apps/mobile) (Pegasus)**: An Android/Kotlin interface for secure, mobile-to-cloud mission control and HITL approvals.
- **[`/core/cerberus`](./core/cerberus) (Cerberus Runtime)**: A high-performance, Zig-based agent execution engine (<1MB binary) hosting autonomous personas.
- **[`/ops`](./ops)**: Infrastructure automation, deployment scripts, and environmental configuration.
- **[`/docs`](./docs)**: Technical specifications, architectural diagrams, and system guides.

## Specialized Agent Personas

1.  **Career-Twin Agent**: An autonomous persona representing a professional profile to external entities, handling inquiries, scheduling, and transaction tracking.
2.  **SDR-Agent**: An automated business development persona for prospect research, communication drafting, and engagement tracking.

---

## Technical Stack

- **Frontend**: Next.js 16 (App Router), React 19, TypeScript, Tailwind CSS 4, DaisyUI 5.
- **Backend Runtime**: Zig (Cerberus Engine).
- **Mobile Client**: Android SDK / Kotlin (Pegasus).
- **Data Persistence**: Supabase (PostgreSQL with Row-Level Security).
- **AI Orchestration**: Multi-provider support via Model Context Protocol (MCP). Default models are served via local or in-house Aura components. External providers are used only for high-complexity tasks with explicit HITL approval.

---

## Operational Procedures

### System-Wide Build
```bash
npm run build
```

### Aura Web (Dashboard)
```bash
cd apps/web
npm run dev        # Development environment
npm run db:check   # Database migration validation
```

### Cerberus Runtime (Execution Engine)
```bash
cd core/cerberus/runtime/cerberus-core
zig build -Doptimize=ReleaseSmall
./zig-out/bin/cerberus --config ../../configs/agent-persona.json --cli
```

---

## System Conventions & Standards

1.  **Strict Zero-Trust Networking**: Every network is assumed hostile. All inner-device communication is anonymized via **TOR** (global signal bouncing) or decentralized via **local IPFS nodes**. 
2.  **Vibe Coding (Operational Methodology)**: Maintaining technical velocity through continuous AI orchestration. Systems are architected to be controlled via high-level intent rather than manual character-by-character composition.
3.  **Three-Tap Rule (UI/UX Constraint)**: For the Pegasus mobile interface, any operation requiring more than three user interactions (taps) to initiate is considered a workflow failure.
4.  **Security Model**: Strict adherence to Supabase Row-Level Security (RLS). No secrets in version control; utilize environment variables and encrypted vaults.
5.  **HITL Gatekeeping**: Every high-impact agent action (e.g., outbound communication, state changes) must pass through a human-in-the-loop approval gate (via Pegasus or Aura Web).
6.  **Resource Optimization**: Preference for low-overhead implementations (e.g., Zig, minimal dependencies) to ensure performance on edge infrastructure.
7.  **Documentation Standards**: Architecture specifications are maintained in `docs/` and agent-specific logic in `core/cerberus/specs/`.

---

## Core Infrastructure & Data Flow

- `README.md`: System high-level entry point.
- `docs/SYSTEM_CAPABILITIES.md`: Detailed functional overview.
- `docs/DEPLOYMENT_GUIDE.md`: Procedural deployment instructions.
- `core/cerberus/configs/`: JSON-based persona configurations.
- `core/cerberus/runtime/cerberus-core/prompts/`: System-level prompts and logic.
- `apps/web/supabase/migrations/`: Database schema and RLS security policies.
