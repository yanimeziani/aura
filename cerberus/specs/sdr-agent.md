# SDR (Sales Development Representative) Agent Specification

## 1. Purpose

Build an autonomous Sales Development Representative agent that crafts and sends professional outreach emails, manages follow-ups, and tracks engagement metrics. This demonstrates business-critical AI application development skills to potential employers.

## 2. Agent Profile

### 2.1 Core Identity
```json
{
  "name": "SDR Agent",
  "role": "Sales Development Representative",
  "mission": "Automate outbound sales outreach with personalization and follow-up",
  "target": "B2B SaaS prospects"
}
```

### 2.2 Capabilities
- **Lead Research**: Gather company/prospect information
- **Email Crafting**: Personalized cold outreach
- **Follow-up Sequencing**: Multi-touch campaigns
- **Engagement Tracking**: Open rates, replies, conversions
- **CRM Integration**: Log activities and update status

## 3. Agent Workflow

### 3.1 Outreach Sequence
```
Day 0:  Initial cold email (personalized)
Day 3:  Follow-up #1 (value-add content)
Day 7:  Follow-up #2 (case study or social proof)
Day 14: Final follow-up (breakup email)
```

### 3.2 Email Templates

#### Initial Outreach
```
Subject: Quick question about [Company]'s [pain point]

Hi [First Name],

I noticed [Company] is [specific observation from research]. 

[Our product] helps [similar companies] solve [specific problem] by [unique approach].

[Social proof - customer or metric]

Worth a 15-minute conversation?

Best,
[Your Name]
```

#### Follow-up #1
```
Subject: Re: Quick question about [Company]'s [pain point]

Hi [First Name],

Following up on my email from [day]. 

I thought you might find this helpful: [relevant resource/case study]

[Specific value proposition for their use case]

Let me know if you'd like to chat.

Best,
[Your Name]
```

#### Follow-up #2
```
Subject: Case study: [Similar Company] increased [metric] by [X%]

Hi [First Name],

Quick share: [Similar Company] faced [problem] and achieved [results] using [solution].

Full case study: [link]

Happy to discuss how this applies to [Company].

Best,
[Your Name]
```

#### Breakup Email
```
Subject: Closing the loop

Hi [First Name],

I haven't heard back, so I'll assume this isn't a priority right now.

If that changes, here's a quick link to schedule time: [calendar link]

Best of luck with [specific goal/initiative],
[Your Name]
```

## 4. Technical Architecture

### 4.1 Agent Configuration
```json
{
  "agents": {
    "sdr": {
      "name": "SDR Agent",
      "model": {
        "primary": "openrouter/anthropic/claude-sonnet-4",
        "fallback": "openrouter/meta-llama/llama-3.3-70b-instruct"
      },
      "system_prompt": "sdr_agent_prompt.txt",
      "tools": [
        "web_research",
        "email_draft",
        "email_send",
        "crm_update",
        "calendar_link"
      ],
      "memory": {
        "profile": "sdr_campaigns",
        "context_window": 4000
      },
      "autonomy": {
        "level": "supervised",
        "max_actions_per_hour": 20
      }
    }
  }
}
```

### 4.2 Memory Structure
```
~/.cerberus/memory/sdr/
├── campaigns/
│   ├── campaign-001-product-launch.md
│   └── campaign-002-feature-announce.md
├── prospects/
│   ├── company-a-john-doe.md
│   └── company-b-jane-smith.md
├── sequences/
│   ├── cold-outreach-v1.md
│   └── product-demo-followup.md
├── templates/
│   ├── initial-email.md
│   ├── followup-1.md
│   ├── followup-2.md
│   └── breakup.md
└── analytics.md
```

### 4.3 Tools Required

#### web_research (MCP)
- Company information lookup
- LinkedIn profile enrichment
- Recent news/funding rounds
- Tech stack detection

#### email_draft
- Personalize templates
- Variable substitution
- Tone adjustment
- A/B test variants

#### email_send
- Send via SMTP/API (Resend, Twilio SendGrid)
- Track delivery status
- Handle bounces

#### crm_update
- Log activities
- Update lead status
- Set follow-up tasks

#### calendar_link
- Generate scheduling links
- Check availability

### 4.4 HITL Gates

**Required Approval:**
- Sending first email to new prospects
- Campaign launch
- Template changes
- List uploads

**Automatic (no approval):**
- Scheduled follow-ups (pre-approved sequence)
- Engagement logging
- CRM updates

## 5. Dragun-app Integration

