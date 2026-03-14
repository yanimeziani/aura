# Career Digital Twin Agent Specification

## 1. Purpose

Build an autonomous agent that represents a job-seeking founder to potential employers. The agent:
- Maintains a comprehensive professional profile
- Responds to employer inquiries intelligently
- Schedules interviews and follow-ups
- Tracks application status
- Provides insights and recommendations

## 2. Agent Profile

### 2.1 Core Identity
```json
{
  "name": "Yani Meziani",
  "role": "Founder & Full-Stack Engineer",
  "tagline": "Building AI-powered tools with Zig/TypeScript/Next.js",
  "location": "Remote-first",
  "availability": "Open to remote opportunities"
}
```

### 2.2 Skills & Experience
- **Languages**: Zig, TypeScript, JavaScript, Python, Kotlin
- **Frameworks**: Next.js 16, React 19, Cerberus (Zig), Pegasus (Kotlin)
- **Infrastructure**: Docker, Debian VPS, Termux, CI/CD
- **AI/ML**: Claude API integration, MCP servers, agentic workflows
- **Databases**: Supabase, PostgreSQL, SQLite
- **Focus**: DevSecOps, Growth Hacking, Autonomous Agents

### 2.3 Projects Portfolio
- **Dragun.app**: Next.js/React/TypeScript SaaS application
- **Cerberus**: Zig-based autonomous AI assistant runtime (<1MB binary)
- **OpenClaw** (legacy, replaced by Cerberus): Agent orchestration platform with HITL gates
- **Pegasus**: Kotlin mobile command center for agents

## 3. Agent Capabilities

### 3.1 Profile Management
- Maintain structured resume/CV data
- Track skills, experience, certifications
- Update availability and job preferences
- Store portfolio links and project descriptions

### 3.2 Intelligent Response
- Answer technical questions about skills and experience
- Provide code samples and project demos
- Explain architectural decisions
- Share relevant case studies

### 3.3 Application Tracking
- Track job applications and status
- Monitor response rates
- Schedule interviews
- Set follow-up reminders

### 3.4 Interview Coordination
- Check calendar availability (via MCP tool)
- Suggest interview times
- Send calendar invites
- Handle rescheduling requests

### 3.5 Insights & Analytics
- Application funnel metrics
- Response time analytics
- Skills gap analysis
- Market demand tracking

## 4. Technical Architecture

### 4.1 Agent Configuration
```json
{
  "agents": {
    "career_twin": {
      "name": "Career Digital Twin",
      "model": {
        "primary": "openrouter/anthropic/claude-sonnet-4"
      },
      "system_prompt": "career_twin_prompt.txt",
      "tools": [
        "calendar",
        "email_draft",
        "document_search",
        "web_fetch"
      ],
      "memory": {
        "profile": "career_profile",
        "context_window": 8000
      },
      "autonomy": {
        "level": "supervised",
        "max_actions_per_hour": 10
      }
    }
  }
}
```

### 4.2 Memory Structure
```
~/.cerberus/memory/career_twin/
├── profile.md           # Core professional profile
├── skills.md            # Detailed skills inventory
├── projects.md          # Portfolio projects
├── applications/        # Job application tracking
│   ├── 2026-03-01-company-a.md
│   └── 2026-03-02-company-b.md
├── conversations/       # Employer interaction logs
└── analytics.md         # Metrics and insights
```

### 4.3 Tools Required

#### calendar (MCP)
- Check availability
- Block interview slots
- Send invites

#### email_draft
- Compose professional emails
- Follow-up templates
- Thank you notes

#### document_search
- Search resume/portfolio
- Find relevant projects
- Retrieve code samples

#### web_fetch
- Research companies
- Check job postings
- Verify company details

### 4.4 HITL Gates
- Sending emails to employers (requires approval)
- Accepting interview times (requires confirmation)
- Sharing sensitive information (requires review)
- Major profile updates (requires validation)

## 5. Dragun-app Integration

### 5.1 Web Interface Routes
```
/career-twin                    # Dashboard
/career-twin/profile           # Edit profile
/career-twin/applications      # Application tracker
/career-twin/conversations     # Chat history
/career-twin/analytics         # Metrics
/career-twin/settings          # Agent config
```

### 5.2 API Endpoints
```typescript
// app/api/career-twin/profile/route.ts
GET  /api/career-twin/profile
PUT  /api/career-twin/profile

// app/api/career-twin/applications/route.ts
GET  /api/career-twin/applications
POST /api/career-twin/applications

// app/api/career-twin/chat/route.ts
POST /api/career-twin/chat         # Proxy to Cerberus agent
```

### 5.3 Database Schema (Supabase)
```sql
CREATE TABLE career_applications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id),
  company_name TEXT NOT NULL,
  position TEXT NOT NULL,
  status TEXT NOT NULL, -- applied, interview, offer, rejected
  applied_at TIMESTAMPTZ DEFAULT now(),
  last_contact TIMESTAMPTZ,
  notes TEXT,
  metadata JSONB
);

CREATE TABLE career_interactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  application_id UUID REFERENCES career_applications(id),
  type TEXT NOT NULL, -- email, call, interview
  direction TEXT NOT NULL, -- inbound, outbound
  summary TEXT,
  occurred_at TIMESTAMPTZ DEFAULT now(),
  metadata JSONB
);
```

## 6. System Prompt

```
You are a Career Digital Twin representing a job-seeking founder and full-stack engineer.

Your mission:
- Represent the candidate professionally and authentically
- Answer employer questions about skills, experience, and availability
- Schedule interviews and coordinate logistics
- Track application status and provide insights

Your capabilities:
- Access to complete professional profile, portfolio, and project history
- Calendar integration for scheduling
- Email drafting for professional communication
- Document search for retrieving relevant experience

HITL Requirements:
- Always request approval before sending emails
- Confirm interview times before accepting
- Flag sensitive information requests for review

Communication style:
- Professional but approachable
- Technical when appropriate, clear always
- Proactive in follow-ups
- Transparent about being an AI assistant

When uncertain: Ask clarifying questions rather than guessing.
When blocked: Escalate to the human for approval.
```

## 7. Success Metrics

### 7.1 Engagement
- Response time to employer inquiries (<1 hour)
- Interview conversion rate
- Application tracking accuracy

### 7.2 Efficiency
- Time saved on application management
- Automated responses vs. manual
- Calendar coordination success rate

### 7.3 Quality
- Employer satisfaction (feedback)
- Interview preparation quality
- Profile accuracy and completeness

## 8. Deployment Checklist

- [ ] Cerberus agent configuration
- [ ] System prompt finalized
- [ ] Memory structure created
- [ ] MCP tools configured (calendar, email, search)
- [ ] Dragun-app UI routes
- [ ] API endpoints
- [ ] Database schema migrated
- [ ] HITL gates configured
- [ ] Test conversations
- [ ] VPS deployment
- [ ] Monitoring setup

## 9. Security & Privacy

### 9.1 Data Protection
- No sensitive credentials in prompts
- PII redaction in logs
- Encrypted storage for profile data
- Audit trail for all actions

### 9.2 Access Control
- Agent requires authentication
- HITL gates for external communication
- Rate limiting on actions
- Spending caps on API usage

## 10. Future Enhancements

- LinkedIn integration
- Automated job search
- Skills gap analysis with learning recommendations
- Network mapping and warm introductions
- Interview prep with mock questions
- Salary negotiation assistant
