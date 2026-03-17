# Nexa Protocol

## Scope

This document defines the protocol-level primitives that Nexa should expose regardless of implementation language or client surface.

Nexa is a protocol for secure collaboration between operators, agents, nodes, and organisations across unstable networks. For applied examples of how these trust primitives secure vital infrastructure, refer to the Open Organisation Fundamentals: [Housing](./OPEN_HOUSING_FUNDA.md), [Education](./OPEN_EDUCATION_FUNDA.md), and [Commerce](./OPEN_COMMERCE_FUNDA.md).

Machine-readable counterparts live in:

- `specs/protocol.json`
- `specs/trust.json`
- `specs/recovery.json`

The implementation should prefer those specs for runtime validation and client/tooling integration.

## Actors

- **Operator:** Any authorised biological being or community node fulfilling the role of a final authority. The operator role is collective, not individual, and is bound by the mandate of acting for the good of all biological beings.
- **Agent:** Bounded executor acting through capabilities delegated by the collective of operators.
- **Node:** Runtime host participating in the mesh; nodes can act as independent observers or consensus participants.
- **Organisation:** An external or internal collective with a trust state verifiable through the mesh.
- **Gateway:** Coordination surface for transport, sync, and the enforcement of collective trust policies.

## Core Objects

### Identity

Every actor should have a stable identifier and an optional rotating transport presence.

Examples:

- operator ID
- node ID
- device ID
- agent ID
- organisation ID
- workspace ID

### Capability

A capability is a bounded permission grant.

Minimum fields:

- subject
- issuer
- action set
- resource scope
- expiry
- revocation reference

### Attestation

An attestation is a signed or operator-confirmed statement about an identity, organisation, node, or state transition.

Examples:

- domain verified
- registry verified
- sovereign operator attested
- session recovered

### Session

A session is shared continuity state for active work.

Properties:

- addressable by workspace ID
- readable across clients
- deletable only under explicit authority
- suitable for catch-up after disconnection

### Artifact

An artifact is content produced or referenced by the system.

Examples:

- documentation
- audit record
- model output
- deployment manifest
- IPFS-published object

## Protocol Surfaces

### Health and discovery

Purpose:

- determine liveness
- inspect provider and transport availability
- expose safe operator diagnostics

### Session sync

Purpose:

- share state across CLI, TUI, dashboard, and remote execution surfaces
- support intermittent connectivity
- support catch-up without re-running prior work

### HITL gating

Purpose:

- force explicit approval for destructive, trust-changing, or outside-mesh actions

Contract:

- client attempts action
- gateway rejects with HITL-required state if approval missing
- operator approves with deliberate confirmation token or header
- gateway executes and records result

### Transport control

Purpose:

- inspect and change transport posture
- rotate Tor circuits
- publish operator-approved content to IPFS
- retrieve content-addressed artifacts

### Model routing

Purpose:

- expose one canonical collaboration model posture across clients and operators
- distinguish shared collaborative inference from edge/mobile fallback inference
- preserve continuity under degraded device and network conditions

### Organisation trust

Purpose:

- record organisation presence
- verify claims through domain, registry, or operator attestation
- revoke trust when needed

## Protocol States

Nexa should model explicit state transitions instead of hiding them in app logic.

Examples:

- `unverified -> domain_verified`
- `domain_verified -> registry_verified`
- `registry_verified -> sovereign`
- `session_active -> session_recovered`
- `pending_action -> hitl_required -> approved -> executed`
- `node_online -> node_degraded -> node_recovered`

## Protocol Guarantees

- no agent action should silently bypass operator authority
- no single client should be required to retain session continuity
- transport choice should not redefine trust
- public artifacts should be separable from private state
- revocation must be possible after compromise or misconfiguration

## Implementation Guidance

In the current codebase, the gateway is the first protocol surface. Over time, protocol behavior should become less coupled to specific UI clients and more explicitly represented in schemas, signed objects, and state transitions.

The implementation target is not a monolithic app. It is an interoperable, operator-controlled protocol layer with replaceable clients and transports.
