#!/usr/bin/env bash
set -euo pipefail

# Initialize SDR Agent memory structure

MEMORY_DIR="${HOME}/.cerberus/memory/sdr"

echo "Creating SDR Agent memory structure at: ${MEMORY_DIR}"

mkdir -p "${MEMORY_DIR}"/{campaigns,prospects,sequences,templates}

# Create templates
cat > "${MEMORY_DIR}/templates/initial-email.md" <<'EOF'
# Initial Outreach Email Template

**When to use**: First contact with prospect

**Subject line patterns**:
- "Quick question about {{company}}'s {{pain_point}}"
- "{{recent_news}} → quick question"
- "{{mutual_connection}} suggested I reach out"

**Template**:
```
Subject: [Choose from above patterns]

Hi {{first_name}},

[Hook: specific observation about their company]

[Value prop: how we solve their specific problem]

[Social proof: relevant case study or metric]

Worth a 15-minute conversation?

{{calendar_link}}

Best,
[Your Name]
```

**Personalization checklist**:
- [ ] Research recent company news
- [ ] Identify specific pain point
- [ ] Find relevant case study
- [ ] Verify email deliverability
EOF

cat > "${MEMORY_DIR}/templates/followup-1.md" <<'EOF'
# Follow-up #1 Template

**When to use**: 3 days after initial email

**Subject line patterns**:
- "Re: [original subject]"
- "Resource for {{company}}'s {{pain_point}}"
- "[Valuable content] for {{company}}"

**Template**:
```
Subject: [Choose from above patterns]

Hi {{first_name}},

Following up on my note from [day].

I thought you'd find this helpful: [relevant resource/case study link]

[Brief summary of value from resource]

Let me know if you'd like to chat about how this applies to {{company}}.

Best,
[Your Name]
```

**Value-add ideas**:
- Industry report or benchmark data
- Case study from similar company
- Blog post solving their pain point
- Tool or template they can use
EOF

cat > "${MEMORY_DIR}/templates/followup-2.md" <<'EOF'
# Follow-up #2 Template

**When to use**: 7 days after initial email

**Subject line patterns**:
- "How {{case_study_company}} {{achieved_result}}"
- "Case study: {{specific_metric}} improvement"
- "{{company}} + {{case_study_company}} comparison"

**Template**:
```
Subject: [Choose from above patterns]

Hi {{first_name}},

Quick share: {{case_study_company}} faced {{specific_problem}} and achieved {{quantified_results}} using {{our_solution}}.

Full case study: [link]

Happy to discuss how this might work for {{company}}.

{{calendar_link}}

Best,
[Your Name]
```

**Social proof requirements**:
- Specific company name (if public)
- Quantified results (e.g., "32% increase")
- Similar industry/size to prospect
- Recent (within last year)
EOF

cat > "${MEMORY_DIR}/templates/breakup.md" <<'EOF'
# Breakup Email Template

**When to use**: 14 days after initial email, no response

**Subject line patterns**:
- "Closing the loop"
- "Last note"
- "Wrong timing?"

**Template**:
```
Subject: [Choose from above patterns]

Hi {{first_name}},

I haven't heard back, so I'll assume this isn't a priority right now.

If timing changes, here's a quick link to grab 15 minutes: {{calendar_link}}

Best of luck with {{specific_goal}},
[Your Name]

P.S. If you know someone at {{company}} who'd find this relevant, I'd appreciate the intro.
```

**Tone notes**:
- No guilt or pressure
- Assume timing, not interest
- Leave door open
- Optional: ask for referral
EOF

# Create sample campaign
cat > "${MEMORY_DIR}/campaigns/sample-campaign.md" <<'EOF'
# Sample Campaign: Product Launch Outreach

## Campaign Details
- **Name**: Product Launch Q1 2026
- **Target**: B2B SaaS founders and CTOs
- **Company Size**: 10-100 employees
- **Status**: Draft
- **Created**: 2026-03-03

## Goal
Book 20 discovery calls in 30 days

## Target Personas
1. **Founder/CEO**: Decision-maker, budget authority
2. **CTO**: Technical evaluator, user champion
3. **VP Product**: Use case identifier, ROI calculator

## Value Proposition
Help B2B SaaS companies reduce [pain point] by [unique approach], leading to [specific outcome].

## Social Proof
- Customer: Acme Corp (50 employees)
- Result: 40% reduction in [metric]
- Timeline: 2 months

