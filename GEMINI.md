# GEMINI.md

## Project Overview

**Aura** is a holistic pocket business monorepo designed for safe AI research, deployment, and personal business management. It integrates mobile control (Pegasus), cloud execution (Cerberus), and specialized AI agents into a unified ecosystem.

### Core Components

- **[`/apps/web`](./apps/web) (dragun-app)**: A Next.js 16 / React 19 dashboard for data visualization, agent control, and professional management.
- **[`/apps/mobile`](./apps/mobile) (Pegasus)**: An Android/Kotlin application for mobile-to-cloud mission control and Human-in-the-Loop (HITL) approvals.
- **[`/core/cerberus`](./core/cerberus)**: A lean Zig-based agent runtime (<1MB binary) hosting autonomous personas like the Career Digital Twin and SDR Agent.
- **[`/ops`](./ops)**: Infrastructure automation, deployment scripts, and environment configuration.
- **[`/docs`](./docs)**: Centralized knowledge base containing architecture specs, PRDs, and guides.

### Key AI Agents

1.  **Career Digital Twin**: Represents the founder to employers, handling job inquiries, interview scheduling, and application tracking.
2.  **SDR Agent**: Automated B2B sales development representative for prospect research and personalized email outreach sequences.

---

## Technical Stack

- **Frontend**: Next.js 16 (App Router), React 19, TypeScript, Tailwind CSS 4, DaisyUI 5.
- **Backend Runtime**: Zig (Cerberus engine).
- **Mobile**: Kotlin, Android SDK (Pegasus).
- **Database**: Supabase (PostgreSQL with Row-Level Security).
- **AI/LLMs**: Claude (via OpenRouter), Llama 3.3 (fallback).
- **Integrations**: Resend (Email), Stripe (Payments), Twilio (SMS).

---

## Building and Running

### Root Commands (Monorepo)

```bash
# Run development mode for all workspaces
npm run dev

# Build all workspaces
npm run build

# Run tests across the monorepo
npm test
```

### App-Specific Commands

**Web Dashboard (`apps/web`):**
```bash
cd apps/web
npm run dev        # Start development server
npm run db:check   # Run database migration checks
```

**Cerberus Runtime (`core/cerberus`):**
```bash
cd core/cerberus/runtime/cerberus-core
zig build          # Build the Zig engine
./zig-out/bin/cerberus --config ../../configs/career-twin-agent.json --cli
```

**Mobile App (`apps/mobile`):**
```bash
cd apps/mobile
./gradlew assembleDebug  # Build debug APK
```

---

## Development Conventions

1.  **Security First**: Strictly adhere to Supabase Row-Level Security (RLS) policies. Never commit secrets; use `.env` files (see `.env.example`).
2.  **Human-in-the-Loop (HITL)**: All sensitive agent actions (sending emails, accepting interviews) MUST go through an approval gate (usually via Pegasus or the Web Dashboard).
3.  **Modular Architecture**: Logic is shared through (currently planned) packages and strictly typed interfaces.
4.  **Lean Systems**: Preference for low-overhead implementations (e.g., Zig for the core engine) to ensure high performance and low resource usage.
5.  **Documentation**: Keep architecture specs in `docs/` and agent-specific documentation in `core/cerberus/specs/` updated with every major change.

---

## Key Files & Directories

- `README.md`: High-level entry point and project vision.
- `docs/PROJECT_SUMMARY.md`: Detailed overview of what has been built.
- `docs/QUICKSTART.md`: Step-by-step setup instructions.
- `core/cerberus/configs/`: JSON configurations for different agent personas.
- `core/cerberus/runtime/cerberus-core/prompts/`: System prompts for autonomous agents.
- `apps/web/supabase/migrations/`: Database schema and RLS policies.
