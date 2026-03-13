# Production Blockers — Demo Readiness (3-Day Horizon)

**Scope:** dragun.app production and demo in 3 days.  
**Build:** ✅ `npm run build` passes.  
**Fixed this pass:** Missing `/auth/auth-code-error` page (was 404 on OAuth failure).

---

## Critical (fix before demo)

### 1. Environment variables in production

`validateEnv()` in `lib/env.ts` runs at startup (instrumentation) but **errors are only logged** — the app still boots. If any required var is missing, you’ll see runtime failures (Stripe, Supabase, AI, etc.) instead of a clear startup error.

**Required in production (from `lib/env.ts`):**

| Variable | Purpose |
|----------|--------|
| `NEXT_PUBLIC_URL` | Canonical app URL (redirects, webhooks, links). |
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase project URL. |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Client-side Supabase. |
| `SUPABASE_SERVICE_ROLE_KEY` | Server/admin Supabase (never use anon key fallback in prod). |
| `STRIPE_SECRET_KEY` | Stripe API. |
| `STRIPE_WEBHOOK_SECRET` | Stripe webhook signature verification. |
| `ARCJET_KEY` | Rate limiting / bot protection on protected routes. |
| `SENTRY_DSN` | Server Sentry. |
| `NEXT_PUBLIC_SENTRY_DSN` | Client Sentry. |
| `GROQ_API_KEY` | Chat / AI features (free tier at console.groq.com). |

**Strongly recommended for demo:**

- `STRIPE_PRICE_STARTER`, `STRIPE_PRICE_GROWTH`, `STRIPE_PRICE_SCALE` — otherwise subscription checkout throws a clear error when a user tries to upgrade.
- `DEBTOR_PORTAL_SECRET` — dedicated secret for debtor portal links; if unset, code falls back to `SUPABASE_SERVICE_ROLE_KEY` then a dev fallback (see Security below).
- `CRON_SECRET` — if you use Vercel cron for scheduled follow-up or data retention; without it those endpoints return 401.

**Action:** In Vercel (or your host), set all required vars and the recommended ones. Run a full auth + dashboard + one AI chat flow after deploy to confirm.

---

### 2. OAuth / auth error page — FIXED

**Was:** Auth callbacks redirect to `/auth/auth-code-error` on missing/invalid `code` or exchange failure, but that route had no page → 404.

**Done:** Added `app/auth/auth-code-error/page.tsx` with a short message and “Back to sign in” link. Build includes `○ /auth/auth-code-error`.

**Action:** None. Optional: add the same copy to i18n if you later localize `/auth/*`.

---

### 3. Stripe webhook and price IDs

- **Webhook:** `app/api/stripe/webhook/route.ts` uses `STRIPE_WEBHOOK_SECRET`; if missing it returns 500 and logs. Ensure the env var is set in production and matches the webhook secret in Stripe (Dashboard → Webhooks → endpoint for this app).
- **Prices:** If `STRIPE_PRICE_STARTER` (or growth/scale) is empty, `createSubscriptionCheckout` throws when a user clicks upgrade. Create the prices in Stripe and set the three env vars.

**Action:** Configure production webhook URL in Stripe, set `STRIPE_WEBHOOK_SECRET`, and set all three `STRIPE_PRICE_*` vars.

---

### 4. Supabase: service role in production

`lib/supabase-admin.ts` uses:

`SUPABASE_SERVICE_ROLE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY`

In production you must set `SUPABASE_SERVICE_ROLE_KEY`. Using the anon key as fallback bypasses the intended security model (service role for server-only, anon for client).

**Action:** Set `SUPABASE_SERVICE_ROLE_KEY` in production and do not rely on anon key fallback.

---

## Security / hardening (before or soon after demo)

### 5. Debtor portal secret

`lib/debtor-token.ts` uses:

`process.env.DEBTOR_PORTAL_SECRET || process.env.SUPABASE_SERVICE_ROLE_KEY || 'fallback-dev-secret'`

In production, set `DEBTOR_PORTAL_SECRET` to a dedicated secret so debtor links are not signed with the service role key. If both env vars were missing, the literal fallback would be used (unacceptable in prod).

**Action:** Generate a strong secret and set `DEBTOR_PORTAL_SECRET` in production.

---

### 6. Env validation at startup

`instrumentation.ts` catches `validateEnv()` and only logs:

```ts
try { validateEnv(); } catch (error) { console.error(error); }
```

So the app can start even when required vars are missing. Consider rethrowing in production so deploys fail fast when config is incomplete.

**Action:** Optional: in production, rethrow after logging so the process exits and the deploy is marked failed.

---

## Demo-day checklist

- [ ] All required env vars set in production (see table above).
- [ ] `STRIPE_PRICE_STARTER` (and growth/scale if demoing plans) set; Stripe webhook URL and `STRIPE_WEBHOOK_SECRET` configured.
- [ ] `SUPABASE_SERVICE_ROLE_KEY` set; no reliance on anon fallback for admin.
- [ ] `DEBTOR_PORTAL_SECRET` set (recommended).
- [ ] One full flow: Google sign-in → dashboard → add/view debtor → send message (AI) → (optional) checkout or debtor portal link.
- [ ] Optional: Hit `/api/health` and confirm `status: operational` and `ai_configured: true`.
- [ ] Optional: Remove or restrict `/sentry-example-page` in production (or leave for internal testing only).

---

## Non-blockers (noted for later)

- **Sentry:** `SENTRY_AUTH_TOKEN` is only needed for build-time upload; runtime works with DSN only.
- **Cron:** Scheduled follow-up and data retention require `CRON_SECRET` and Vercel cron (or equivalent) configured; not required for a basic demo.
- **Contact form:** `CONTACT_EMAIL` / `RESEND_FROM` and Resend config only needed if you demo the contact page.
- **SMS/Twilio:** Optional until you need SMS; defaults to noop.

---

## Summary

- **Fixed:** `/auth/auth-code-error` page added so failed OAuth redirects show a proper page instead of 404.
- **Must-do for demo:** Set all required and recommended env vars in production; configure Stripe webhook + price IDs; use `SUPABASE_SERVICE_ROLE_KEY` and preferably `DEBTOR_PORTAL_SECRET`; run one full user journey end-to-end.
