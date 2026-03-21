# Transfer Checklist (ULaval Corpus UL)

Mark each item `[x]` only when evidence exists in the handover package.

## A. Repository and Build Integrity

- [ ] Snapshot commit hash recorded
- [ ] Transfer timestamp recorded
- [ ] File manifest with checksums generated
- [ ] `make verify-release` (or equivalent gate) executed and archived
- [ ] Clean-environment build reproduction validated by receiving team

## B. Documentation Completeness

- [ ] Architecture docs included
- [ ] Protocol docs included
- [ ] Trust and threat model docs included
- [ ] Security policy and disclosure process included
- [ ] Governance and contribution docs included
- [ ] ULaval transfer protocol document included

## C. OSS Attribution and Licensing

- [ ] `docs/transfer/OSS_SOURCE_REGISTER.md` complete (no TODOs)
- [ ] License file inventory validated
- [ ] NOTICE obligations reviewed and generated where required
- [ ] Vendored source provenance verified
- [ ] Citation review approved by designated reviewers

## D. Security and Operations

- [ ] Secrets scrubbed from transfer package
- [ ] `.env.example` reviewed for safe guidance only
- [ ] Incident escalation path documented
- [ ] Access control matrix defined for pilot/acceptance phases
- [ ] Rollback and recovery procedures tested

## E. Governance and Institutional Acceptance

- [ ] Roles and responsibilities acknowledged by both parties
- [ ] Open questions log resolved or accepted with owners
- [ ] Pilot acceptance criteria met
- [ ] Formal acceptance memo issued by ULaval Corpus UL
- [ ] Post-transfer stewardship review scheduled

## Evidence Links

- Readiness report: TODO
- Reproducibility report: TODO
- Pilot report: TODO
- Acceptance memo: TODO
