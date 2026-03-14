# PILOT_GAPS — Production Pilot Readiness

## Current State Snapshot (post–gap scan)
- Core dashboard, debtor records, chat flow, and payment flow exist.
- **Statuses**: `pending`, `contacted`, `promise_to_pay`, `paid`, `no_answer`, `escalated` (see `lib/recovery-types.ts`).
- **Prioritized queue**: Dashboard filters + sort (score, amount, overdue, created); `lib/recovery-score.ts`; queue section in dashboard.
- **Action log**: `recovery_actions` table; `updateRecoveryStatus` logs every status change; timeline per debtor in table.
- **KPI strip**: StatsGrid — outstanding, recovered, contacted today, promises, paid today, plan.
- **CSV export**: `/api/recovery/export` (debtors) and `/api/recovery/audit-export` (actions); links in DebtorFilters and BulkActionsBar.
- **Schema**: Migration `20260228000001_collections_pilot.sql` ensures `recovery_actions` and `debtors.days_overdue`/`updated_at` in DB.

## Remaining (operational)
- [x] Pilot dataset ingestion script ready (`mounir_onboarding.sql`)
- [ ] Run `mounir_onboarding.sql` against production Supabase project
- [ ] Verify RAG indexing for Venice Gym agreement (requires AI keys)
- [ ] Book 15-minute onboarding call with Mounir (Sovereign Calendar Ready in `~/sovereign_calendar.py`)

## Immediate Build Order — DONE
1. ~~Schema extension + migration for statuses and action log~~
2. ~~Prioritized queue query + dashboard section~~
3. ~~Action update server actions~~
4. ~~KPI cards wired to operational metrics~~
5. ~~CSV export fallback for daily operations~~
6. ~~Mounir onboarding & pilot dataset script~~
7. ~~Plug in Sovereign Local Encrypted Calendar (MCP)~~
