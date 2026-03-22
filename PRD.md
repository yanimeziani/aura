# Product Requirements Document - FocusFeed NetSafe Mesh Scaffold

**Author:** Codex
**Date:** 2026-03-18
**Status:** Draft for scaffold planning
**Scope:** Full distribution across all supported platforms

## 1. Executive Summary

FocusFeed NetSafe Mesh is a distributed governance and content integrity platform. The initial scaffold must establish a production-oriented foundation for a Zig backend runtime and a Kotlin frontend stack that can distribute a consistent citizen and leadership experience across Android, desktop, and web targets.

The product starts with restricted access for consensus-validated world leaders, one isolated cluster per leader, while preserving a longer-term path toward a global citizen portal. The system must enforce a Layer 0 content firewall, provenance-aware AI labeling, safety-first policy enforcement, and governance rules that include First Nations representation and balanced participation principles throughout the framework.

This PRD defines the requirements for the first scaffold only. It is intended to produce a working architecture skeleton, core interfaces, delivery boundaries, and a phased implementation plan rather than a full production build.

## 2. Product Vision

Build a mesh-native platform where trusted content, governance, and controlled access are embedded into the core runtime instead of added as peripheral moderation tools. Every distributed node, client, and cluster should share the same trust model, provenance model, and governance constraints.

## 3. Problem Statement

Current digital platforms suffer from five structural failures:

1. False and manipulated content enters systems before trust checks occur.
2. AI-generated content is often unlabeled or weakly attributed.
3. Governance participation is opaque and unevenly distributed.
4. Distributed systems are fragmented across platform-specific clients.
5. Public-interest systems lack a reliable global citizen interface.

The scaffold must solve these failures at the architecture level by making trust enforcement, provenance, and cluster isolation part of the core product shape.

## 4. Goals

### 4.1 Primary Goals

- Establish FocusFeed as a Layer 0 content firewall in the platform architecture.
- Scaffold a Zig backend that can evolve into a distributed mesh runtime.
- Scaffold a Kotlin frontend architecture for full distribution across platforms.
- Limit initial cluster access to consensus-validated world leaders.
- Support one isolated cluster per validated leader.
- Require provenance-aware content headers for AI and synthetic content.
- Preserve a clear path toward a world citizen portal in later phases.

### 4.2 Secondary Goals

- Encode governance requirements early, including First Nations representation across the framework.
- Make safety-first policy enforcement explicit in the system design.
- Ensure personal human experience remains prioritized over automated optimization.
- Define boundaries for future board review items such as SaveOSAP and similar governance submissions.

## 5. Non-Goals for the Initial Scaffold

- Open citizen onboarding at global scale.
- Full production-grade consensus engine.
- Final legal policy language for all jurisdictions.
- Complete mobile, desktop, and browser feature parity on day one.
- A finished moderation or misinformation classifier.
- A finalized public election, voting, or treasury system.

## 6. Users and Access Model

### 6.1 Phase 1 Users

- Consensus-validated world leaders
- Board members
- Governance operators
- Trust and safety operators

### 6.2 Future Users

- Citizens
- Regional delegates
- First Nations representatives in dedicated governance workflows
- Researchers and auditors

### 6.3 Access Principles

- Access is denied by default.
- Each validated leader receives one dedicated cluster.
- Cross-cluster access is prohibited unless explicitly approved by governance policy.
- Board-level oversight functions must be auditable.
- Citizen-facing surfaces remain scaffolded but locked until later phases.

## 7. Product Principles

- Safety first
- Human experience over system convenience
- Provenance before amplification
- Trust before distribution
- Representation embedded across the governance framework
- Full-platform availability from a shared product model
- Strong isolation between clusters

## 8. Platform Distribution Strategy

The scaffold must be designed for full distribution across all platforms using a shared contract model and a shared UX system.

### 8.1 Backend Distribution

- Zig services run as independent deployable components.
- Services must support edge, regional, and central deployment profiles.
- Mesh communication patterns must be explicit, versioned, and auditable.

### 8.2 Frontend Distribution

The frontend stack will be Kotlin-first to support broad distribution:

- Android app via Kotlin Multiplatform
- Desktop app via Compose Multiplatform
- Web client via Kotlin/Wasm or a Kotlin-compatible web target
- Shared domain, networking, auth, policy, and state layers across targets

### 8.3 Distribution Requirement

No core user flow should be specified in a way that only works on a single platform. Every MVP requirement must identify:

- which platforms are in scope
- which shared modules power the flow
- which platform-specific adaptations are required

## 9. High-Level Architecture

### 9.1 Core Components

