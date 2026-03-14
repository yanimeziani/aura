# E2E Tests (Playwright)

## Where the demo UI lives

- **Landing page** (`/en` or `/fr`): Demo section with id `#demo` — scroll or click "Watch demo" to reach it
- **Demo page** (`/en/demo` or `/fr/demo`): Full-page interactive demo

## Running tests

```bash
# Ensure .env.local has required vars (SUPABASE_SERVICE_ROLE_KEY, STRIPE_WEBHOOK_SECRET, etc.)
npm run test:e2e

# Interactive UI mode
npm run test:e2e:ui
```

## Prerequisites

- Dev server starts automatically via `webServer` in `playwright.config.ts`
- On Linux, install Playwright system deps: `npx playwright install-deps`
- Tests use `reuseExistingServer` when not in CI — start `npm run dev` first to use your running server

## Test coverage

- Landing page demo section (en + fr)
- Demo page load and locale
- Interactive demo (quick actions, custom input)
- Navbar and Footer links to demo
