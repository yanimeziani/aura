#!/usr/bin/env bash
set -euo pipefail

# Initialize Career Digital Twin memory structure

MEMORY_DIR="${HOME}/.cerberus/memory/career_twin"

echo "Creating Career Digital Twin memory structure at: ${MEMORY_DIR}"

mkdir -p "${MEMORY_DIR}"/{applications,conversations}

# Create profile.md
cat > "${MEMORY_DIR}/profile.md" <<'EOF'
# Career Profile: Yani Meziani

## Identity
- **Name**: Yani Meziani
- **Role**: Founder & Full-Stack Engineer
- **Tagline**: Building AI-powered tools with Zig/TypeScript/Next.js
- **Location**: Remote-first
- **Availability**: Open to remote opportunities

## Contact
- **Email**: yani@example.com (replace with real)
- **LinkedIn**: linkedin.com/in/yanimeziani (replace with real)
- **GitHub**: github.com/yanimeziani (replace with real)
- **Portfolio**: dragun.app

## Professional Summary
Solo founder and full-stack engineer with expertise in systems programming, web development, and AI agent orchestration. Built production systems spanning mobile, web, and cloud infrastructure with focus on cost efficiency, security, and automation.

## Current Focus
- Building Cerberus: Zig-based AI assistant runtime (<1MB binary)
- Building Pegasus: Kotlin/Android mission control for Cerberus agents
- Dragun.app SaaS application
- Job search: Seeking remote full-stack or founding engineer roles

## Work Authorization
- US Work Authorization: [Update this]
- Open to: Remote, full-time, contract
- Notice Period: Immediate availability

## Salary Expectations
- Target: $[range] USD (update based on preferences)
- Negotiable based on equity, remote flexibility, and role scope
EOF

# Create skills.md
cat > "${MEMORY_DIR}/skills.md" <<'EOF'
# Skills Inventory

## Programming Languages
- **Zig**: Systems programming, <1MB binaries, memory safety, vtable architecture
- **TypeScript**: Next.js 16, React 19, strict typing, Server Components
- **JavaScript**: Node.js, modern ES features
- **Python**: Automation, scripting, agent orchestration
- **Kotlin**: Android/Termux development, mobile UX

## Frameworks & Libraries
- **Next.js 16**: App Router, Server Components, Server Actions, API routes
- **React 19**: Concurrent features, Suspense, hooks
- **Tailwind CSS 4**: Utility-first styling, DaisyUI
- **Playwright**: E2E testing
- **Zod**: Schema validation

## Infrastructure & DevOps
- **Docker**: Container orchestration, multi-service deployments
- **Debian/Linux**: VPS management, SSH hardening, systemd
- **Termux**: Mobile-to-cloud workflows on Android
- **CI/CD**: Automated testing, deployment pipelines
- **Security**: fail2ban, SSH keys, firewall rules, secrets management

## Databases
- **PostgreSQL**: Complex queries, RLS policies, migrations
- **Supabase**: Auth, storage, real-time subscriptions
- **SQLite**: Embedded databases, performance optimization

## AI & Agentic Systems
- **Claude API**: Anthropic integration, streaming responses
- **MCP**: Model Context Protocol servers
- **Pegasus**: Mobile mission control for AI agents (Kotlin/Compose)
- **Cost Optimization**: Token budgets, model fallbacks, batch processing

## Tools & Platforms
- **Git**: Advanced workflows, rebasing, conflict resolution
- **Stripe**: Payment processing, webhooks
- **Resend**: Transactional emails, templates
- **Sentry**: Error tracking, performance monitoring

## Soft Skills
- **Solo Founder**: Product, engineering, operations
- **Cost-Conscious**: Token budgets, infrastructure optimization
- **Security-First**: Default-deny, audit trails, compliance
- **Remote Work**: Async communication, documentation, autonomy
EOF

# Create projects.md
cat > "${MEMORY_DIR}/projects.md" <<'EOF'
# Portfolio Projects

## Dragun.app
**Tech Stack**: Next.js 16, React 19, TypeScript, Supabase, Stripe, Tailwind CSS 4

**Description**: Full-stack SaaS application with authentication, payments, and multi-language support.

