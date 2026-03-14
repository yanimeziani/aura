# Dragun.app

**Intelligent debt recovery powered by AI negotiation.**

Dragun automates debt recovery with AI that negotiates professionally -- citing contract terms, offering flexible settlement paths, and maintaining full compliance. Built for businesses that want to recover revenue without destroying relationships.

## Stack

- **Framework**: Next.js 16 (App Router, Server Actions)
- **UI**: Tailwind CSS v4, DaisyUI v5, Framer Motion
- **Auth & DB**: Supabase (PostgreSQL, pgvector, Row-Level Security)
- **AI**: Groq (Llama 3.3 70B / 8B instant); optional OpenAI for RAG embeddings
- **Payments**: Stripe Connect (destination charges, 5% platform fee)
- **Monitoring**: Sentry, Vercel Analytics
- **Security**: Arcjet (rate limiting, bot protection), CSP, HSTS
- **i18n**: next-intl (EN/FR)

## Architecture

Two distinct experiences on one platform:

- **Merchant Dashboard** — Data-dense operational control. Recovery queue, analytics, CSV import/export, configurable AI tone, Stripe Connect onboarding.
- **Debtor Portal** — Calm, respectful resolution interface. Warm conversational AI, flexible payment options, secure Stripe checkout. Mobile-first.

## Getting Started

```bash
cp .env.example .env.local
# Fill in your Supabase, Stripe, and AI provider keys
npm install
npm run dev
```

## Environment Variables

See [`.env.example`](.env.example) for all required and optional variables.

At minimum you need:
- Supabase project URL + keys
- Groq API key (free at console.groq.com)
- Stripe secret key + webhook secret

## Deployment

Deployed on Vercel. Push to `main` triggers production deployment.

## Testing

- **Unit**: `npm run test:unit` (chunking and other unit tests via tsx)
- **E2E**: `npm run test:e2e` (Playwright; see [docs/e2e.md](docs/e2e.md))
- **All**: `npm run test` runs unit then E2E

## Maintenance

Routine checks (lint, audit, i18n, DB) and pre-release checklist: see [MAINTENANCE.md](MAINTENANCE.md).

## OpenClaw

This repo is part of the shared **OpenClaw** setup (Dragun + FocusFeed). MCPs (Vercel, GitHub, Supabase, Stripe, Sentry) and agent config: see `~/.openclaw/workspace/OPENCLAW_SETUP.md` or `../OPENCLAW.md`.

## License

Proprietary. All rights reserved. Meziani AI Inc.
