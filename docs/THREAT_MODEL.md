# Nexa Threat Model

## Assumption Set

Nexa is built for adversarial conditions, not convenience-only environments.

Assume:

- endpoints can be lost or seized
- networks can be surveilled or filtered
- providers can fail, throttle, or leak
- operators can make mistakes
- agents can overreach if poorly bounded
- public-facing systems will be probed continuously

## Protected Assets

- vault contents
- operator authority
- trust registry
- deployment credentials
- session continuity state
- approval records
- private operational context

Secondary assets:

- telemetry
- public docs bundle integrity
- transport policy
- node availability

## Threat Classes

### Device compromise

Examples:

- lost phone
- stolen laptop
- forensic seizure
- malware on operator endpoint

Required response:

- revoke device trust
- recover from another device
- preserve operator continuity without trusting the lost hardware

### Network observation or censorship

Examples:

- ISP surveillance
- hostile public Wi-Fi
- provider-level filtering
- region-based blocking

Required response:

- alternate transport paths
- Tor-routed egress where appropriate
- ability to resume work after degraded connectivity

### Gateway abuse

Examples:

- unauthenticated action attempts
- oversized or malicious payloads
- path traversal style abuse
- replay of destructive requests

Required response:

- strict validation
- capability checks
- HITL for destructive actions
- bounded payload sizes

### Agent overreach

Examples:

- an agent performs destructive actions without approval
- an agent leaks sensitive state into external providers
- an agent mutates trust or deployment state too broadly

Required response:

- tool scoping
- approval gates
- constrained capability design
- auditability of executed actions

### State corruption or drift

Examples:

- invalid session state
- mismatched deployment assumptions
- stale trust entries
- split-brain between clients

Required response:

- canonical state locations
- deterministic recovery paths
- sync semantics that tolerate reconnection

## Security Posture

Nexa should prefer:

- default-deny for high-impact actions
- explicit routing over implicit fallback
- portable state over host-local snowflakes
- revocation support over trust permanence
- technical source documentation over undocumented operator folklore

## Immediate Hardening Priorities

The architecture suggests the following priorities for future implementation:

- formalize identity objects and capability schemas
- sign or otherwise strongly authenticate trust-changing events
- reduce legacy path and environment ambiguity
- make session recovery and device recovery first-class flows
- continue bounding transport-facing endpoints
- consolidate canonical config and state layouts

## Non-Goals

Nexa is not trying to guarantee perfect secrecy or eliminate all operator error. The goal is controlled failure: bounded blast radius, recoverable state, explicit authority, and resilient collaboration under imperfect conditions.