**Key Features**:
- Next.js App Router with Server Components
- Supabase backend with RLS policies
- Stripe payment integration
- i18n support (multiple languages)
- Playwright E2E tests
- Sentry error tracking

**Technical Highlights**:
- Strict TypeScript throughout
- Server Actions for mutations
- Mobile-responsive with Tailwind
- Security-first (RLS, input validation)

**Links**:
- Live: dragun.app
- GitHub: [private repo]

---

## Cerberus
**Tech Stack**: Zig 0.15, SQLite, Docker

**Description**: Lightweight autonomous AI assistant runtime optimized for size and performance.

**Key Features**:
- Binary size <1MB (ReleaseSmall)
- 50+ AI provider support (OpenAI, Anthropic, Gemini, etc.)
- 17 messaging channels (Telegram, Discord, IRC, etc.)
- SQLite + markdown memory backends
- 3,371+ tests with zero memory leaks
- Vtable-driven architecture

**Technical Highlights**:
- Systems programming in Zig
- Memory safety without garbage collection
- Modular vtable design for extensibility
- Comprehensive test coverage

**Links**:
- GitHub: [private/public?]

---

## Pegasus
**Tech Stack**: Kotlin, Jetpack Compose, Material 3, Hilt, Retrofit

**Description**: Android mission control for Cerberus AI agent runtime.

**Key Features**:
- Real-time agent monitoring with SSE streaming
- HITL approval queue with diff preview and risk labels
- Cost tracking with per-agent gauges and panic mode
- SSH terminal access to VPS infrastructure
- Agent chat UI with skill routing
- Audit logging and traceability

**Technical Highlights**:
- Multi-agent coordination
- Cost-optimized model routing
- Security-first with approval gates
- Observable and auditable

**Links**:
- Deployed on Debian VPS

---

## Pegasus
**Tech Stack**: Kotlin, Termux, SSH

**Description**: Mobile command center for agent management via Termux on Android.

**Key Features**:
- TUI dashboard for agent status
- SSH tunneling to VPS
- Cost monitoring
- HITL approval queue
- Mobile-to-cloud workflow

**Technical Highlights**:
- Android development with Kotlin
- Terminal UI design
- Secure SSH tunneling
- Real-time updates

**Links**:
- Deployed on Samsung Z Fold 5
EOF

# Create analytics.md
cat > "${MEMORY_DIR}/analytics.md" <<'EOF'
# Job Search Analytics

## Metrics (Update regularly)
- **Applications Submitted**: 0
- **Interviews Scheduled**: 0
- **Offers Received**: 0
- **Average Response Time**: N/A

## Application Funnel
- Applied → Response: 0%
- Response → Interview: 0%
- Interview → Offer: 0%

## Top Skills Requested (from job postings)
- [Track keywords from postings]

## Companies Applied
- [List companies and status]

## Next Actions
- [ ] Update LinkedIn profile
- [ ] Create portfolio website
- [ ] Prepare technical interview questions
- [ ] Research target companies
EOF

# Create README
cat > "${MEMORY_DIR}/README.md" <<'EOF'
# Career Digital Twin Memory

This directory contains the knowledge base for the Career Digital Twin agent.

## Structure
- `profile.md`: Core professional profile and contact info
- `skills.md`: Detailed skills inventory
- `projects.md`: Portfolio projects with descriptions
- `applications/`: Job application tracking (one file per application)
- `conversations/`: Employer interaction logs
- `analytics.md`: Job search metrics and insights

## Maintenance
- Update profile.md with latest contact info and availability
- Add new projects to projects.md as they're completed
- Track applications in applications/ directory
- Review analytics.md weekly to track progress

## HITL Gates
Agent requires approval for:
- Sending emails to employers
- Accepting interview times
- Sharing sensitive information
EOF

echo "✅ Career Digital Twin memory structure created successfully"
echo ""
echo "Next steps:"
echo "1. Edit ${MEMORY_DIR}/profile.md with your real contact info"
echo "2. Update ${MEMORY_DIR}/skills.md with additional skills"
echo "3. Add more projects to ${MEMORY_DIR}/projects.md"
echo "4. Configure agent with: cerberus --config configs/career-twin-agent.json"
