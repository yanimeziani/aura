# Nexa Trust Model

## Goal

Define how Nexa grants authority, constrains agents, and limits blast radius under compromise, operator error, or network hostility.

## Trust Hierarchy

From highest to lowest authority:

1. operator intent
2. explicit operator-approved capabilities
3. trusted node and device identities
4. agent execution rights
5. external provider responses

Agents may act with delegated power, but they do not become the root of trust.

## Trust Boundaries

Primary trust boundaries in Nexa:

- operator to gateway
- gateway to provider
- operator to device
- device to node
- node to node
- agent to tool
- public artifact to private vault state

Every boundary should answer:

- who is authenticated
- what is authorized
- what is logged
- how it is revoked
- how it recovers after compromise

## HITL Policy

HITL is not a UX feature. It is a trust-boundary enforcement mechanism.

Actions that should require HITL by default:

- destructive state deletion
- trust-tier escalation or revocation
- organisation registry writes
- deployment to exposed infrastructure
- secret rotation
- outbound actions with financial, legal, or reputational consequences

HITL requirements:

- approval must be explicit
- approval must be scoped to a named action
- clients must not auto-retry gated actions with approval headers
- approval should be auditable

## Capability Design

Capabilities should be:

- minimal
- time-bounded
- scope-bounded
- revocable
- attributable to an issuer

Avoid broad permanent grants such as:

- full filesystem write
- unrestricted remote shell
- unrestricted outbound messaging
- trust-registry mutation without approval

## Identity Recovery

Recovery must assume devices can be lost, seized, wiped, or replaced.

Requirements:

- sovereign authority is not tied to one device
- replacement devices can be reintroduced without rewriting the whole system
- compromised device trust can be revoked
- recovery steps are documented and reproducible

## Provider Trust

External model providers are useful but untrusted.

Implications:

- model output is advisory until accepted into state or action
- secrets should not be over-shared
- routing through Tor or other controlled transport should remain available
- provider outage must not destroy operator continuity

## Organisation Trust

Organisation trust is incremental.

Suggested ladder:

- `unverified`
- `domain_verified`
- `registry_verified`
- `sovereign_attested`

Rules:

- trust changes are events, not hidden fields
- stronger trust tiers require stronger evidence
- revocation is normal and must be supported cleanly

## Audit Expectations

Nexa should preserve enough information to answer:

- who approved an action
- what capability was used
- what state changed
- what transport path was involved
- how the action can be traced or reversed

Logs are useful, but trust should not depend on log retention alone. Important transitions should be represented as explicit state changes or attestations.
