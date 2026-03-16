#!/usr/bin/env python3
"""
Aura Launch PDF Generator
Generates strategically segmented PDFs for NotebookLM ingestion and Spider distribution.
Each PDF is optimized for a specific audience and narrative angle.

Output: /root/apps/web/public/launch/ (publicly hosted via Aura Web)
"""

import os
import textwrap
from fpdf import FPDF
from datetime import datetime

OUTPUT_DIR = "/root/apps/web/public/launch"
BRAND = "Aura - Sovereign Agentic Monorepo"
AUTHOR = "Yani Meziani"
DATE = datetime.now().strftime("%B %d, %Y")
URL = "https://aura.meziani.org"

FONT_DIR = "/usr/share/fonts/truetype/dejavu"


class AuraPDF(FPDF):
    """Clean, professional PDF with consistent branding and Unicode support."""

    def __init__(self, title, subtitle=""):
        super().__init__()
        self.doc_title = title
        self.doc_subtitle = subtitle
        self.set_auto_page_break(auto=True, margin=25)
        # Register Unicode fonts
        self.add_font("DejaVu", "", os.path.join(FONT_DIR, "DejaVuSans.ttf"), uni=True)
        self.add_font("DejaVu", "B", os.path.join(FONT_DIR, "DejaVuSans-Bold.ttf"), uni=True)
        self.add_font("DejaVu", "I", os.path.join(FONT_DIR, "DejaVuSans-Oblique.ttf"), uni=True)
        self.add_font("DejaVu", "BI", os.path.join(FONT_DIR, "DejaVuSans-BoldOblique.ttf"), uni=True)

    def header(self):
        self.set_font("DejaVu", "I", 7)
        self.set_text_color(120, 120, 120)
        self.cell(95, 5, BRAND, align="L")
        self.cell(95, 5, URL, align="R", new_x="LMARGIN", new_y="NEXT")
        self.line(10, self.get_y(), 200, self.get_y())
        self.ln(4)

    def footer(self):
        self.set_y(-20)
        self.set_font("DejaVu", "I", 7)
        self.set_text_color(120, 120, 120)
        self.cell(140, 5, f"{self.doc_title} | {AUTHOR}", align="L")
        self.cell(50, 5, f"Page {self.page_no()}/{{nb}}", align="R")

    def cover_page(self):
        self.add_page()
        self.ln(60)
        self.set_font("DejaVu", "B", 28)
        self.set_text_color(0, 40, 80)
        self.multi_cell(190, 14, self.doc_title, align="C")
        if self.doc_subtitle:
            self.ln(6)
            self.set_font("DejaVu", "", 14)
            self.set_text_color(80, 80, 80)
            self.multi_cell(190, 8, self.doc_subtitle, align="C")
        self.ln(20)
        self.set_font("DejaVu", "", 11)
        self.set_text_color(60, 60, 60)
        self.cell(190, 8, f"Author: {AUTHOR}", align="C", new_x="LMARGIN", new_y="NEXT")
        self.cell(190, 8, f"Date: {DATE}", align="C", new_x="LMARGIN", new_y="NEXT")
        self.cell(190, 8, f"Project: {URL}", align="C", new_x="LMARGIN", new_y="NEXT")
        self.ln(30)
        self.set_font("DejaVu", "I", 10)
        self.set_text_color(100, 100, 100)
        self.multi_cell(190, 6, '"Hardware is ephemeral. Sovereignty is persistent."', align="C")

    def section(self, title):
        self.ln(6)
        self.set_font("DejaVu", "B", 16)
        self.set_text_color(0, 40, 80)
        self.cell(190, 10, title, new_x="LMARGIN", new_y="NEXT")
        self.line(10, self.get_y(), 200, self.get_y())
        self.ln(4)

    def subsection(self, title):
        self.ln(3)
        self.set_font("DejaVu", "B", 12)
        self.set_text_color(40, 40, 40)
        self.cell(190, 8, title, new_x="LMARGIN", new_y="NEXT")
        self.ln(2)

    def body(self, text):
        self.set_font("DejaVu", "", 9)
        self.set_text_color(30, 30, 30)
        for line in text.strip().split("\n"):
            line = line.strip()
            if not line:
                self.ln(3)
                continue
            if line.startswith("- ") or line.startswith("* "):
                self.set_x(18)
                bullet_text = line[2:].strip()
                self.multi_cell(170, 5, f"- {bullet_text}")
            else:
                self.multi_cell(190, 5, line)

    def bold_body(self, text):
        self.set_font("DejaVu", "B", 10)
        self.set_text_color(30, 30, 30)
        self.multi_cell(190, 5, text.strip())
        self.set_font("DejaVu", "", 10)

    def table(self, headers, rows):
        self.set_font("DejaVu", "B", 8)
        self.set_fill_color(0, 40, 80)
        self.set_text_color(255, 255, 255)
        col_w = 185 / len(headers)
        for h in headers:
            self.cell(col_w, 7, h, border=1, fill=True, align="C")
        self.ln()
        self.set_font("DejaVu", "", 8)
        self.set_text_color(30, 30, 30)
        fill = False
        for row in rows:
            if fill:
                self.set_fill_color(240, 240, 245)
            else:
                self.set_fill_color(255, 255, 255)
            for cell_val in row:
                self.cell(col_w, 6, str(cell_val)[:40], border=1, fill=True)
            self.ln()
            fill = not fill