## Sequence
- Day 0: Initial email
- Day 3: Follow-up with resource
- Day 7: Case study email
- Day 14: Breakup email

## Metrics (Update as campaign runs)
- **Prospects Added**: 0
- **Emails Sent**: 0
- **Delivered**: 0
- **Opened**: 0
- **Replied**: 0
- **Meetings Booked**: 0

## Notes
- [Add campaign-specific notes]
EOF

# Create sample prospect
cat > "${MEMORY_DIR}/prospects/sample-prospect.md" <<'EOF'
# Prospect: John Doe - Acme Corp

## Basic Info
- **Name**: John Doe
- **Email**: john@acme.com
- **Company**: Acme Corp
- **Title**: CTO
- **Status**: New

## Research Notes

### Company
- **Industry**: B2B SaaS
- **Size**: 50 employees
- **Funding**: Series A ($10M)
- **Recent News**: Launched new product feature, hiring engineers
- **Tech Stack**: React, Node.js, PostgreSQL
- **Pain Points**: Scaling infrastructure, developer productivity

### Decision-Maker
- **Background**: 10 years engineering, 3 years at Acme
- **Previous**: Senior Engineer at BigTech Corp
- **LinkedIn**: [profile URL]
- **Twitter**: [if active]
- **Interests**: Open source, developer tools, AI

### Personalization Hooks
- Recent product launch (congratulate)
- Hiring for DevOps (pain point: infrastructure)
- Previously worked at BigTech (mutual context)

## Outreach History
- [Will be populated by agent]

## Next Steps
- [ ] Draft personalized initial email
- [ ] Get approval to send
- [ ] Schedule follow-ups
EOF

# Create analytics template
cat > "${MEMORY_DIR}/analytics.md" <<'EOF'
# SDR Agent Analytics

## Overall Performance
- **Total Campaigns**: 0
- **Total Prospects**: 0
- **Emails Sent**: 0
- **Reply Rate**: 0%
- **Meeting Booked Rate**: 0%

## Campaign Performance
| Campaign | Sent | Delivered | Opened | Replied | Booked | Reply % | Book % |
|----------|------|-----------|--------|---------|--------|---------|--------|
| Sample   | 0    | 0         | 0      | 0       | 0      | 0%      | 0%     |

## Email Deliverability
- **Delivery Rate**: 0% (target: >95%)
- **Bounce Rate**: 0% (target: <5%)
- **Complaint Rate**: 0% (target: <0.1%)

## Engagement Trends
- **Best Send Time**: TBD
- **Best Subject Line Pattern**: TBD
- **Avg Time to Reply**: TBD

## Next Optimizations
- [ ] A/B test subject lines
- [ ] Refine personalization depth
- [ ] Test different send times
- [ ] Update templates based on replies
EOF

# Create README
cat > "${MEMORY_DIR}/README.md" <<'EOF'
# SDR Agent Memory

This directory contains campaigns, prospects, and templates for the SDR Agent.

## Structure
- `campaigns/`: Campaign definitions and tracking
- `prospects/`: Individual prospect research and notes
- `sequences/`: Multi-touch email sequences
- `templates/`: Email templates with personalization variables
- `analytics.md`: Performance metrics and optimization notes

## Workflow
1. Create campaign in `campaigns/`
2. Add prospects with research in `prospects/`
3. Agent drafts personalized emails using templates
4. Request HITL approval before sending first email
5. Agent manages follow-up sequence automatically
6. Track engagement in analytics.md

## HITL Gates
Agent requires approval for:
- Sending first email to new prospects
- Launching new campaigns
- Major template changes
- Uploading large contact lists

## Templates
All templates support these variables:
- {{first_name}}, {{last_name}}
- {{company}}, {{title}}
- {{pain_point}}, {{recent_news}}
- {{case_study_company}}, {{case_study_metric}}
- {{calendar_link}}

## Compliance
- Unsubscribe link in every email (required)
- Honor unsubscribe within 1 hour (target)
- Never email purchased lists
- Respect GDPR and CAN-SPAM
EOF

echo "✅ SDR Agent memory structure created successfully"
echo ""
echo "Next steps:"
echo "1. Review templates in ${MEMORY_DIR}/templates/"
echo "2. Create your first campaign in ${MEMORY_DIR}/campaigns/"
echo "3. Add prospects to ${MEMORY_DIR}/prospects/"
echo "4. Configure Resend API key for email sending"
echo "5. Run agent with: cerberus --config configs/sdr-agent.json"
