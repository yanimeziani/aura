# BRIEFING: Nexa Stack Overview
**Target Ingestion**: NotebookLM Deep Dive Podcast
**Context**: Operator briefing
**Status**: Active

---

## 1. Core Model
This stack is designed to keep the full request lifecycle inside operator-controlled infrastructure. It uses documentation, automation, and bounded agent execution to coordinate work across local and VPS environments.

- **Controlled stack**: Networking, runtime, frontend, and deployment paths remain inside the repository or clearly defined dependencies.
- **Self-hosting focus**: Core connectivity and control paths are designed to avoid unnecessary reliance on third-party managed platforms.
- **Mobile-to-cloud operation**: A phone acts as a reconnecting client while the VPS remains the always-on execution environment.

---

## 2. The Runtime: Cerberus (Zig 0.15.2)
Cerberus is the high-performance, lightweight heartbeat of the agentic fleet.

- **Architecture**: A single, static Zig binary (<1MB) compiled with **Zig 0.15.2**. It is designed for microsecond latency and minimal resource overhead.
- **Agent Hosting**: Cerberus acts as the "host" for agentic intelligence, routing tasks to models like Claude 3.5 Sonnet and Llama 3.3 70B.
- **Tooling (MCP)**: Implements Model Context Protocol (MCP) servers in Zig and Python. These servers provide the agents with "hands"—the ability to read/write files, search the repo, and execute shell commands within a strictly confined `AURA_ROOT`.
- **Security**: Uses `std.crypto` (no OpenSSL) for TLS termination and secure communications.

---

## 3. Control Plane: Pegasus & Android Client
Pegasus is the bridge between operator actions and agent execution.

- **Mobile client**: A native Android application (Kotlin/Jetpack Compose) for mobile access.
- **HITL (Human-In-The-Loop)**: Risky actions such as spending, deployment, or external communication require approval.
- **Telemetry**: Real-time dashboards for cost monitoring (tokens/day), agent health, and infrastructure status.
- **Resilience**: Features a 30-day offline cache and automatic fallback channels for flaky mobile networks.

---

## 4. Agent Workloads
The stack currently deploys two primary agents:

### A. Career Digital Twin
- **Purpose**: Represent a professional profile to external contacts.
- **Stack**: Next.js 16, React 19 (Server Components), Supabase.
- **Capabilities**: Responds to employer inquiries, schedules interviews via calendar integration, and tracks job applications.

### B. SDR Agent (Sales Development Representative)
- **Purpose**: B2B lead generation and outreach.
- **Logic**: Executes multi-touch email sequences (Initial → Follow-up #1 → Follow-up #2 → Breakup).
- **Compliance**: Built-in GDPR and CAN-SPAM compliance gates.
- **Engagement**: Tracks opens, replies, and bounces using the Resend API.

---

## 5. Infrastructure
The infrastructure layer keeps services reachable and auditable across local and remote environments.

- **Aura-Edge**: A Zig-based DDoS protection layer and HTTP listener. It filters packets at the edge before they hit the application logic.
- **Aura-Tailscale (Mesh VPN)**: A WireGuard-based implementation in Zig for private connectivity between phones, staging machines, and production VPS nodes.
- **Operational Stack**: Debian 12 on the VPS with reproducible runtime environments and scripted orchestration.

---

## 6. Operational Principles
The stack uses documentation, automation, and cost controls to keep changes auditable.

- **Documentation**: Agent actions produce artifacts such as diffs, logs, or decision summaries.
- **Cost Discipline**: 
    - **Cheap Models First**: Llama-based models handle summarization and triage.
    - **Premium Models for Logic**: Claude 3.5 Sonnet is reserved for architecture and complex debugging.
    - **Hard Caps**: Automatic budget downgrades and "Panic Mode" (disabling non-essential agents) if daily spend limits are hit.
- **Safe Ops Only**: By default, agents cannot perform destructive operations. Escalation requires explicit approval.

---

## 7. Technical Summary (The Stack)
- **Languages**: Zig 0.15.2 (Core), Kotlin (Mobile), TypeScript (Frontend), Python (Glue).
- **Frameworks**: Next.js 16, React 19, Jetpack Compose.
- **Database**: Supabase / PostgreSQL with Row-Level Security (RLS).
- **Communication**: WireGuard (Zig), TLS 1.3, MQTT 5.0.
- **Operating Model**: BMAD v6.

The system is designed to execute, report, and escalate according to explicit operator approval.
