# User Journey Map: Meziani AI Labs Ecosystem

This document maps the end-to-end user experience for the Meziani AI Labs product suite (Dragun, Aura Flow, Aura Taxes).

---

## 1. Awareness & Initial Ingestion
**Entry Point:** `https://meziani.ai` (Public-facing landing page)

- **User Context:** SMB owner or Enterprise operator looking for autonomous infrastructure.
- **Engagement:**
  - User lands on the centered, high-end Next.js page.
  - User chooses their segment: **Canada** (Data Sovereignty) or **Algérie / MENA** (Open-source automation).
  - User browses features (Canadian hosting, Systematic Execution, Operational Continuity).
- **Call to Action:** "Request Assessment" (Phase 1).
- **Trigger:** Form submission triggers two paths:
  1. **Lead Database:** Data saved to `meziani.org/api/lead`.
  2. **Zig Workflow:** Data sent to `aura-flow` (`/ops/webhook/landing`) for automated profiling.

---

## 2. Authentication Gateway
**Entry Point:** `https://www.dragun.app/login` (Central Auth Gateway)

- **UX Goal:** One identity for all Meziani AI Labs products.
- **Action:** 
  - User signs in with Google.
  - System checks `validate-access` status.
- **Landing:** Redirect to the **Central Portal Hub** (`/portal`).

---

## 3. Central Portal Hub
**Entry Point:** `https://www.dragun.app/portal` (Unified Dashboard)

- **UX Design:** High-end dark theme, grid-based tile layout.
- **Product Tiles:**
  - **Dragun:** "Launch" button (Active).
  - **Aura Flow:** "Coming Soon" (Inactive).
  - **Aura Taxes:** "Coming Soon" (Inactive).
- **Cross-Sell Logic:** User sees the breadth of the ecosystem immediately upon entry.

---

## 4. Active Usage (The SaaS Journey)
**Entry Point:** `/dashboard` (Specific SaaS module)

- **Phase A: Dragun (Debt Recovery)**
  - **Onboarding:** Profile setup → Policy definition (Strictness) → Document indexing (RAG).
  - **Core Value:** Import debtors → AI Negotiates → Settlement links sent via Stripe.
  - **Transparency:** Audit trails visible for every interaction.
- **Phase B: Aura Flow (Workflows) - *Future***
  - Automated webhook handling and spooling.
- **Phase C: Aura Taxes (Accounting) - *Future***
  - QuickBooks-grade ledger management using the Zig backend.

---

## 5. Retention & Expansion
- **Unified Billing:** Centralized Stripe Connect integration across all products.
- **Synergy:** Lead data from `aura-landing-next` flows into `aura-flow`, which can eventually trigger a recovery case in `dragun` or an invoice in `aura-taxes`.
- **System Health:** Managed by the **Aura OS Night Ops** layer, ensuring 24/7 autonomous availability.

---

## UX Principles
1. **Miller’s Law:** Max 3-5 primary metrics on dashboards.
2. **Goal-Gradient Effect:** Clear progress bars during onboarding.
3. **Centered Focus:** Single-column focus for high-conversion forms.
4. **Magnet Scroll:** Intentional content delivery via scroll-snapping.
