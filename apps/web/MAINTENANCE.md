# Maintenance & supervision

Routine checks and how to run them.

## Scripts

| Task | Command |
|------|---------|
| Lint | `npm run lint` |
| Unit tests | `npm run test:unit` |
| E2E tests | `npm run test:e2e` |
| All tests | `npm run test` |
| Security audit | `npm run audit` |
| i18n parity | `npm run i18n:check` |
| DB migrations check | `npm run db:check` |

## Pre-release checklist

- [ ] `npm run lint` — no errors
- [ ] `npm run test:unit` — passes
- [ ] `npm run test:e2e` — passes (or skip in CI if no browser)
- [ ] `npm run audit` — fix or accept high/critical findings
- [ ] `npm run i18n:check` — EN/FR keys in sync
- [ ] No secrets in client components; server actions call `getMerchantId()` first
- [ ] CSP and security headers unchanged in `next.config.ts`

## Dependency updates

1. **Check outdated**: `npm outdated`
2. **Security**: `npm run audit`; fix with `npm audit fix` or manual upgrades
3. **Major upgrades**: Prefer one major at a time; run full test suite and manual smoke test
4. **Lockfile**: Commit `package-lock.json` after any dependency change

## Security

- Env validation: `lib/env.ts` — all required vars validated at startup
- Admin client: Only in server code via `lib/supabase-admin.ts`
- API routes: Input validation and auth; rate limiting via Arcjet
- CSP: Defined in `next.config.ts`; avoid adding `'unsafe-inline'` / `'unsafe-eval'` without review

## Docs

- [COMMS.md](docs/COMMS.md) — Twilio/Resend and comms flows
- [e2e.md](docs/e2e.md) — Playwright E2E
- [RUN_MIGRATIONS.md](docs/RUN_MIGRATIONS.md) — Supabase migrations