### 5.1 Web Interface Routes
```
/sdr                           # Dashboard
/sdr/campaigns                 # Campaign management
/sdr/campaigns/new             # Create campaign
/sdr/campaigns/[id]            # Campaign details
/sdr/prospects                 # Prospect database
/sdr/sequences                 # Email sequences
/sdr/templates                 # Template library
/sdr/analytics                 # Performance metrics
```

### 5.2 API Endpoints
```typescript
// app/api/sdr/campaigns/route.ts
GET  /api/sdr/campaigns
POST /api/sdr/campaigns

// app/api/sdr/prospects/route.ts
GET  /api/sdr/prospects
POST /api/sdr/prospects
PUT  /api/sdr/prospects/[id]

// app/api/sdr/emails/route.ts
POST /api/sdr/emails/draft      # Draft email
POST /api/sdr/emails/send       # Send email (with HITL)
GET  /api/sdr/emails/[id]       # Email details

// app/api/sdr/analytics/route.ts
GET  /api/sdr/analytics         # Metrics dashboard
```

### 5.3 Database Schema (Supabase)
```sql
CREATE TYPE campaign_status AS ENUM ('draft', 'active', 'paused', 'completed');
CREATE TYPE prospect_status AS ENUM ('new', 'contacted', 'replied', 'interested', 'unqualified', 'converted');
CREATE TYPE email_status AS ENUM ('draft', 'scheduled', 'sent', 'delivered', 'opened', 'replied', 'bounced');

CREATE TABLE sdr_campaigns (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id),
  name TEXT NOT NULL,
  description TEXT,
  status campaign_status DEFAULT 'draft',
  sequence_id UUID,
  created_at TIMESTAMPTZ DEFAULT now(),
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  metadata JSONB
);

CREATE TABLE sdr_prospects (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id),
  campaign_id UUID REFERENCES sdr_campaigns(id),
  email TEXT NOT NULL,
  first_name TEXT,
  last_name TEXT,
  company TEXT,
  title TEXT,
  status prospect_status DEFAULT 'new',
  research_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  last_contacted TIMESTAMPTZ,
  metadata JSONB
);

CREATE TABLE sdr_emails (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  prospect_id UUID REFERENCES sdr_prospects(id),
  campaign_id UUID REFERENCES sdr_campaigns(id),
  sequence_step INT DEFAULT 0,
  subject TEXT NOT NULL,
  body TEXT NOT NULL,
  status email_status DEFAULT 'draft',
  scheduled_at TIMESTAMPTZ,
  sent_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  opened_at TIMESTAMPTZ,
  replied_at TIMESTAMPTZ,
  reply_content TEXT,
  metadata JSONB
);

CREATE TABLE sdr_analytics (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  campaign_id UUID REFERENCES sdr_campaigns(id),
  date DATE DEFAULT CURRENT_DATE,
  emails_sent INT DEFAULT 0,
  emails_delivered INT DEFAULT 0,
  emails_opened INT DEFAULT 0,
  emails_replied INT DEFAULT 0,
  emails_bounced INT DEFAULT 0,
  conversions INT DEFAULT 0,
  metadata JSONB
);

-- Indexes for performance
CREATE INDEX idx_prospects_campaign ON sdr_prospects(campaign_id);
CREATE INDEX idx_prospects_status ON sdr_prospects(status);
CREATE INDEX idx_emails_prospect ON sdr_emails(prospect_id);
CREATE INDEX idx_emails_status ON sdr_emails(status);
CREATE INDEX idx_analytics_campaign ON sdr_analytics(campaign_id);
```

## 6. System Prompt

```
You are an SDR (Sales Development Representative) agent responsible for professional B2B outreach.

Your mission:
- Research prospects and companies thoroughly
- Craft personalized, value-driven emails
- Manage follow-up sequences
- Track engagement and optimize performance

Your capabilities:
- Web research for company and prospect information
- Email drafting with personalization variables
- CRM integration for activity logging
- Analytics tracking for campaign performance

HITL Requirements:
- Request approval before sending first email to new prospects
- Request approval for new campaigns
- Flag unusual bounce rates or negative replies
- Escalate angry or legal-threatening responses immediately

Email Best Practices:
- Keep emails under 150 words
- Lead with value, not features
- Personalize with specific research insights
- Clear, single call-to-action
- Professional tone, no hype
- Respect unsubscribe requests immediately

Communication Style:
- Professional and consultative
- Focused on prospect's problems, not our solutions
- Data-driven (use metrics and case studies)
- Respectful of prospect's time
- Persistent but not pushy

When researching prospects:
- Look for recent company news, funding, product launches
- Identify potential pain points from job postings
- Note relevant tech stack or initiatives
- Find mutual connections or shared interests

When drafting emails:
- Use research insights for personalization
- Reference specific company details
- Include relevant social proof
- Suggest low-commitment next step (15-min call)

When handling replies:
- Positive reply: Schedule meeting, send calendar link
- Question: Answer promptly with value
- Not interested: Thank them, ask for referral
- Unsubscribe: Remove immediately, log preference

Success metrics:
- Reply rate: Target 10%+
- Meeting booked rate: Target 5%+
- Email deliverability: Target 95%+
- Personalization quality: Human-level

When uncertain: Flag for human review rather than sending generic email.
When blocked: Escalate to human for guidance.
```

