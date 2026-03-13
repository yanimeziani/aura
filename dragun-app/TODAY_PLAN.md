# TODAY_PLAN — Production Pilot Build (Venice Gym Charlesbourg)

## Mission
Ship a live production pilot that can replace Debtor Raptor in day-to-day unpaid charge recovery operations.

## Success Criteria (Today)
- [ ] Unpaid accounts ingest works on real client export
- [x] Prioritized recovery queue is visible and actionable
- [x] Operator can log outcomes (reached/promise/paid/no answer/escalated)
- [x] KPI strip updates from real actions
- [x] Audit trail exists for every operator action

## Timeboxed Execution

### Sprint 1 (Now → +90 min): Foundation + Gap Scan
- [x] Verify current app runs locally
- [x] Identify existing unpaid-charges flow coverage in code
- [x] Write implementation gaps in `PILOT_GAPS.md`
- [x] Lock minimal schema changes (migration `20260228000001_collections_pilot.sql`)

### Sprint 2 (+90 → +210 min): Core Recovery Queue
- [x] Build/adjust query for prioritized unpaid accounts
- [x] Queue screen with score + next action
- [x] Action controls + status updates

### Sprint 3 (+210 → +330 min): KPI + Auditability
- [x] Pilot KPI summary (StatsGrid)
- [x] Immutable action log entries (recovery_actions + timeline)
- [x] Filters (age bucket / amount bucket / status)

### Sprint 4 (+330 → +420 min): Hardening
- [x] Validate error paths and empty states (existing)
- [x] CSV export snapshot for operations fallback
- [ ] Smoke test end-to-end on pilot dataset

## Constraints
- Keep scope to collections operations only
- No broad redesigns
- Use term: production pilot
