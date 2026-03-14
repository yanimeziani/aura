# BRIEFING: The Sovereign Stack — Autonomous Multi-Agent Command Center
**Target Ingestion**: NotebookLM Deep Dive Podcast
**Context**: Fleet Commander / Sovereign Operator Briefing
**Status**: ACTIVE / DETERMINISTIC / ZERO-EMPLOYEE CONFIGURATION

---

## 1. The Core Vision: The Sovereign Stack
The "Sovereign Stack" is a philosophical and technical mandate to **own the entire request lifecycle**. It is designed for the "Fleet Commander" who operates with zero employees, relying instead on a ruthless documentation-first approach (BMAD) and a fleet of autonomous agents.

- **Total Ownership**: From the lowest network bytes (Zig-based edge) to the high-level frontend (Next.js 16), every component is either built in-house or strictly controlled.
- **Independence**: Zero dependency on third-party "Managed" services like Cloudflare or Tailscale Inc for core connectivity. The stack implements its own Mesh VPN and Edge protection.
- **The "Command Center" Energy**: Operating from a mobile cockpit (Samsung Z Fold) to manage a global infrastructure. It’s a "Mobile-to-Cloud" architecture where the phone is the staging ground and the VPS is the always-on executor.

---

## 2. The Runtime: Cerberus (Zig 0.15.2)
Cerberus is the high-performance, lightweight heartbeat of the agentic fleet.

- **Architecture**: A single, static Zig binary (<1MB) compiled with **Zig 0.15.2**. It is designed for microsecond latency and minimal resource overhead.
- **Agent Hosting**: Cerberus acts as the "host" for agentic intelligence, routing tasks to models like Claude 3.5 Sonnet and Llama 3.3 70B.
- **Tooling (MCP)**: Implements Model Context Protocol (MCP) servers in Zig and Python. These servers provide the agents with "hands"—the ability to read/write files, search the repo, and execute shell commands within a strictly confined `AURA_ROOT`.
- **Security**: Uses `std.crypto` (no OpenSSL) for TLS termination and secure communications.

---

## 3. The Control Plane: Pegasus & Android Cockpit
Pegasus is the bridge between the operator's intent and the agent's execution.

- **Mobile Cockpit**: A native Android application (Kotlin/Jetpack Compose) designed for one-handed operation and "night-ops" high-contrast UI.
- **HITL (Human-In-The-Loop)**: Every risky action (spending money, deploying code, sending external emails) is queued in Pegasus for the Commander's approval via a "Single Tap" interface.
- **Telemetry**: Real-time dashboards for cost monitoring (tokens/day), agent health, and infrastructure status.
- **Resilience**: Features a 30-day offline cache and automatic fallback channels for flaky mobile networks.

---

## 4. The Agents: Digital Twins and Revenue Generators
The stack currently deploys two primary agents, each serving a specific mission:

### A. Career Digital Twin
- **Mission**: Represent the founder to the world 24/7.
- **Stack**: Next.js 16, React 19 (Server Components), Supabase.
- **Capabilities**: Responds to employer inquiries, schedules interviews via calendar integration, and tracks job applications. It uses a 1,400-word system prompt to mirror the founder's expertise and professional "vibe."

### B. SDR Agent (Sales Development Representative)
- **Mission**: Autonomous B2B lead generation and outreach.
- **Logic**: Executes multi-touch email sequences (Initial → Follow-up #1 → Follow-up #2 → Breakup).
- **Compliance**: Built-in GDPR and CAN-SPAM compliance gates.
- **Engagement**: Tracks opens, replies, and bounces using the Resend API.

---

## 5. The Infrastructure: Aura-Edge & Sovereign Mesh
The infrastructure layer ensures the fleet remains reachable and secure without external gatekeepers.

- **Aura-Edge**: A Zig-based DDoS protection layer and HTTP listener. It filters packets at the edge before they hit the application logic.
- **Aura-Tailscale (Mesh VPN)**: A sovereign implementation of the WireGuard protocol in Zig. It creates a private, encrypted mesh network between the Commander's phone, staging machines, and production VPS.
- **Operational Stack**: Debian 12 (Bookworm) on the VPS, with **Nix (Flakes)** for reproducible runtime environments. Orchestration is handled via Ansible. Infrastructure is managed with a "GitOps 2.0" philosophy—every change is a commit.

---

## 6. Operational Principles: BMAD & Cost Discipline
The "Fleet Commander" operates under a strict code of conduct known as **BMAD (Build, Monitor, Automate, Document)**.

- **Ruthless Documentation**: Every agent action produces an artifact (diff, log, or decision summary). The system is designed to be "Open-Source-Ready" from day one.
- **Cost Discipline**: 
    - **Cheap Models First**: Llama-based models handle summarization and triage.
    - **Premium Models for Logic**: Claude 3.5 Sonnet is reserved for architecture and complex debugging.
    - **Hard Caps**: Automatic budget downgrades and "Panic Mode" (disabling non-essential agents) if daily spend limits are hit.
- **Safe Ops Only**: By default, agents cannot perform destructive operations. Escalation requires explicit, signed-off instructions from the Commander.

---

## 7. Technical Summary (The Stack)
- **Languages**: Zig 0.15.2 (Core), Kotlin (Mobile), TypeScript (Frontend), Python (Glue).
- **Frameworks**: Next.js 16, React 19, Jetpack Compose.
- **Database**: Supabase / PostgreSQL with Row-Level Security (RLS).
- **Communication**: WireGuard (Zig), TLS 1.3, MQTT 5.0.
- **Operating Model**: BMAD v6.

**"The system executes, reports, and escalates only when you say so. You own the wire, the tool, and the process."**
