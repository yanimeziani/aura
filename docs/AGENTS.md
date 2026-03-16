# AGENTS.md — Agent Coding Guidelines

This file provides coding guidelines for agents working in this repository.

## 1. Project Overview

This repository contains multiple projects:
- **dragun-app**: Next.js 16/React 19/TypeScript application (main web app)
- **cerberus**: Zig-based autonomous AI assistant runtime
- **pegasus**: Kotlin/Android mission control for Cerberus agents
- **openclaw-config**: [DEPRECATED] Docker/Python configurations (see cerberus/policies/)
- **openclaw-tui**: [DEPRECATED] Terminal UI (replaced by Pegasus)

## 2. Build, Lint, and Test Commands

### dragun-app (Next.js/TypeScript)

```bash
# Development
npm run dev                    # Start dev server

# Build
npm run build                  # Production build
npm run start                 # Start production server

# Linting
npm run lint                   # Run ESLint

# Testing
npm run test:unit              # Run unit tests (tsx)
npm run test:e2e              # Run Playwright e2e tests
npm run test:e2e:ui           # Run e2e tests with UI
npm run test                   # Run all tests (unit + e2e)

# Run a single test file
npx playwright test tests/demo.spec.ts
npx tsx tests/chunking.test.ts

# Database
npm run db:check              # Run Supabase migrations and checks
npm run audit                  # Security audit
npm run i18n:check            # Check i18n parity
```

### cerberus (Zig)

```bash
# Build
zig build                      # Dev build
zig build -Doptimize=ReleaseSmall  # Release build (<1MB target)

# Testing
zig build test --summary all   # Run all tests (3371+ tests)
```

## 3. Code Style Guidelines

### General Principles

- **KISS**: Keep code simple and readable. Avoid clever tricks.
- **YAGNI**: Don't add code "just in case". Wait for concrete requirements.
- **Fail Fast**: Prefer explicit errors over silent failures.
- **Secure by Default**: Deny access first, grant explicitly.

### TypeScript/JavaScript (dragun-app)

#### Imports
```typescript
// Absolute imports for project modules (preferred)
import { getUser } from '@/lib/user';
import { Button } from '@/components/ui';

// Third-party imports first, then local
import { useState, useEffect } from 'react';
import { streamText } from 'ai';
import { supabaseAdmin } from '@/lib/supabase-admin';
```

#### Naming Conventions
- **Files**: `kebab-case.ts` or `PascalCase.tsx` (components)
- **Components**: `PascalCase` (e.g., `Dashboard.tsx`)
- **Functions/variables**: `camelCase` (e.g., `getUserById`)
- **Types/Interfaces**: `PascalCase` (e.g., `DebtorRecord`)

#### TypeScript Best Practices
- Always use explicit types for function parameters and return values
- Use `interface` for object shapes, `type` for unions/aliases
- Avoid `any` — use `unknown` if type is truly unknown

#### Error Handling
- Throw descriptive errors with context
- Use try/catch for async operations
- Log errors with appropriate context (avoid logging secrets)

```typescript
const { data, error } = await supabase.from('debtors').select('*').eq('id', id).single();
if (error || !data) {
  throw new Error(`Failed to fetch debtor: ${error?.message}`);
}
```

#### React/Next.js Patterns
- Use Server Components by default, Client Components only when needed ('use client')
- Use Next.js App Router conventions (server actions in `actions/`, routes in `app/api/`)

#### Formatting
- Use Prettier for code formatting
- 2-space indentation
- Single quotes for strings (except JSX attributes)

### Zig (cerberus)

See `/root/cerberus/runtime/cerberus-core/AGENTS.md` for detailed Zig conventions.

Key points:
- **Identifiers**: `snake_case` for functions/variables, `PascalCase` for types
- **Constants**: `SCREAMING_SNAKE_CASE`
- Use `std.testing.allocator` in tests (leak-detecting)
- Target `<1MB` binary size for release builds

### Python (cerberus/deploy/pegasus-compat)

- Follow PEP 8
- Use type hints
- 4-space indentation
- snake_case for functions/variables

## 4. Testing Guidelines

### Unit Tests (dragun-app)
- Place tests in `tests/` directory
- Name files as `*.test.ts`
- Use descriptive test names: `shouldReturnDebtorById`

### E2E Tests (dragun-app)
- Use Playwright
- Place specs in `tests/e2e/`

### Running Specific Tests
```bash
npx playwright test tests/demo.spec.ts
npx playwright test tests/demo.spec.ts -g "should login"
npx tsx tests/chunking.test.ts
```

## 5. Common Patterns

### Environment Variables (dragun-app)
- Use `lib/env.ts` for validation
- Prefix public vars with `NEXT_PUBLIC_`
- Never log or expose secrets

### Database (Supabase)
- Use migrations in `supabase/migrations/`
- RLS policies for row-level security
- Service role key for admin operations only

### API Routes
- Place in `app/api/` (Next.js App Router)
- Return proper status codes
- Validate input with Zod or similar

## 6. Anti-Patterns to Avoid

- **Never** use `any` type in TypeScript
- **Never** commit secrets or credentials
- **Never** skip error handling
- **Never** make unrelated changes in a PR
- **Avoid** deep nesting (max 3-4 levels)
- **Avoid** magic numbers — use named constants

## 4. HITL (Human-in-the-Loop)

- **Destructive or outside-mesh actions** (medium-to-critical, big repercussions) require operator confirmation. The gateway returns 403 until the client sends **`X-HITL-Confirm: <action_id>`**.
- **Agents must never** send the confirm header without explicit operator approval (e.g. via Mission Control). Agents may call the endpoint; if they get 403 with `hitl_required: true`, they must surface the request to the operator and only retry with the header after approval.
- Gated actions: `delete_session`, `register_org`, `revoke_org`, `attest_org`. See **docs/HITL.md** and **GET /api/hitl/actions**.

## 5. Document for public / NotebookLM (single URL)

- **Always document updates in `docs/updates/`** so they appear in the realtime docs bundle.
- The single URL **`GET /docs/nexa`** (e.g. `https://<gateway>/gw/docs/nexa`) is built on each request from curated docs + **all `docs/updates/*.md`**. Operators and public use it for NotebookLM, media summarisation, and audio/video assets.
- Write only core Nexa docs (architecture, runbooks, product updates). **Never** put logs, PII, vault content, or deployment-specific data in `docs/updates/`.
- Use clear filenames: `YYYY-MM-DD-topic.md` or `topic-update.md`.
- Treat the docs bundle as a source corpus for NotebookLM and self-supervised review. Write in a technical, neutral style that improves retrieval and synthesis quality rather than pushing a persona.
- Prefer architecture, interfaces, invariants, failure modes, and recovery procedures over slogans or promotional framing.
- Follow **[docs/NOTEBOOKLM_SOURCE_GUIDE.md](/root/docs/NOTEBOOKLM_SOURCE_GUIDE.md)** for source-writing rules that keep generated assets well-rounded without biasing tone negatively.
