# Nexa Architecture

## Purpose

Nexa is a collaboration and deployment stack for humans and AI systems operating across hostile, unstable, or vendor-controlled environments. The architecture is designed around five constraints:

- device loss is normal
- networks are hostile
- operators retain final authority
- agents need bounded autonomy
- recovery must be fast, portable, and deterministic

The project should be evaluated as protocol infrastructure, not as a generic application monorepo.

## System Model

Nexa is composed of six layers:

1. Identity and trust
2. Transport and routing
3. State and recovery
4. Execution and coordination
5. Applied Sovereignty (The Open Organisation)
6. Operator interfaces

Each layer must degrade safely when another layer is impaired.

## Layer 1: Identity and Trust

The trust layer establishes who can act, what they can do, and how authority is recovered or revoked.

Core primitives:

- operator identity
- device identity
- node identity
- agent identity
- organisation identity
- capability grants
- attestations
- revocation events

Rules:

- operator authority is primary
- agents never own sovereign authority
- device trust is replaceable
- identity must survive hardware replacement
- high-impact actions require explicit HITL confirmation

## Layer 2: Transport and Routing

Nexa must function over multiple transports without assuming a single trusted network.

Current transport classes:

- direct local transport
- VPS-hosted control transport
- Tor-routed egress
- IPFS publication and retrieval
- reconnect and catch-up transport for intermittently connected clients

Transport requirements:

- route selection must be explicit
- cloud-facing egress should be isolatable behind Tor
- content-addressed publication should be possible without exposing private state
- clients must resume from partial connectivity without losing session context

## Layer 3: State and Recovery

State is split into portable operator state, runtime state, and derived state.

Portable state:

- vault contents
- trust registry
- session continuity state
- documentation and runbooks
- deployment manifests

Derived state:

- caches
- logs
- telemetry aggregates
- temporary exports

Recovery invariant:

From a clean machine, an operator must be able to restore working control with bounded time, bounded secrets, and bounded manual steps.

## Layer 4: Execution and Coordination

Execution is agentic, but not unconstrained.

Execution model:

- agents operate through explicit tools and gateways
- external actions are mediated by capability checks
- destructive actions require HITL confirmation
- session state can be shared across CLI, TUI, dashboard, and remote nodes
- decisions must leave enough audit trail for recovery and review

Model routing requirements:

- shared multi-operator coding should default to the strongest collaborative coding model
- mobile and degraded execution should default to a smaller edge coding model
- parallel mobile agents should share one local runtime rather than one runtime per agent

The gateway is not merely an API proxy. It is the coordination membrane between operator intent, transport policy, shared state, and execution.

## Layer 5: Applied Sovereignty (The Open Organisation)

This layer translates abstract trust into vital services for all biological beings.

### Physical Sovereignty (Housing)
- Secure, accessible housing as a biological foundation.
- Shelter nodes within the mesh decouple living spaces from predatory financial infrastructure.
- Refer to [Open Organisation Housing Fundamentals](./OPEN_HOUSING_FUNDA.md).

### Cognitive Sovereignty (Education)
- Decentralized knowledge transmission through sovereign nodes.
- Age-specific pedagogy: **Montessori-only** (under 15) for foundations; **Technical Mastery** (15+) for Nexa stack specialization.
- Refer to [Open Organisation Education Fundamentals](./OPEN_EDUCATION_FUNDA.md).

### Resource Sovereignty (Distillation & Credits)
- **Lynx Distillation:** High-performance extraction of "essence" from noise using the Zig-based distillation engine.
- **Crypto Credits:** Sovereign resource management and pipeline for vital service funding.

## Layer 6: Operator Interfaces

Interfaces are replaceable clients over the same protocol surfaces.

Current interfaces:

- CLI
- TUI chat
- dashboard
- public docs/source bundle

Requirements:

- no interface may become the sole control point
- loss of one client must not destroy control continuity
- interfaces should reflect protocol state, not invent separate state

## Canonical Subsystems

- `Nexa Gateway`: routing, sync, provider mediation, HITL, transport controls
- `Nexa Vault`: portable operator state and key material
- `Nexa Mesh`: node-to-node coordination and continuity path
- `Nexa operator UI`: operator interface for status, approvals, and continuity
- `Nexa Docs`: technical source corpus for operators, models, and downstream synthesis

## Architectural Invariants

- operator authority outranks agent autonomy
- identity is portable; hardware is disposable
- sensitive state is never coupled to one device
- every destructive action has a deliberate trust boundary
- transport is multi-path, not single-provider
- public documentation is a technical source corpus, not marketing collateral
- recovery quality matters as much as feature count

## Current Refactor Direction

The codebase should continue moving toward:

- one canonical gateway contract
- one canonical vault layout
- one canonical docs bundle
- environment-driven deployment rather than host-specific assumptions
- explicit protocol docs before new feature sprawl

Legacy product-specific framing is tolerated only where migration is unfinished. New work should attach to Nexa's protocol architecture, not to old branding or narrow application stories.
