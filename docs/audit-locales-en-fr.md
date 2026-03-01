# Audit: EN & FR locales across the platform

**Scope:** All message files (`messages/*.json`), i18n config, and usage of translations app-wide.  
**Last audit:** 2026-02-28.

---

## 1. Locale setup

| Item | Value |
|------|--------|
| **Active locales** | `en`, `fr` (see `i18n/routing.ts`) |
| **Default locale** | `en` |
| **Locale detection** | Enabled |
| **Message loading** | `i18n/request.ts` → `messages/${locale}.json` (only `en.json` or `fr.json` are loaded) |
| **Extra message files** | `fr-US.json`, `fr-CA.json` exist but are **not** in `routing.locales`; they are never loaded by the current config |

**Conclusion:** The app is effectively **en + fr** only. fr-US and fr-CA are present on disk but unused unless routing is extended.

---

## 2. Key coverage: EN vs FR

| Metric | EN | FR |
|--------|----|----|
| **Total leaf keys** | 585 | 584 |
| **Missing in FR** | — | 1 (fixed: `Pricing.heroTitle`) |
| **Extra in FR** | 0 | — |

**Namespaces (top-level):** Both have the same 20:  
Navbar, Footer, Demo, Home, Features, Pricing, FAQ, Contact, About, Legal, Integrations, Dashboard, Chat, Pay, Success, Auth, Onboarding, OnboardingProfile, OnboardingTutorial, DebtorShell.

After adding `Pricing.heroTitle` to `fr.json`, FR has full key parity with EN for all namespaces.

---

## 3. Namespaces and where they’re used

| Namespace | Used in |
|-----------|---------|
| **Navbar** | `components/Navbar.tsx` |
| **Footer** | `components/Footer.tsx`, `components/FooterStatus.tsx` |
| **Demo** | `app/[locale]/(marketing)/demo/page.tsx`, `components/InteractiveRecoveryDemo.tsx` |
| **Home** | `app/[locale]/(marketing)/page.tsx`, demo page (backToHome, demoTitle, demoDesc) |
| **Features** | `app/[locale]/(marketing)/features/page.tsx` |
| **Pricing** | `app/[locale]/(marketing)/pricing/page.tsx` |
| **FAQ** | `app/[locale]/(marketing)/faq/page.tsx` |
| **Contact** | `app/[locale]/(marketing)/contact/page.tsx` |
| **About** | `app/[locale]/(marketing)/about/page.tsx` |
| **Legal** | `app/[locale]/(marketing)/legal/page.tsx` |
| **Integrations** | `app/[locale]/(marketing)/integrations/page.tsx` |
| **Dashboard** | Dashboard page + DashboardTopNav, DebtorFilters, DebtorTableWithBulk, FocusStrip, InsightsPanel, SuggestedCitations, KnowledgeModal, SettingsModal, PaywallBanner, PendingSubscription, BulkActionsBar, ImportDebtors, DebtorActionForm, MobileBottomBar |
| **Chat** | `components/debtor-portal/ChatClient.tsx` |
| **Pay** | `components/debtor-portal/PayClient.tsx` |
| **Success** | `app/[locale]/pay/[debtorId]/success/page.tsx` |
| **Auth** | `app/[locale]/login/page.tsx`, `app/[locale]/register/page.tsx` |
| **Onboarding** | `app/[locale]/onboarding/page.tsx` |
| **OnboardingProfile** | `app/[locale]/onboarding/profile/page.tsx`, `ProfileForm.tsx` |
| **OnboardingTutorial** | `app/[locale]/onboarding/tutorial/page.tsx`, `TutorialClient.tsx` |
| **DebtorShell** | `components/debtor/DebtorShell.tsx` |

All namespaces present in EN/FR are referenced in the codebase.

---

## 4. fr-US and fr-CA (not active)

| File | Top-level keys | Leaf keys | Missing vs EN |
|------|----------------|-----------|----------------|
| **fr-US.json** | 15 | ~262 | No Demo, Onboarding, OnboardingProfile, OnboardingTutorial, DebtorShell; ~323 keys |
| **fr-CA.json** | 15 | ~265 | Same missing namespaces; ~320 keys |