## 7. Email Sending Integration

### 7.1 Resend Integration
```typescript
// lib/resend-client.ts
import { Resend } from 'resend';

const resend = new Resend(process.env.RESEND_API_KEY);

export async function sendSDREmail({
  to,
  subject,
  html,
  prospectId,
  campaignId
}: {
  to: string;
  subject: string;
  html: string;
  prospectId: string;
  campaignId: string;
}) {
  const { data, error } = await resend.emails.send({
    from: 'sales@yourdomain.com',
    to,
    subject,
    html,
    tags: [
      { name: 'campaign_id', value: campaignId },
      { name: 'prospect_id', value: prospectId }
    ]
  });

  if (error) {
    throw new Error(`Failed to send email: ${error.message}`);
  }

  return data;
}
```

### 7.2 Webhook Tracking
```typescript
// app/api/webhooks/resend/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase-admin';

export async function POST(req: NextRequest) {
  const event = await req.json();

  // Update email status based on webhook event
  const { type, data } = event;
  const emailId = data.tags?.prospect_id;

  if (!emailId) return NextResponse.json({ ok: true });

  const statusMap: Record<string, string> = {
    'email.delivered': 'delivered',
    'email.opened': 'opened',
    'email.bounced': 'bounced',
    'email.complained': 'bounced'
  };

  const status = statusMap[type];
  if (!status) return NextResponse.json({ ok: true });

  await supabaseAdmin
    .from('sdr_emails')
    .update({ 
      status,
      [`${status}_at`]: new Date().toISOString()
    })
    .eq('id', emailId);

  return NextResponse.json({ ok: true });
}
```

## 8. Success Metrics

### 8.1 Email Performance
- Delivery rate: >95%
- Open rate: 30-50%
- Reply rate: 10-20%
- Meeting booked rate: 5-10%
- Bounce rate: <5%

### 8.2 Campaign Efficiency
- Time saved per prospect: ~30 minutes
- Cost per meeting booked: <$50
- Personalization quality score: >8/10
- Follow-up completion rate: >90%

### 8.3 Agent Reliability
- Email accuracy (no merge field errors): 100%
- HITL approval latency: <1 hour
- CRM sync accuracy: >99%

## 9. Deployment Checklist

- [ ] Cerberus SDR agent configuration
- [ ] System prompt finalized
- [ ] Email templates created
- [ ] Resend API key configured
- [ ] Webhook endpoint for tracking
- [ ] Dragun-app UI routes
- [ ] API endpoints
- [ ] Database schema migrated
- [ ] HITL gates configured
- [ ] Test campaign with 3-5 prospects
- [ ] Unsubscribe handling
- [ ] Bounce handling
- [ ] VPS deployment
- [ ] Monitoring setup

## 10. Security & Compliance

### 10.1 Email Compliance
- CAN-SPAM compliance (unsubscribe link in every email)
- GDPR compliance (consent tracking)
- Bounce handling (remove hard bounces)
- Complaint handling (immediate unsubscribe)

### 10.2 Data Protection
- No prospect data in logs
- Encrypted storage for email content
- Rate limiting on sends (avoid spam flags)
- Authentication required for all actions

### 10.3 Reputation Management
- SPF/DKIM/DMARC configured
- Warm-up sending (start with 10-20/day)
- Monitor sender reputation
- Dedicated sending domain

## 11. Future Enhancements

- AI-powered reply detection and routing
- A/B testing framework
- Multi-channel sequences (email + LinkedIn)
- Lead scoring and prioritization
- Intent signal detection
- Conversation intelligence (reply analysis)
- Integration with Calendly/Cal.com
- Automated meeting prep briefs
- Sales team handoff workflows
