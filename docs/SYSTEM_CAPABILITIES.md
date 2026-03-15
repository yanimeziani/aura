# Aura: System Capabilities & Agent Architecture

## Overview

Aura provides a high-efficiency framework for autonomous agent orchestration, specializing in two primary functional domains: external profile representation (Career-Twin) and automated business development (SDR).

## 1. Career-Twin Agent Persona

**Purpose**: An autonomous agent representing a technical profile to external entities, handling professional inquiries, scheduling, and transaction tracking.

### Technical Deliverables
- **Persona Configuration**: Cerberus logic defined in `core/cerberus/configs/career-twin-agent.json`.
- **System Prompts**: Technical profile and logic in `core/cerberus/runtime/cerberus-core/prompts/career_twin_prompt.txt`.
- **Memory Structure**: Initialized via `core/cerberus/scripts/init-career-twin-memory.sh`.
- **Aura Web Interface**: Management dashboard in `apps/web/app/[locale]/career-twin/`.
- **API Endpoints**: REST-based coordination in `apps/web/app/api/career-twin/`.
- **Data Schema**: Supabase migration in `apps/web/supabase/migrations/20260303000001_career_twin_tables.sql`.
- **System Spec**: Technical architecture in `core/cerberus/specs/career-digital-twin.md`.

### Functional Capabilities
- **Technical Profile Management**: Autonomous handling of skills, projects, and professional history.
- **Inquiry Processing**: Automated, context-aware responses to external technical or professional questions.
- **Engagement Tracking**: Database-backed monitoring of application and inquiry status.
- **Scheduling Coordination**: Integration with calendar protocols (ICS) for automated interview or meeting scheduling.
- **HITL Verification**: Mandatory approval gates for all outbound communications.

---

## 2. SDR Agent Persona

**Purpose**: An automated Sales Development Representative (SDR) for prospect research, communication drafting, and multi-touch engagement sequences.

### Technical Deliverables
- **Persona Configuration**: Cerberus logic in `core/cerberus/configs/sdr-agent.json`.
- **System Prompts**: Outreach logic in `core/cerberus/runtime/cerberus-core/prompts/sdr_agent_prompt.txt`.
- **Memory Structure**: Initialized via `core/cerberus/scripts/init-sdr-memory.sh`.
- **Data Schema**: Supabase migration in `apps/web/supabase/migrations/20260303000002_sdr_tables.sql`.
- **System Spec**: Technical architecture in `core/cerberus/specs/sdr-agent.md`.

### Functional Capabilities
- **Prospect Research**: Autonomous analysis of company data, funding rounds, and technical stacks.
- **Communication Synthesis**: Context-aware drafting of personalized outreach using a multi-model approach (e.g., Claude, Llama).
- **Sequence Orchestration**: Multi-stage follow-up logic with automated timing and engagement triggers.
- **Engagement Telemetry**: Real-time tracking of delivery status, opens, and replies via Resend API.
- **Compliance Enforcement**: Integrated CAN-SPAM and GDPR logic for secure, legal outreach.

---

## Technical Performance & Security

### Performance Metrics
- **Cerberus Runtime Latency**: <50ms for local logic execution.
- **Model Coordination**: Dynamic routing based on task complexity (Claude Sonnet 4 for synthesis, Llama 3.3 for research).
- **Resource Usage**: <1MB binary footprint for the Cerberus core.

### Security & Sovereignty
- **Strict Zero-Trust Architecture**: Every network interface is treated as a hostile environment. (Note: TOR and IPFS layers are currently in active development/planned for future release).
- **Encrypted Memory**: Local-first storage for all sensitive agent memory.
- **RLS Policies**: Row-Level Security ensures data isolation and access control.
- **HITL Gates**: Mandatory human oversight for high-risk agent actions.
- **Audit Logging**: Comprehensive logging for all agent decisions and external interactions.

### Project Status & Implementation
- **Supabase Migrations**: ✅ Career-Twin (20260303000001) and SDR (20260303000002) tables initialized.
- **Core Scripts**: ✅ Memory initialization and deployment automation verified.
- **Web Interface**: 🛠 Integration with new agent tables in progress.
