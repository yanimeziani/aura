---
title: 'Communications Architecture Essentials (Email + SMS)'
slug: 'communications-architecture-essentials-email-sms'
created: '2026-02-27T01:06:00Z'
status: 'in-progress'
stepsCompleted: [1]
tech_stack:
  - Next.js API routes
  - TypeScript
  - Provider adapters (Resend, Twilio)
files_to_modify:
  - lib/comms/**
  - app/api/comms/**
  - README.md
  - ENVIRONMENT.md
code_patterns:
  - Provider abstraction via channel adapters
  - Runtime env validation per provider
  - Normalized send result envelope
test_patterns:
  - API smoke test endpoint
  - Lint/build checks
---

# Overview

## Problem Statement
Dragun needs a reliable communications foundation for collections outreach, starting with high-leverage channels (email + SMS) while enabling future escalation channels (AI voice calls) without rewriting core flows.

## Solution
Implement a BMAD-first essential architecture with a provider-agnostic communications core and two production adapters: Resend (email) and Twilio (SMS). Keep channel contracts unified so voice AI can plug in as a third adapter.

## Scope

### In Scope (Essentials)
- Unified comms module with channel contracts and normalized results
- Email delivery via Resend
- SMS delivery via Twilio
- Auth-protected test endpoint for delivery smoke tests
- Env contracts + docs for setup and operations
- Delivery and error telemetry structure for debtor timeline integration

### Out of Scope (Planned Next)
- Full campaign orchestration and retry queues
- Deliverability optimization layer (domain warmup, dedicated IP strategy)
- AI outbound voice calling production flow
- Multi-provider failover and routing rules engine

# Context for Development

## Constraints
- Must not disrupt current debtor/merchant flows
- Secrets must remain env-only
- Keep design mobile/API-first and extensible
- Comply with quiet hours / consent / do-not-contact policy in future orchestration layer

## Architectural Direction
- `lib/comms/types.ts`: channel-agnostic contracts
- `lib/comms/providers/*`: isolated provider clients
- `lib/comms/index.ts`: dispatch + normalized outputs
- `app/api/comms/test/route.ts`: guarded operational smoke endpoint

## Planned Extension Path (Post-Essentials)
1. Add voice_ai adapter contract
2. Add policy engine (consent + local window + retry caps)
3. Add sequencing orchestrator (email→sms→voice)
4. Add debtor-outcome event model (contacted, promised-to-pay, dispute, wrong number)
