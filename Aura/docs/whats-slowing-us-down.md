# What’s slowing us down — facts and fixes

*Evidence from the repo and runtime.*

---

## 1. Dashboard showed no targets (fixed)

**Fact:** `/state` only returned `persistentState` and `clients`. It did **not** return `proposals` or `sniperTargets`. The UI expects `s.proposals` and `s.sniperTargets`, so the feed was always empty.

**Fact:** The Eye writes proposals to `upwork-scraper/proposals/*.md`. There were already 2 files there. The backend never read that vault.

**Fix:** Backend now has `loadProposalsFromVault()` and `loadSniperTargets()` (from `sniper-node/outbox`). `GET /state` includes `state.proposals` and `state.sniperTargets`. Dashboard will show targets after refresh.

---

## 2. APPROVE did nothing (fixed)

**Fact:** The frontend calls `POST /approve` with `{ title }`. There was **no** `/approve` route in the backend → 404. So “APPROVE” never started the delivery pipeline.

**Fix:** Added `POST /approve` (requireAuth). It finds the proposal/target by title, calls `autoApprove(title, content)`, and returns `{ success: true, clientId }`. Delivery (create-vite, client config, CRM sync) now runs when you approve.

---

## 3. First dollar path (unchanged)

**Fact:** Revenue only increases when a **Stripe webhook** hits `POST /webhook/stripe` (e.g. `checkout.session.completed`). No other code path updates `totalRevenue`. So the first dollar arrives at the **exact time** that first webhook is received and processed.

**What was slowing it:** Even with proposals visible and approve working, the client still has to **pay** (e.g. via your Stripe Payment Link). If `STRIPE_WEBHOOK_SECRET` isn’t set or the link isn’t used, no webhook fires and revenue stays 0.

**Action:** Ensure Stripe webhook is configured (e.g. `stripe listen --forward-to localhost:8181/webhook/stripe`) and that delivered clients get your payment link. First dollar = first successful payment event.

---

## 4. Other friction (for awareness)

| Item | Fact |
|------|------|
| **Proposals ↔ backend** | Eye runs as a separate process and writes to disk. Backend now **reads** that vault on every `/state`. No real-time push; refresh or re-open dashboard to see new proposals. |
| **Run /approve auth** | `POST /run/:node` and `POST /approve` use `requireAuth`. In `SOVEREIGN_MODE=true` they’re open; otherwise Google OAuth required. |
| **agent-hub dist** | `autoApprove` uses `generateClientConfig` and `syncToCRM` from `agent-hub/dist`. If `agent-hub` isn’t built, approve can throw at runtime. |

---

## Summary

- **Slowing us down (and fixed):** Empty targets (state didn’t load vault), and APPROVE 404 (no route). Both are fixed in the backend.
- **First dollar:** Still gated on a real Stripe payment and webhook. Unblocking the dashboard and approve gets you to “delivery done”; payment is the next step.

Restart the backend so the new `/state` and `/approve` code is in effect. Then refresh the dashboard — you should see the 2 proposals and APPROVE should work.