- `mesh-gateway`: entry point for mesh traffic
- `focusfeed-firewall`: Layer 0 content intake and blocking service
- `provenance-service`: parses and validates content headers
- `cluster-registry`: manages leader-to-cluster assignments
- `consensus-validator`: determines validated access state
- `policy-engine`: enforces governance and safety rules
- `identity-service`: handles actor identity and credentials
- `audit-log`: immutable event trail
- `citizen-portal-api`: future public-facing interface, scaffolded only

### 9.2 Client Components

- `client-shared`: Kotlin shared domain and networking layer
- `client-android`: Android shell
- `client-desktop`: desktop shell
- `client-web`: browser shell
- `design-system`: shared UI tokens, accessibility rules, and state conventions

### 9.3 Architectural Principles

- API-first contracts
- event-driven audit trail
- strong cluster isolation
- provenance-aware content rendering
- offline-tolerant client state where practical
- no trust decision hidden solely in frontend code

## 10. Functional Requirements

### 10.1 Identity and Access

- The system must authenticate board members, operators, and validated leaders.
- The system must support a validation state for leaders that is independent from simple login state.
- The system must bind each validated leader to a dedicated cluster.
- The system must block access when a leader is not consensus-validated.
- The system must expose an auditable access decision trail.

### 10.2 Cluster Management

- The system must create isolated logical clusters.
- The system must assign content, policy, and communication streams to the correct cluster.
- The system must prevent unauthorized cluster crossover.
- The system must allow board-approved cross-cluster review workflows with full audit logging.

### 10.3 Layer 0 Content Firewall

- All incoming content must pass through the Layer 0 firewall before entering a cluster.
- The firewall must classify content as accepted, flagged, quarantined, or blocked.
- The firewall must support provenance checks before content is made visible to users.
- The firewall must provide machine-readable reasons for quarantine or rejection.
- The firewall must expose moderation outcomes to the audit system.

### 10.4 AI Content Provenance

- The system must require headers or structured metadata for AI-generated or synthetic content where available.
- The system must display origin, creator, timestamp, and content type to users.
- The system must differentiate verified provenance from missing or unverified provenance.
- The system must allow policy rules that downgrade or block unlabeled synthetic content.

### 10.5 Governance Framework

- The system must model board participation roles.
- The governance framework must explicitly support First Nations representation requirements.
- The governance framework must support balanced participation rules, including future 50/50 representation policies where configured by governance.
- The system must support board review workflows for submissions, proposals, and policy artifacts.

### 10.6 Citizen Portal Scaffold

- The scaffold must reserve a citizen portal entry point in backend and client routing.
- The Citizen Portal must be a **World Model AR Experience UI/UX**, providing an immersive, spatial view of the Mesh's state and biological safety invariants.
- Future public services must be able to reuse the same identity, provenance, and policy layers.

### 10.7 Content Experience

- Users must see clear trust status for content.
- Users must see whether content is human-authored, AI-generated, synthetic, or unknown.
- Users must be able to inspect metadata for source and time of creation.
- Clients must render content consistently across supported platforms.

## 11. Platform-Specific Requirements

### 11.1 Android

- Provide secure sign-in and session persistence.
- Support push notifications for governance events and trust alerts.
- Maintain acceptable performance on mid-range devices.

### 11.2 Desktop

- Provide a high-information-density operator interface.
- Support multi-panel workflows for board review and cluster monitoring.
- Support secure local caching for non-sensitive session state.

### 11.3 Web

- Provide browser-based access for rapid distribution.
- Preserve provenance and trust indicators in responsive layouts.
- Support PWA installation for lighter deployments.

## 12. Backend Technical Requirements

### 12.1 Zig Runtime

- Backend services must be scaffolded in Zig.
- Service boundaries must be explicit and independently buildable.
- The repo must support local development, integration testing, and release packaging for each Zig service.
- Shared protocol definitions must be centralized to avoid drift across services.

### 12.2 APIs and Contracts

- External and internal APIs must be versioned.
- Contracts must support content ingestion, validation status, cluster membership, policy decisions, and audit trails.
- API definitions must be generated or documented in a machine-readable format.

### 12.3 Data and Persistence

- The data model must capture identities, clusters, provenance, policy decisions, and audit events.
- Sensitive data categories must be tagged for stricter handling.
- The scaffold must define a path for append-only audit storage.

## 13. Frontend Technical Requirements

### 13.1 Kotlin Architecture

- Frontend scaffold must be Kotlin-based.
- Shared Kotlin modules must own domain models, API clients, auth state, feature flags, and provenance rendering rules.
- Platform shells must remain thin and reuse shared modules wherever possible.

