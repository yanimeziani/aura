# ULaval Corpus UL Transfer Protocol

Status: Draft v0.1 (initiated)  
Scope: Full repository transfer and institutional onboarding package for ULaval Corpus UL

## 1) Purpose

This protocol defines a complete, auditable, and reversible transfer path from Nexa maintainers to ULaval Corpus UL for academic review, research collaboration, and controlled operational use.

The protocol is designed to:
- preserve provenance and attribution for all open-source dependencies and borrowed concepts
- provide reproducible technical handover artifacts
- document legal, ethical, security, and governance boundaries
- support phased acceptance by institutional stakeholders

## 2) Transfer Principles

- Transparency first: all claims must be traceable to source documents, commits, or upstream projects.
- Least privilege: transfer only the access required at each phase.
- Reproducibility: ULaval reviewers must be able to rebuild and verify from documented steps.
- Reversibility: every operational change in transfer phases must have rollback instructions.
- Attribution compliance: every external OSS source must be cited with license and usage context.

## 3) Actors and Responsibilities

- Transfer Authority (Nexa Maintainers)
  - prepares package, signs off integrity, maintains source-of-truth until final acceptance
- Receiving Authority (ULaval Corpus UL)
  - performs technical, legal, and research review; issues acceptance records
- Security Review Team
  - validates threat model fit, incident channels, and key handling procedures
- Documentation Custodian
  - ensures every artifact has revision history and citation traceability

## 4) Protocol Phases

### Phase A - Pre-Transfer Readiness

Required outcomes:
- repository baseline captured (commit hash, branch state, release manifest)
- architecture and protocol documentation frozen for handover window
- OSS source register completed (see `docs/transfer/OSS_SOURCE_REGISTER.md`)
- legal/licensing checks completed (SPDX and NOTICE completeness)

Exit artifacts:
- `docs/transfer/HANDOVER_PACKAGE_INDEX.md`
- signed readiness checklist (see `docs/transfer/TRANSFER_CHECKLIST.md`)

### Phase B - Controlled Knowledge Transfer

Required outcomes:
- guided technical walkthroughs of architecture, trust model, threat model, and recovery model
- reproducible setup verified by receiving team on clean environment
- clarification log recorded for all open technical questions

Exit artifacts:
- walkthrough notes and Q&A decisions
- reproducibility validation report

### Phase C - Operational Pilot

Required outcomes:
- pilot environment boundaries documented (data class, access levels, network boundaries)
- security controls tested (credential handling, incident paths, rollback procedures)
- governance pilot process validated (change control and approval paths)

Exit artifacts:
- pilot completion report
- risk register with mitigation ownership

### Phase D - Acceptance and Stewardship

Required outcomes:
- formal acceptance decision by ULaval Corpus UL
- stewardship model documented (maintainer responsibilities, escalation tree, release cadence)
- post-transfer governance review scheduled

Exit artifacts:
- acceptance memo
- stewardship charter

## 5) Mandatory Documentation Set

At minimum, the transfer package must include:
- repository snapshot metadata (commit hash, timestamp, signed digest)
- architecture/protocol/trust/threat documentation references
- build and verification runbook
- security policy and disclosure channel
- governance and contribution policy
- full OSS citation register with licenses and usage mapping

## 6) Integrity and Provenance Controls

- Record the exact repository state:
  - git commit hash
  - tree checksum of transfer package
  - generation timestamp and operator identity
- Keep a manifest of included files and their checksums
- Maintain a decision log for any exclusions from transfer bundle

## 7) OSS Citation and Attribution Requirements

All external OSS inputs must be tracked in:
- `docs/transfer/OSS_SOURCE_REGISTER.md`

Each record must include:
- project name and canonical URL
- version or commit pin used
- license type
- where it is used in this repository
- whether source was modified
- attribution text and NOTICE requirements

No phase can be marked complete if citation records are incomplete.

## 8) Security and Data Handling

- Do not transfer secrets, personal credentials, production tokens, or private keys.
- Use `.env.example` as reference only; receiving team generates fresh credentials.
- Any sample data transferred must be non-sensitive and documented by classification.

## 9) Completion Criteria

Transfer is complete only when all are true:
- checklist items in `docs/transfer/TRANSFER_CHECKLIST.md` are marked complete
- OSS source register coverage is complete and reviewed
- receiving authority signs acceptance memo
- post-transfer governance schedule is confirmed

## 10) Revision Log

- v0.1 - Initial protocol initiated for ULaval Corpus UL transfer formalization.
