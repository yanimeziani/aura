# Next 10 Crucial Steps

Prioritized actions after the mobile responsive pass. Tick as done.

---

1. **Run full pre-release checklist**  
   Execute: `npm run lint`, `npm run i18n:check`, `npm run test:e2e`, `npm run build`. Fix any failures before tagging or deploying.

2. **Add dashboard error boundary**  
   Create or verify `app/[locale]/dashboard/error.tsx` with a user-friendly fallback and retry so dashboard failures don’t white-screen on mobile/desktop.

3. **Validate env at build/runtime**  
   Ensure `lib/env.ts` (or equivalent) validates all required env vars and fails fast with clear errors; keep `.env.example` in sync and never commit `.env.local`.

4. **Harden API routes**  
   Review `/api/chat`, `/api/stripe/*`, and webhooks: auth, input validation, and rate limiting (Arcjet) on every public route; log and monitor 4xx/5xx.

5. **i18n parity and RTL (if needed)**  
   Run `npm run i18n:check`; add any missing EN/FR keys; if you add RTL locales later, audit layout and `dir`/`lang` usage.

6. **E2E coverage for critical paths**  
   Add or extend Playwright tests for: login → dashboard, add debtor, open chat link, pay flow (or mocked Stripe), and mobile viewport (e.g. 375px) for key pages.

7. **Monitoring and alerts**  
   Confirm Sentry is configured for frontend and API; set up alerts on error rate and optionally on key business events (e.g. payment completed, webhook failures).

8. **Security and dependency audit**  
   Run `npm run audit` (or equivalent); fix or document accepted high/critical issues; re-check CSP and security headers in `next.config.ts` after any new scripts or domains.

9. **CI pipeline**  
   Add or update GitHub Actions (or other CI): lint, i18n check, build, and e2e (or smoke) on PRs; block merge on failure for main/production branch.

10. **Documentation and handoff**  
    Keep README, MAINTENANCE.md, and COMMS.md up to date; document any new env vars, feature flags, or deployment steps; note mobile viewport and safe-area assumptions for future work.

---

After completing these, run the pre-release checklist again and then deploy or tag a release.
