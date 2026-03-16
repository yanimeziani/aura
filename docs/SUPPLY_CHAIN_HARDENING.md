# Supply Chain Hardening Plan

## Current high-risk supply chain surface

### Frontend and runtime

- `next`
- `react`
- `react-dom`
- `next-intl`
- `framer-motion`
- `three`
- `@react-three/fiber`
- `@react-three/drei`
- `lucide-react`
- `tailwindcss`
- `daisyui`

These expand the browser and build-time attack surface through a very large transitive dependency tree, SWC/bundler binaries, and frequent release churn.

### Platform and data plane

- `@supabase/ssr`
- `@supabase/supabase-js`
- `@sentry/nextjs`
- `@vercel/analytics`
- `@arcjet/next`
- `stripe`
- `twilio`
- `resend`
- `@ai-sdk/*`
- `ai`

These create vendor concentration risk, secret-handling risk, telemetry egress risk, and potentially silent behavior changes if pinned loosely.

### Toolchain

- `npm`
- transitive `node_modules`
- prebuilt platform binaries such as `@next/swc-*`

This is the part most likely to break reproducibility and to pull in compromised packages.

## Replacement target

### Backend

Use in-house Zig services only for the critical control plane:

- HTTP API routes
- auth/session validation
- static asset serving
- health/mesh/status endpoints
- operator actions behind HITL

Rules:

- lock Zig version exactly
- no runtime package manager
- stdlib-first implementation
- vendor any non-stdlib code in-repo after review
- treat external network integrations as isolated adapters, not framework plugins

### Frontend

Use a lightweight in-house TypeScript shell:

- no React
- no Next.js
- no client framework runtime
- no CSS utility framework
- no icon package dependency
- no analytics SDK

Use:

- TypeScript compiled locally
- static HTML + CSS + minimal DOM code
- a small in-repo design system
- all API routes served by the Zig backend

## Migration mapping

| Current | Risk | In-house replacement |
|---|---|---|
| Next.js routes | heavy framework, transitive churn | Zig route table |
| React state/rendering | runtime complexity | direct DOM rendering in TS |
| Tailwind/DaisyUI | build + CSS dependency surface | local CSS tokens/components |
| Supabase client | vendor lock-in | Zig adapters to your own DB/service layer |
| Sentry/Vercel analytics | egress + telemetry leakage | local structured logs |
| Stripe/Twilio/Resend SDKs | vendor SDK exposure | narrow HTTPS adapters in Zig |
| AI SDK wrappers | rapid churn | explicit provider clients or local OSS inference |

## What was added

- [core/nexa-gateway/src/main.zig](/root/core/nexa-gateway/src/main.zig): stdlib-only Zig gateway scaffold
- [core/nexa-gateway/build.zig](/root/core/nexa-gateway/build.zig): locked build definition
- [core/nexa-gateway/build.zig.zon](/root/core/nexa-gateway/build.zig.zon): no external Zig dependencies
- [apps/nexa-lite/index.html](/root/apps/nexa-lite/index.html): lightweight frontend shell
- [apps/nexa-lite/src/main.ts](/root/apps/nexa-lite/src/main.ts): framework-free TS client
- [apps/nexa-lite/src/design-system.css](/root/apps/nexa-lite/src/design-system.css): local design system tokens/components

## Immediate next steps

1. Put the Zig gateway behind the existing mesh and expose only a minimal route set.
2. Move dashboard read paths to `apps/nexa-lite`.
3. Replace each external SaaS SDK with a reviewed Zig adapter or internal service.
4. Freeze versions and add hash verification in CI for Zig and frontend build outputs.
5. Remove Next.js apps only after feature parity and operator validation.