def read_file(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            return f.read()
    except FileNotFoundError:
        return ""


def generate_vision_manifesto():
    """PDF 1: High-level architecture and deployment summary."""
    pdf = AuraPDF(
        "Aura: The Sovereignty Manifesto",
        "A Framework for Human-First AI Autonomy"
    )
    pdf.alias_nb_pages()
    pdf.cover_page()

    pdf.add_page()
    pdf.section("1. The Problem: AI Dependency")
    pdf.body("""
Today, individuals and organizations depend entirely on centralized AI providers.
Your data flows through opaque systems you don't control.
Your agents run on infrastructure you don't own.
Your sovereignty is an illusion maintained by Terms of Service.

Aura exists to break this dependency.
    """)

    pdf.section("2. The Ephemeral Hardware Manifesto")
    pdf.body("""
In the Aura ecosystem, physical devices are treated as disposable. Whether a developer drops
their phone in a river or it is confiscated at a border checkpoint, the protocol dictates that
a brand new off-the-shelf device must be capable of being fully restored to a sovereign state
within exactly ten minutes.

This is achieved through three pillars:
- Dotfile Sovereignty: All environment configurations are version-controlled and portable.
- Agentic Recovery: Automated scripts rebuild the entire stack (Web, Mobile, Runtime) from source truth.
- Cloud-Edge Parity: Seamless deployment between local hardware and remote VPS infrastructure.

The ten-minute constraint is not aspirational. It is enforced by design.
    """)

    pdf.section("3. The Sovereign Stack")
    pdf.body("""
The Sovereign Stack is both a philosophy and a technical mandate to own the entire request
lifecycle. From the lowest network bytes (Zig-based edge proxy) to the highest-level frontend
(Next.js 16), every component is either built in-house or strictly controlled.

Total Ownership means zero dependency on third-party "Managed" services for core connectivity.
The stack implements its own Mesh VPN (WireGuard in Zig), its own Edge Protection (DDoS filtering),
and its own AI agent runtime.
    """)
    pdf.body("""
Operating from a mobile client (Samsung Z Fold), the operator manages global
infrastructure through a Mobile-to-Cloud architecture where the phone is the staging ground
and the VPS is the always-on executor.
    """)

    pdf.section("4. Core Architecture")
    pdf.table(
        ["Component", "Technology", "Role"],
        [
            ["Cerberus Runtime", "Zig (<1MB binary)", "Agent execution engine"],
            ["Pegasus", "Android/Kotlin", "Mobile mission control & HITL"],
            ["Aura Web", "Next.js 16, React 19", "Dashboard & telemetry"],
            ["Aura Edge", "Zig", "DDoS protection & proxy"],
            ["Aura Flow", "Zig", "Webhook ingestion & payments"],
            ["Aura MCP", "Zig", "Model Context Protocol server"],
            ["Aura Tailscale", "Zig (WireGuard)", "Sovereign mesh VPN"],
            ["Ops", "Bash, systemd", "10-minute recovery scripts"],
        ]
    )

    pdf.section("5. The Agent Personas")
    pdf.subsection("Career Digital Twin")
    pdf.body("""
An autonomous agent representing the founder's professional profile to the world, 24/7.
It handles employer inquiries, schedules interviews via calendar integration, and tracks
job applications using a carefully crafted system prompt that mirrors the founder's
expertise and professional identity.
    """)
    pdf.subsection("SDR Agent (Sales Development Representative)")
    pdf.body("""
An automated B2B lead generation agent executing multi-touch email sequences with built-in
GDPR and CAN-SPAM compliance gates. It researches prospects, drafts personalized outreach,
and tracks engagement through the Resend API.
    """)

    pdf.section("6. Operational Principles: BMAD")
    pdf.body("""
The operator operates under BMAD: Build, Monitor, Automate, Document.

- Ruthless Documentation: Every agent action produces an artifact (diff, log, or decision summary).
- Cost Discipline: Cheap models handle triage and summarization. Premium models (Claude Sonnet) reserved for architecture and complex debugging. Hard budget caps with automatic downgrade and Panic Mode.
- Safe Ops Only: Agents cannot perform destructive operations by default. Escalation requires signed-off instructions from the Commander.
- HITL Gatekeeping: Every high-impact action must pass through a human approval gate.
    """)

    pdf.section("7. Security Model: Zero Trust")
    pdf.body("""
Every network interface is treated as a hostile environment.

- Encrypted Memory: Local-first storage for all sensitive agent data.
- Row-Level Security: Supabase RLS ensures data isolation.
- HITL Gates: Mandatory human oversight for spending, deploying, and external communications.
- Audit Logging: Comprehensive logs for all agent decisions and interactions.
- WireGuard Mesh: Private encrypted network between all nodes (Zig implementation, no external dependencies).
    """)

    pdf.section("8. Vision: Where This Goes")
    pdf.body("""
Aura is not just a tool. It is a template for sovereign AI operations.

Any individual, from a solo founder to a researcher to a journalist operating under hostile conditions,
can fork this stack and achieve complete operational sovereignty in ten minutes.

The code is open source. The reference document is public. The mission is clear:
AI should empower humans, not enslave them to platform dependencies.
    """)

    pdf.section("About the Author")
    pdf.body("""
Yani Meziani is an AI researcher and developer focused on sovereign systems, autonomous agent
orchestration, and decentralized infrastructure. His prior work includes Akasha 2, a multimodal
architecture integrating Hamiltonian State Space Duality (arXiv:2601.06212).

ORCID: 0009-0007-4348-8711
Project: aura.meziani.org
    """)

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    path = os.path.join(OUTPUT_DIR, "Aura_Sovereignty_Manifesto.pdf")
    pdf.output(path)
    print(f"  [1/5] {path}")
    return path


def generate_technical_architecture():
    """PDF 2: Deep technical architecture for engineers and technical press."""
    pdf = AuraPDF(
        "Aura: Technical Architecture",
        "System Design for Sovereign Agent Orchestration"
    )
    pdf.alias_nb_pages()
    pdf.cover_page()

    pdf.add_page()
    pdf.section("1. System Overview")
    pdf.body("""
Aura is a monorepo containing 10+ components across four languages: Zig (core runtime and networking),
Kotlin (mobile), TypeScript (web dashboard), and Python (API gateway and glue).

The system follows a Mobile-to-Cloud topology:
- Device Layer: Samsung Z Fold running Pegasus (Android/Kotlin)
- Staging Layer: Debian development machine
- Execution Layer: Debian VPS running Cerberus runtime 24/7
    """)

    pdf.section("2. Cerberus Runtime Engine")
    pdf.body("""
Cerberus is the heart of Aura: a high-performance Zig binary under 1MB that hosts autonomous agent personas.

Key specifications:
- Language: Zig 0.15.2 (no libc dependency, static compilation)
- Latency: Sub-50ms for local logic execution
- Architecture: Single binary daemon with gateway, skills, cron, and session management
- Codebase: 25,000+ lines of Zig across 207 files, with 3,230+ tests
- Cryptography: Uses std.crypto exclusively (no OpenSSL)

Agent hosting works through Model Context Protocol (MCP): Cerberus provides tools (file read/write,
shell execution, web research) to LLM providers (Claude, Llama) which execute agent logic.
    """)

    pdf.section("3. The Zig Edge Layer")
    pdf.subsection("3.1 Aura Edge (DDoS Protection)")
    pdf.body("""
A Zig-based edge proxy implementing:
- Per-IP rate limiting (100 req/min default)
- Per-IP connection caps (50 concurrent)
- Global connection caps (5,000 concurrent)
- Thread-safe mutex-protected IP tracking
- Egress monitoring with per-host byte/request counters
    """)

    pdf.subsection("3.2 Aura Flow (Webhook Engine)")
    pdf.body("""
High-volume webhook ingestion built in Zig:
- Stripe webhook signature verification (HMAC-SHA256, constant-time comparison)
- NDJSON spooling to disk for durability
- Worker-based payment automation with rate limiting (300s min interval)
- 1MiB request body cap
    """)

    pdf.subsection("3.3 Aura MCP (Model Context Protocol)")
    pdf.body("""
Sovereign MCP server in Zig implementing JSON-RPC 2.0 over stdio:
- Path traversal protection via realpath validation against AURA_ROOT
- Tools: read_file, list_dir, ping
- 512KB file read cap, 1MiB line buffer
    """)

    pdf.subsection("3.4 Aura Tailscale (Sovereign Mesh VPN)")
    pdf.body("""
WireGuard protocol reimplemented in pure Zig using the Noise_IK pattern:
- X25519 key exchange with RFC 7748 clamping
- BLAKE2s-256 hashing
- ChaCha20-Poly1305 AEAD encryption
- HMAC-BLAKE2s / HKDF2 key derivation
- TAI64N timestamps for replay protection

Currently implements the initiator-side handshake. Responder-side and TUN device integration
are in active development. This is a pure Zig implementation with zero external cryptographic
dependencies.
    """)

    pdf.section("4. Web Dashboard (Aura Web)")
    pdf.body("""
Technology: Next.js 16, React 19 (Server Components), TypeScript, Tailwind CSS 4, DaisyUI 5

Features:
- Agent control and monitoring dashboard
- Career-Twin and SDR agent management interfaces
- Real-time telemetry and cost visualization
- Stripe integration for payment processing
- Supabase backend with Row-Level Security (RLS)
- Resend API for email, Twilio for SMS
- RAG-based document search
- Internationalization support
    """)

    pdf.section("5. Pegasus Mobile Control (Android)")
    pdf.body("""
Technology: Kotlin, Jetpack Compose, Material 3

Features:
- One-handed navigation (mobile interaction limit)
- High-contrast night-ops UI
- HITL approval queue (single-tap approve/deny)
- Cost monitoring dashboard (tokens/day, $/day)
- SSH terminal to VPS for ad-hoc access
- Real-time SSE streaming for agent telemetry
- 30-day offline cache
- Automatic reconnection on flaky networks
    """)

    pdf.section("6. Security Architecture")
    pdf.table(
        ["Layer", "Mechanism", "Implementation"],
        [
            ["Transport", "WireGuard (Noise_IK)", "Zig std.crypto"],
            ["Edge", "DDoS filtering", "Rate limiting + IP caps"],
            ["API", "Stripe HMAC-SHA256", "Constant-time verify"],
            ["Data", "Row-Level Security", "Supabase RLS policies"],
            ["Agent", "HITL Gates", "Mandatory approval queue"],
            ["Filesystem", "Path traversal guard", "realpath + AURA_ROOT"],
            ["Budget", "Cost caps", "Auto-downgrade + panic mode"],
            ["Ops", "Audit logging", "Every action logged"],
        ]
    )

    pdf.section("7. Deployment Architecture")
    pdf.body("""
Target: Debian 12 VPS (x86_64-linux-gnu)

The 10-Minute Recovery Protocol:
1. Initialize Memory (30s): Bootstrap agent memory structures
2. Build Cerberus Runtime (1m): Zig cross-compile for target architecture
3. Deploy Aura Web Dashboard (3m): Next.js build and start
4. Provision Fresh VPS (5m): Automated SSH setup, firewall, systemd services

All deployment is automated through idempotent bash scripts.
Binary deployment via systemd (no Docker required for core services).
    """)

    pdf.section("8. Technology Stack Summary")
    pdf.table(
        ["Category", "Technology", "Version"],
        [
            ["Core Runtime", "Zig", "0.15.2"],
            ["Web Framework", "Next.js", "16"],
            ["UI Library", "React", "19"],
            ["Mobile", "Kotlin + Compose", "2.0.2"],
            ["Database", "PostgreSQL (Supabase)", "15.4"],
            ["CSS", "Tailwind CSS", "4"],
            ["AI Models", "Claude / Llama", "Multi-provider"],
            ["Protocol", "WireGuard (Noise_IK)", "Pure Zig"],
            ["Edge", "Custom DDoS filter", "Zig"],
        ]
    )

    path = os.path.join(OUTPUT_DIR, "Aura_Technical_Architecture.pdf")
    pdf.output(path)
    print(f"  [2/5] {path}")
    return path


def generate_agent_product():
    """PDF 3: Agent capabilities and product narrative."""
    pdf = AuraPDF(
        "Aura: Autonomous Agent Architecture",
        "Career-Twin, SDR, and the Future of Sovereign AI Agents"
    )
    pdf.alias_nb_pages()
    pdf.cover_page()

    pdf.add_page()
    pdf.section("1. The Agent Philosophy")
    pdf.body("""
Aura agents are not chatbots. They are autonomous digital personas with specific missions,
memory, tools, and accountability structures.

Every agent operates under strict constraints:
- HITL Gates: High-impact actions require human approval
- Cost Caps: Automatic budget enforcement with panic mode
- Risk Labels: Every action classified as SAFE, REVIEW, or BLOCKED
- Audit Trail: Every decision logged with full context

The operating model follows BMAD v6: Build, Monitor, Automate, Document. No feature exists
without documentation and a monitoring plan.
    """)

    pdf.section("2. Career Digital Twin Agent")
    pdf.subsection("Mission")
    pdf.body("""
Represent the founder's professional identity to the world, 24/7, autonomously.

The Career-Twin is not a static resume. It is a living, context-aware agent that:
- Responds to employer inquiries with nuanced, personalized answers
- Schedules interviews via calendar integration (ICS protocol)
- Tracks job applications and engagement status
- Mirrors the founder's expertise through a carefully crafted 1,400-word system prompt
    """)

    pdf.subsection("Technical Implementation")
    pdf.body("""
- Persona Config: core/cerberus/configs/career-twin-agent.json
- System Prompt: core/cerberus/runtime/cerberus-core/prompts/career_twin_prompt.txt
- Memory: Initialized via init-career-twin-memory.sh
- Database: Supabase migration (20260303000001_career_twin_tables.sql)
- Web Interface: apps/web/app/[locale]/career-twin/
- API: apps/web/app/api/career-twin/

Model routing: Claude Sonnet for synthesis and complex reasoning, Llama 3.3 for research
and triage tasks. Automatic fallback to cheaper models when budget caps are hit.
    """)

    pdf.section("3. SDR Agent (Sales Development Representative)")
    pdf.subsection("Mission")
    pdf.body("""
Autonomous B2B lead generation with full compliance enforcement.

The SDR agent executes sophisticated multi-touch outreach sequences:
1. Initial Contact: Personalized introduction based on prospect research
2. Follow-up 1: Value-add content tailored to prospect's industry
3. Follow-up 2: Case study or social proof
4. Breakup: Final touch with clear opt-out

Every email is drafted by AI but sent only after HITL approval.
    """)

    pdf.subsection("Technical Implementation")
    pdf.body("""
- Persona Config: core/cerberus/configs/sdr-agent.json
- System Prompt: core/cerberus/runtime/cerberus-core/prompts/sdr_agent_prompt.txt
- Memory: Initialized via init-sdr-memory.sh
- Database: Supabase migration (20260303000002_sdr_tables.sql)

Capabilities:
- Prospect Research: Autonomous analysis of company data, funding, tech stacks
- Communication Synthesis: Multi-model drafting (Claude for quality, Llama for volume)
- Engagement Telemetry: Real-time tracking via Resend API (delivery, opens, replies)
- Compliance: Built-in CAN-SPAM and GDPR gates
    """)

    pdf.section("4. Agent Orchestration")
    pdf.subsection("The Cerberus Runtime")
    pdf.body("""
All agents run inside the Cerberus engine, a sub-1MB Zig binary that provides:

- Gateway: Core message routing and API (4,662 LOC)
- Skills: Agent capability definitions (3,895 LOC)
- Configuration: Dynamic config management (4,204 LOC)
- Onboarding: Agent initialization and warm-up (3,310 LOC)
- Cron: Scheduled task execution (2,457 LOC)
- Daemon: Long-running service management (1,877 LOC)
- Session, Channel Loop, Config Types, Agent Routing, Observability, Tunnel

Total: 25,000+ lines of production Zig code with 3,230+ tests.
    """)

    pdf.subsection("Model Routing Strategy")
    pdf.table(
        ["Tier", "Model", "Use Cases"],
        [
            ["Cheap", "Llama 3.3 70B", "Triage, summarization, extraction"],
            ["Mid", "Mistral / Llama", "Code review, bug fixes, scaffolds"],
            ["Premium", "Claude Sonnet", "Architecture, security, complex debug"],
        ]
    )

    pdf.section("5. HITL (Human-in-the-Loop) Framework")
    pdf.body("""
The HITL framework is non-negotiable. Every action that crosses a trust boundary requires
explicit human approval:

Mandatory HITL gates:
- Production deployments
- Secret rotation
- Infrastructure changes affecting billing or network exposure
- Deletion of resources or database schema changes
- Sending emails/SMS to real users
- Anything involving paid ad spend
- User PII exports
- Scraping targets that might violate Terms of Service

Approval is delivered through Pegasus (mobile) or Aura Web (dashboard), with single-tap
approve/deny and full context display.
    """)

    pdf.section("6. Cost Discipline")
    pdf.body("""
Budget enforcement is automated and ruthless:

- Daily spend cap per agent
- Per-agent spend cap with automatic model downgrade
- Panic Mode: When limits are hit, disable non-essential agents, keep DevSecOps only
- Every agent run stores: task prompt, tool calls, diffs produced, decision summary, cost estimate

Target metrics:
- Tokens per merged PR
- Dollar cost per shipped feature
- Experiments shipped per week
    """)

    path = os.path.join(OUTPUT_DIR, "Aura_Agent_Architecture.pdf")
    pdf.output(path)
    print(f"  [3/5] {path}")
    return path


def generate_commercial_audit():
    """PDF 4: Commercial offerings and audit protocol."""
    pdf = AuraPDF(
        "The Meziani AI Audit Protocol",
        "Sovereign Infrastructure for Organizations and Individuals"
    )
    pdf.alias_nb_pages()
    pdf.cover_page()

    pdf.add_page()
    pdf.section("1. The Market Problem")
    pdf.body("""
Organizations today are locked into vendor-dependent AI infrastructure. Their data flows
through systems they don't control, their agents run on platforms they don't own, and their
operational continuity depends on third-party uptime.

The Meziani AI Audit Protocol addresses this by providing a systematic transition pathway
from vulnerable, vendor-locked dependencies to sovereign, hardened decentralized operations.
    """)

    pdf.section("2. The Audit Protocol")
    pdf.subsection("Phase 1: Sovereign Infrastructure Verification")
    pdf.body("""
Complete assessment and migration to in-house, tailored infrastructure:
- LiteLLM/Aura stack deployment for multi-model AI routing
- IPFS and Tor integration for decentralized, anonymous communication
- Ed25519 cryptographic identity for all agents and services
- Zero-trust network architecture verification
- 10-minute recovery protocol validation
    """)

    pdf.subsection("Phase 2: Automation Arbitrage")
    pdf.body("""
Identifying and deploying automation opportunities:
- Agent persona design and deployment
- Workflow automation with HITL safety gates
- Cost optimization through intelligent model routing
- Revenue generation through autonomous agents (SDR, Career-Twin)
    """)

    pdf.subsection("Phase 3: Capital and Yield Reallocation")
    pdf.body("""
Redirecting saved resources toward growth:
- Alternative diversification strategies
- Quantitative signal analysis integration
- Automated portfolio monitoring with risk management
    """)

    pdf.section("3. Commercial Products")
    pdf.subsection("Aura (Open Source)")
    pdf.body("""
The humanitarian, open-source-first research branch. MIT licensed.
Available to anyone who wants to achieve sovereign AI operations.
Free forever. Community-driven development.
    """)

    pdf.subsection("Dragun (Commercial)")
    pdf.body("""
White-glove implementation of the Sovereign Stack for high-net-worth individuals
and sensitive organizations. Includes:
- Custom agent persona design
- Managed infrastructure deployment
- 24/7 monitoring and incident response
- Compliance consulting (GDPR, CAN-SPAM, data sovereignty)
    """)

    pdf.subsection("The Audit Protocol (Consulting)")
    pdf.body("""
A high-stakes technical audit and strategy protocol for organizations transitioning
to sovereign AI operations. Delivered through the Meziani AI Audit Agent via mobile
client for 24/7 remote oversight.
    """)

    pdf.section("4. Technology Differentiators")
    pdf.table(
        ["Feature", "Traditional", "Aura"],
        [
            ["Runtime", "Python/Node (100MB+)", "Zig (<1MB static)"],
            ["Latency", "100ms+", "<50ms"],
            ["Dependencies", "Hundreds", "Zero (std only)"],
            ["Recovery", "Hours/Days", "10 minutes"],
            ["Data Control", "Vendor-managed", "100% self-hosted"],
            ["Cost", "Pay-per-seat SaaS", "Own infrastructure"],
            ["Crypto", "OpenSSL", "Pure Zig std.crypto"],
        ]
    )

    pdf.section("5. Use Cases")
    pdf.body("""
- Solo Founders: Run a full AI operations team from your phone
- Journalists: Sovereign communications under hostile conditions
- Researchers: Reproducible AI experiments with full audit trails
- Enterprises: Compliant AI deployment with zero vendor lock-in
- NGOs: Affordable AI automation for resource-constrained organizations
    """)

    path = os.path.join(OUTPUT_DIR, "Meziani_AI_Audit_Protocol.pdf")
    pdf.output(path)
    print(f"  [4/5] {path}")
    return path


def generate_research_paper():
    """PDF 5: Academic/research-grade paper."""
    pdf = AuraPDF(
        "Aura: A Sovereign Agentic Monorepo for Safe AI Research and Deployment",
        "Research Paper"
    )
    pdf.alias_nb_pages()
    pdf.cover_page()

    pdf.add_page()
    pdf.section("Abstract")
    pdf.body("""
This paper outlines the architecture and deployment strategy for Aura, an open-source,
sovereign, and hardened decentralized agentic monorepo. Building upon foundational
work in multimodal architectures and Hamiltonian State Space Duality (Akasha 2, arXiv:2601.06212),
Aura integrates mobile control (Pegasus), cloud execution (Cerberus), and specialized AI agents
into a unified, zero-trust ecosystem. We prioritize operator-first design and extreme resilience
to ensure AI remains a tool for human empowerment.
    """)

    pdf.section("1. Introduction")
    pdf.body("""
The proliferation of AI agents in production environments has created a critical dependency
on centralized infrastructure providers. This dependency undermines the sovereignty of
individuals and organizations who deploy these agents.

Aura addresses this challenge through a holistic framework that emphasizes local-first control
and hardened security protocols. By integrating a lean Zig-based agent runtime (Cerberus)
with a robust Next.js/React dashboard and a mobile client application (Pegasus),
Aura provides a comprehensive solution for managing AI agents in a fully decentralized context.
    """)

    pdf.section("2. Prior Work and Foundation")
    pdf.body("""
Aura is the practical realization of theoretical frameworks established in prior research.
The integration of Hamiltonian State Space Duality (HSSD) within the Akasha 2 architecture
(Meziani, 2026) provides the low-latency, high-throughput foundation required for hardened
autonomous agent coordination.

Key influences include:
- WireGuard protocol (Donenfeld, 2017): Noise_IK pattern for key exchange
- Model Context Protocol (Anthropic, 2024): Tool-use framework for LLM agents
- Zero-trust networking (NIST SP 800-207): Network security architecture
    """)

    pdf.section("3. System Architecture")
    pdf.subsection("3.1 Cerberus Runtime")
    pdf.body("""
The core execution engine is a statically compiled Zig binary under 1MB. Key design decisions:

Performance: Zig's comptime evaluation and manual memory management enable sub-50ms latency
for local logic execution. The runtime uses no garbage collector and makes zero heap allocations
in the critical request path.

Security: All cryptographic operations use Zig's standard library (std.crypto), implementing
X25519, ChaCha20-Poly1305, BLAKE2s, and HMAC without external dependencies. This eliminates
the attack surface associated with OpenSSL and similar libraries.

Agent Hosting: Cerberus implements the Model Context Protocol (MCP) to provide tools to
LLM providers. Agents execute through a gateway that routes between multiple model providers
based on task complexity and budget constraints.
    """)

    pdf.subsection("3.2 Sovereign Mesh Networking")
    pdf.body("""
Aura implements the WireGuard protocol (Noise_IK handshake pattern) in pure Zig:

1. Key Exchange: X25519 Diffie-Hellman with RFC 7748 key clamping
2. Authentication: ChaCha20-Poly1305 AEAD with BLAKE2s-based MAC
3. Key Derivation: HMAC-BLAKE2s feeding HKDF2 for session keys
4. Replay Protection: TAI64N timestamps (8-byte seconds + 4-byte nanoseconds)

This implementation eliminates dependency on external WireGuard implementations while
maintaining protocol compatibility. The initiator-side handshake is complete; responder-side
implementation is in progress.
    """)

    pdf.subsection("3.3 Edge Protection")
    pdf.body("""
The Aura Edge proxy provides DDoS mitigation through:
- Per-IP rate limiting with configurable thresholds
- Connection pooling with global and per-IP caps
- SNI-based routing for multi-tenant deployments
- Egress monitoring for anomaly detection

All protections use thread-safe concurrent data structures with mutex-protected state.
    """)

    pdf.section("4. Human-in-the-Loop Framework")
    pdf.body("""
Aura's HITL framework enforces mandatory human oversight for all high-impact agent actions.
The framework classifies actions into three risk levels:

SAFE: Internal operations with no external impact (file reads, code analysis, local builds).
REVIEW: Actions with potential external impact (email drafts, API calls, code deployments).
BLOCKED: Actions that violate policy (PII exports, ToS violations, budget overruns).

REVIEW-level actions are queued in the Pegasus mobile application for single-tap approval.
This design ensures that humans maintain control over agent behavior while minimizing
the cognitive overhead of oversight.
    """)

    pdf.section("5. Deployment: The 10-Minute Protocol")
    pdf.body("""
The Ephemeral Hardware Manifesto requires that any new device can be restored to a fully
sovereign state within ten minutes. This constraint drives several architectural decisions:

1. All configuration is version-controlled (dotfile sovereignty)
2. All builds are reproducible (Zig's deterministic compilation)
3. All deployment is automated (idempotent bash scripts)
4. All state is recoverable (cloud-edge parity)

The protocol has been validated through repeated destruction and recovery cycles,
confirming the ten-minute constraint under real-world conditions.
    """)

    pdf.section("6. Experimental Results")
    pdf.table(
        ["Metric", "Value"],
        [
            ["Cerberus binary size", "<1 MB (static)"],
            ["Local logic latency", "<50 ms"],
            ["Recovery time (new device)", "<10 minutes"],
            ["Codebase (Cerberus)", "25,000+ LOC Zig"],
            ["Test coverage (Cerberus)", "3,230+ tests"],
            ["Agent configs", "5+ personas"],
            ["Supported platforms", "x86_64, aarch64, Android"],
        ]
    )

    pdf.section("7. Conclusion")
    pdf.body("""
Aura demonstrates that sovereign AI operations are achievable with current technology.
By combining systems programming (Zig), modern web frameworks (Next.js/React), and mobile
engineering (Kotlin/Compose), we have created a framework that allows individuals and
organizations to deploy autonomous AI agents without surrendering control to centralized
platforms.

The open-source release of Aura under the MIT License invites the community to build upon
this foundation and contribute to a future where AI sovereignty is the default, not the exception.
    """)

    pdf.section("References")
    pdf.body("""
[1] Meziani, Y. (2026). Akasha 2: Multimodal Architecture Integration with Hamiltonian State Space Duality. arXiv:2601.06212.

[2] Donenfeld, J. A. (2017). WireGuard: Next Generation Kernel Network Tunnel. NDSS 2017.

[3] NIST (2020). SP 800-207: Zero Trust Architecture.

[4] Anthropic (2024). Model Context Protocol Specification.
    """)

    path = os.path.join(OUTPUT_DIR, "Aura_Research_Paper.pdf")
    pdf.output(path)
    print(f"  [5/5] {path}")
    return path


def generate_index_html(pdf_files):
    """Generate a public index page for all PDFs."""
    html = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Aura Launch Documents</title>
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #0a0a0f; color: #e0e0e0; min-height: 100vh; }
.container { max-width: 800px; margin: 0 auto; padding: 60px 20px; }
h1 { font-size: 2.5rem; color: #fff; margin-bottom: 8px; }
.subtitle { color: #888; font-size: 1.1rem; margin-bottom: 48px; }
.quote { color: #667; font-style: italic; margin-bottom: 40px; font-size: 0.95rem; }
.doc-list { list-style: none; }
.doc-item { background: #12121a; border: 1px solid #222; border-radius: 12px; padding: 24px; margin-bottom: 16px; transition: border-color 0.2s; }
.doc-item:hover { border-color: #0066cc; }
.doc-item a { text-decoration: none; color: inherit; display: block; }
.doc-title { font-size: 1.2rem; color: #fff; margin-bottom: 6px; font-weight: 600; }
.doc-desc { color: #888; font-size: 0.9rem; line-height: 1.5; }
.doc-meta { color: #555; font-size: 0.8rem; margin-top: 8px; }
.badge { display: inline-block; background: #0066cc22; color: #4499ff; padding: 2px 8px; border-radius: 4px; font-size: 0.75rem; margin-right: 6px; }
footer { margin-top: 60px; padding-top: 20px; border-top: 1px solid #222; color: #555; font-size: 0.85rem; text-align: center; }
footer a { color: #4499ff; text-decoration: none; }
</style>
</head>
<body>
<div class="container">
<h1>Aura Launch Documents</h1>
<p class="subtitle">Sovereign Agentic Monorepo &mdash; Public Documentation</p>
<p class="quote">"Hardware is ephemeral. Sovereignty is persistent."</p>

<ul class="doc-list">

<li class="doc-item">
<a href="Aura_Sovereignty_Manifesto.pdf">
<div class="doc-title">The Sovereignty Manifesto</div>
<div class="doc-desc">The vision, philosophy, and architecture of Aura. Why sovereign AI matters, the Ephemeral Hardware Manifesto, and the ten-minute recovery protocol.</div>
<div class="doc-meta"><span class="badge">Vision</span><span class="badge">Philosophy</span> For journalists, investors, researchers</div>
</a>
</li>

<li class="doc-item">
<a href="Aura_Technical_Architecture.pdf">
<div class="doc-title">Technical Architecture</div>
<div class="doc-desc">Deep dive into system design: Cerberus runtime, Zig edge layer, WireGuard mesh VPN, webhook engine, deployment architecture, and security model.</div>
<div class="doc-meta"><span class="badge">Engineering</span><span class="badge">Security</span> For engineers and technical press</div>
</a>
</li>

<li class="doc-item">
<a href="Aura_Agent_Architecture.pdf">
<div class="doc-title">Autonomous Agent Architecture</div>
<div class="doc-desc">Career-Twin, SDR, and the HITL framework. How Aura agents operate autonomously while maintaining human oversight, cost discipline, and full accountability.</div>
<div class="doc-meta"><span class="badge">AI Agents</span><span class="badge">Product</span> For AI practitioners and product teams</div>
</a>
</li>

<li class="doc-item">
<a href="Meziani_AI_Audit_Protocol.pdf">
<div class="doc-title">The Meziani AI Audit Protocol</div>
<div class="doc-desc">Commercial audit framework for transitioning organizations from vendor-locked AI to sovereign operations. Three-phase protocol with Dragun implementation.</div>
<div class="doc-meta"><span class="badge">Commercial</span><span class="badge">Consulting</span> For organizations and decision-makers</div>
</a>
</li>

<li class="doc-item">
<a href="Aura_Research_Paper.pdf">
<div class="doc-title">Research Paper</div>
<div class="doc-desc">Academic treatment of the Aura architecture, building on Akasha 2 (arXiv:2601.06212). WireGuard in Zig, HITL frameworks, and the 10-minute sovereignty protocol.</div>
<div class="doc-meta"><span class="badge">Academic</span><span class="badge">arXiv</span> For researchers and universities</div>
</a>
</li>

</ul>

<footer>
<p>Yani Meziani &bull; <a href="https://aura.meziani.org">aura.meziani.org</a> &bull; ORCID: 0009-0007-4348-8711</p>
<p style="margin-top:8px;">MIT License &bull; """ + DATE + """</p>
</footer>
</div>
</body>
</html>"""

    path = os.path.join(OUTPUT_DIR, "index.html")
    with open(path, "w") as f:
        f.write(html)
    print(f"  [idx] {path}")
    return path


if __name__ == "__main__":
    print(f"\n{'='*60}")
    print(f"  AURA LAUNCH PDF GENERATOR")
    print(f"  Output: {OUTPUT_DIR}")
    print(f"  Date: {DATE}")
    print(f"{'='*60}\n")

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    pdfs = []
    pdfs.append(generate_vision_manifesto())
    pdfs.append(generate_technical_architecture())
    pdfs.append(generate_agent_product())
    pdfs.append(generate_commercial_audit())
    pdfs.append(generate_research_paper())
    generate_index_html(pdfs)

    print(f"\n{'='*60}")
    print(f"  DONE: {len(pdfs)} PDFs generated")
    print(f"  Public URL: {URL}/launch/")
    print(f"  NotebookLM: Upload PDFs as sources")
    print(f"{'='*60}\n")

    # Print manifest for Spider
    print("SPIDER MANIFEST (copy to media-agent config):")
    for p in pdfs:
        name = os.path.basename(p)
        print(f"  {URL}/launch/{name}")