These files are **not** loaded with the current routing. If you enable `fr-US` or `fr-CA` later, they will need the missing namespaces (or a fallback chain) to avoid missing translation keys.

---

## 5. Hardcoded / non-translated strings

Strings that are user-facing but not using `t()`:

| Location | String | Suggestion |
|----------|--------|------------|
| `DashboardAlerts.tsx` | `aria-label="Updates and alerts"` | Add to Dashboard (or shared) and use `t('updatesAndAlerts')` |
| `DashboardTopNav.tsx` | `aria-label="Open account menu"` | Add to Dashboard, e.g. `t('openAccountMenu')` |
| `Navbar.tsx` | `aria-label="Open menu"` | Add to Navbar, e.g. `t('openMenu')` |
| `Navbar.tsx` | `aria-label="Dragun home"` | Add to Navbar, e.g. `t('dragunHome')` |
| `SettingsModal.tsx` | `placeholder="+1 234 567 8900"` | Use Dashboard (or OnboardingProfile) placeholder key |
| `MobileBottomBar.tsx` | `placeholder="Jane Smith"`, `"jane@example.com"`, `"1500.00"` | Use Dashboard add-debtor placeholders |
| `AccessibleModal.tsx` | `aria-label="Close modal"` | Shared or per-component key |
| `PhoneMockup.tsx` | `"View payment options"` | Add to Home or shared |
| `Typography.tsx` | `aria-label="required"` | Shared key for “required” |

**Server-side / flow:**  
- `app/[locale]/onboarding/page.tsx`: `formData.append('locale', 'en')` — locale is hardcoded to `'en'`; should use current request locale when available.

---

## 6. Interpolation and dynamic keys

- **Interpolation:** Used correctly where needed, e.g. `t('subscriptionActivatedDesc', { plan, limit })`, `t('focusCount', { count })`, `t('dOverdue', { days })`, `t('dScore', { days, score })`.
- **Dynamic key:** `t(\`nextAction_${getNextAction(d).key}\`)` in DebtorTableWithBulk — all possible `nextAction_*` keys must exist in both en and fr (send_outreach, follow_up, wait_promise, etc.). Verified present in EN; FR should mirror.

---

## 7. Recommendations

1. **FR key parity:** Done — `Pricing.heroTitle` added to `fr.json`.
2. **Aria-labels and placeholders:** Move the strings in §5 into message files and use `t()` so EN/FR stay in sync and screen readers get the right language.
3. **Onboarding locale:** Replace hardcoded `'en'` in onboarding form with the current locale (e.g. from middleware or request).
4. **fr-US / fr-CA:** Either remove if unused or document as “future locales”; if enabled, add missing namespaces or implement fallback (e.g. fr-CA → fr → en).
5. **Lint/CI:** Add a script or CI step that compares `en.json` and `fr.json` leaf keys and fails when FR is missing keys (or when new keys are added only to one file).

---

## 8. File reference

| File | Purpose |
|------|---------|
| `i18n/routing.ts` | Locales, default locale, detection |
| `i18n/request.ts` | Loads `messages/${locale}.json` for the request |
| `messages/en.json` | English (source of truth for key set) |
| `messages/fr.json` | French (full parity with EN after heroTitle fix) |
| `messages/fr-US.json` | French (US) — not loaded |
| `messages/fr-CA.json` | French (CA) — not loaded |
| `app/page.tsx` | Redirects to `/${defaultLocale}` |
| `lib/supabase/middleware.ts` | Normalizes paths like `/dashboard` to `/${defaultLocale}/dashboard` |

---

## 9. Summary

- **EN and FR** are the only active locales; key coverage is aligned (585 → 584 + 1 fix).
- **fr-US and fr-CA** are not used by routing; they are partial and would need more keys/namespaces if enabled.
- **Hardcoded strings** are limited to a few aria-labels, placeholders, and one onboarding locale; moving them into messages will complete locale coverage for the platform.
