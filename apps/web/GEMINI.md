# GEMINI.md

## Project Overview

**Dragun (dragun-app)** is an intelligent debt recovery platform designed for businesses to recover revenue through AI-driven negotiation. It uses a "bleeding edge" stack to provide a professional, empathetic, and compliant recovery experience.

### Core Components

- **Merchant Dashboard**: A data-dense interface for managing recovery queues, uploading contracts (PDF), and configuring AI behavior (strictness, settlement floors).
- **Debtor Portal**: A mobile-first, respectful resolution interface featuring real-time AI chat (Gemini 2.0 Flash) and secure payment options (Stripe).

### Key Technologies

- **Frontend**: Next.js 16 (App Router, RSC, Server Actions), React 19, TypeScript.
- **Styling**: Tailwind CSS v4, DaisyUI v5 (Chat Bubble, Stat, Card components), Framer Motion.
- **Backend/Database**: Supabase (PostgreSQL with pgvector, Auth, Row-Level Security).
- **AI**: Gemini 2.0 Flash (via Vercel AI SDK), Groq (Llama 3.3 fallback).
- **Payments**: Stripe Connect (destination charges).
- **Internationalization**: `next-intl` (English and French support).
- **Security**: Arcjet (rate limiting, bot protection), Sentry (monitoring).

## Technical Philosophy: The "Master Blueprint"

Aura is built on a philosophy of **extreme sovereignty** and **absolute control**. This is manifested in the decision to build core infrastructure—including the Git compiler and sovereign model context protocol servers—entirely in **Zig (v0.15.2)** from scratch, without external dependencies.

### The "Master Blueprint" Analogy
Imagine a 100-story skyscraper where the master key is compromised. Instead of tracking down every key, the "Master Blueprint" approach allows for changing every single lock on every single door simultaneously in 60 seconds. This level of cryptographic rotation across a global network is only possible if you own the entire stack from the ground up.

### Custom Compiler Infrastructure
The project involves building a custom translator (compiler) to convert human-readable code into raw binary machine code. Key stages include:
- **AST (Abstract Syntax Tree)**: Representing the grammatical structure of the code.
- **Intermediate Representation (IR)**: An internal, optimized version of the code.
- **ELF Machine Code Writer**: The "deepest plumbing" that converts the representation into the final raw binary machine code (ELF format).

By bypassing standard compilers and libraries, Aura achieves:
- **Instantaneous Systemic Updates**: Near-instant global cryptographic rotation.
- **Zero Supply Chain Risk**: No reliance on third-party code or "black box" compilers.
- **Minimal Footprint**: Hyper-optimized, lean binaries (<1MB).

---

## Building and Running

### Development Commands

```bash
# Install dependencies
npm install

# Start development server
npm run dev

# Build for production
npm run build

# Start production server
npm run start
```

### Quality and Maintenance

```bash
# Run all tests (Unit + E2E)
npm test

# Run unit tests only
npm run test:unit

# Run Playwright E2E tests
npm run test:e2e

# Check i18n key parity between languages
npm run i18n:check

# Run database migration checks
npm run db:check

# Lint the codebase
npm run lint

# Security audit
npm run audit
```

---

## Development Conventions

1.  **Architecture**: 
    - Use **Server Components (RSC)** for initial data loading.
    - Use **Server Actions** (`app/actions/`) for mutations and form submissions.
    - Keep logic modular in `lib/` (e.g., `lib/ai-provider.ts`, `lib/stripe.ts`).
2.  **Security**:
    - **RLS (Row-Level Security)**: Always verify Supabase RLS policies in `supabase/migrations/`.
    - **Merchant Isolation**: Ensure `getMerchantId()` is called in all protected Server Actions.
    - **Arcjet**: Integrated for rate limiting and bot protection.
3.  **UI/UX**:
    - Follow the **Design System** defined in `DESIGN_SYSTEM.md` and `design-tokens.json`.
    - Use **DaisyUI v5** components for consistent styling.
    - Mobile-first approach for the Debtor Portal.
4.  **i18n**:
    - All user-facing text must be externalized in `messages/*.json`.
    - Maintain parity between `en.json` and `fr.json` using `npm run i18n:check`.
5.  **AI/RAG**:
    - Contracts are chunked and stored in Supabase using `pgvector`.
    - AI responses must cite contract terms when negotiating.

---

## Key Files & Directories

- `app/[locale]/`: Main application pages and layouts (i18n-routed).
- `app/actions/`: Server Actions for backend operations.
- `lib/`: Core utilities (AI, Supabase, Stripe, Comms, Phone).
- `components/`: Reusable UI components (DaisyUI, Landing, Dashboard, etc.).
- `messages/`: Translation files for `next-intl`.
- `supabase/migrations/`: Database schema, functions, and RLS policies.
- `docs/`: Specialized documentation (API, COMMS, E2E, Migration guides).
- `PRD.md`: Detailed product requirements and technical architecture.
- `MAINTENANCE.md`: Pre-release checklist and routine maintenance tasks.