### 13.2 UI System

- A shared design system must define trust badges, provenance cards, policy warnings, and governance workflow states.
- Accessibility must be planned from the start, including readable status color contrast and non-color trust indicators.
- Platform shells may adapt layout, but not semantics, for trust-critical UI.

## 14. Security and Trust Requirements

- Zero-trust assumptions for all inbound content
- auditability for every trust decision
- signed or verifiable provenance where available
- least-privilege access for every actor role
- secure defaults in every client
- no silent downgrade of blocked or quarantined content

## 15. Compliance and Governance Requirements

- Governance rules must be configurable without rewriting all clients.
- Board workflows must support review, approval, rejection, and escalation states.
- The system must preserve human override paths for consequential trust decisions.
- Policy changes must be traceable to an approving authority.

## 16. Observability Requirements

- Every service must emit structured logs.
- Trust decisions must be traceable end to end.
- Cluster-level health and access events must be observable.
- The scaffold must define metrics for ingestion, blocking, quarantine, access denial, and client errors.

## 17. Success Metrics

### 17.1 Scaffold Completion Metrics

- Zig backend services compile and run locally.
- Kotlin shared modules compile for targeted platforms.
- Android, desktop, and web shells can authenticate against the scaffold environment.
- Leader-to-cluster assignment is enforced end to end.
- Firewall ingestion flow returns trust decisions and provenance state.
- Audit events are produced for critical actions.

### 17.2 Product Readiness Metrics

- Time to scaffold a new cluster is below a defined operational threshold.
- 100% of displayed AI content in test flows carries visible provenance state.
- Unauthorized cross-cluster access attempts are blocked in all integration tests.
- Shared frontend module coverage remains high enough to prevent platform drift.

## 18. Release Phases

### Phase 0: PRD and Contract Baseline

- finalize service map
- define shared protocol models
- define Kotlin module boundaries
- define trust and provenance vocabulary

### Phase 1: Scaffold Foundation

- create Zig service skeletons
- create Kotlin shared modules
- create Android, desktop, and web shells
- wire identity, cluster registry, and audit logging stubs

### Phase 2: Trust Flow MVP

- implement Layer 0 content ingestion
- implement provenance parsing and UI rendering
- enforce leader validation and cluster isolation
- expose core operator dashboards

### Phase 3: Governance MVP

- add board workflows
- add representation-aware governance policy configuration
- add policy engine decisions to user-facing flows

### Phase 4: Citizen Portal Preview

- open limited citizen portal routes
- test public-safe content views
- prepare broader distribution strategy

## 19. Initial Repository Scaffold

The scaffold should target a structure similar to:

```text
/core
  /mesh-gateway
  /focusfeed-firewall
  /provenance-service
  /cluster-registry
  /consensus-validator
  /policy-engine
  /identity-service
  /audit-log
  /protocol
/clients
  /shared
  /android
  /desktop
  /web
/docs
  /architecture
  /protocols
  /governance
  /operations
/infra
  /local
  /staging
  /production
```

## 20. Risks

- Governance scope may expand faster than the implementation model.
- Kotlin web target choices may change as platform constraints become clearer.
- Consensus validation may require more legal and operational definition than assumed here.
- Provenance standards may vary across jurisdictions and providers.
- Cluster isolation requirements may force stricter infrastructure boundaries than an initial scaffold expects.

## 21. Open Questions

- ~~What exact mechanism determines consensus-validated leader status in phase 1?~~ **Resolved:** Candidate leaders are chosen and validated by successfully passing the Universal Mesh Wargame (Operation De-Escalator) with a 0% casualty probability, after which they are issued their ML-KEM hardware keys.
- Which Kotlin web target is preferred for the first scaffold: Kotlin/Wasm, Compose HTML, or a limited wrapper strategy?
- What persistence stack will back the Zig services in the first deployable milestone?
- Which board actions require multi-party approval versus operator execution?
- Which citizen portal features must exist as visible placeholders in the first release?

## 22. Acceptance Criteria for This PRD

This PRD is implementation-ready when:

- scaffold ownership boundaries are clear
- Zig backend service responsibilities are named
- Kotlin client module boundaries are named
- cross-platform distribution expectations are explicit
- MVP trust, provenance, and cluster requirements are testable
- rollout phases are ordered and bounded

## 23. Immediate Next Step

Use this PRD to generate:

1. repository scaffold plan
2. shared protocol specification
3. Zig service skeleton backlog
4. Kotlin Multiplatform module plan
5. MVP delivery board
