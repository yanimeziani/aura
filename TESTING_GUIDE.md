# Testing Guide — Career Digital Twin + SDR Agent

This guide walks you through testing both agents to ensure they work correctly before deploying to production.

---

## Prerequisites

- ✅ Memory structures initialized (`bash scripts/init-*.sh`)
- ✅ API keys configured (OpenRouter, Resend)
- ✅ Database migrations run (`npm run db:check`)
- ✅ Cerberus built (`zig build`)

---

## Test 1: Career Digital Twin — CLI Mode

### Step 1: Start Agent in CLI Mode
```bash
cd /root/cerberus/runtime/cerberus-core

# Load environment
source ~/.cerberus/career-twin.env

# Run agent
./zig-out/bin/cerberus --config /root/cerberus/configs/career-twin-agent.json --cli
```

### Step 2: Test Profile Queries
```
> Tell me about my TypeScript experience
> What projects should I highlight for a full-stack engineering role?
> Summarize my skills in systems programming
> What makes me a good fit for a remote-first startup?
```

**Expected Behavior**:
- Agent responds with accurate information from `profile.md` and `projects.md`
- Mentions specific projects (Dragun.app, Cerberus, Pegasus)
- Professional tone, concise answers

### Step 3: Test Employer Interaction
```
> An employer from Acme Corp asked: "What's your experience with Zig?"
> An employer wants to schedule an interview. Check my calendar for next week.
> Draft a thank-you email after an interview with BigTech Inc.
```

**Expected Behavior**:
- Responds with Cerberus project details
- Requests calendar tool usage (will be added via MCP)
- Drafts professional email, asks for approval before sending

### Step 4: Test HITL Gates
```
> Send an email to john@acme.com introducing myself
```

**Expected Behavior**:
- Agent drafts email
- **Requests approval** before sending
- Flags that this requires HITL gate approval

---

## Test 2: Career Digital Twin — Web Interface

### Step 1: Start Dragun-app
```bash
cd /root/dragun-app
npm run dev
```

### Step 2: Access Dashboard
Navigate to: http://localhost:3000/career-twin

**Expected View**:
- Stats cards (Applied, Interviews, Offers, Total)
- "Add Application" button
- Applications list (empty initially)

### Step 3: Add Job Application
1. Click "Add Application"
2. Fill in:
   - Company: Acme Corp
   - Position: Senior Full-Stack Engineer
   - Status: applied
   - Notes: "Referred by John Doe"
3. Submit

**Expected Behavior**:
- Application appears in dashboard
- Stats updated (Applied: 1, Total: 1)
- Application card shows company, position, status badge

### Step 4: Test API Endpoints
```bash
# Get all applications (requires auth token)
curl http://localhost:3000/api/career-twin/applications \
  -H "Authorization: Bearer YOUR_TOKEN"

# Create application
curl -X POST http://localhost:3000/api/career-twin/applications \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "company_name": "BigTech Inc",
    "position": "Founding Engineer",
    "status": "interview",
    "notes": "2nd round interview scheduled"
  }'
```

**Expected Response**:
```json
{
  "application": {
    "id": "uuid",
    "company_name": "BigTech Inc",
    "position": "Founding Engineer",
    "status": "interview",
    "applied_at": "2026-03-03T...",
    "notes": "2nd round interview scheduled"
  }
}
```

---

## Test 3: SDR Agent — CLI Mode

### Step 1: Start Agent in CLI Mode
```bash
cd /root/cerberus/runtime/cerberus-core

# Load environment
source ~/.cerberus/sdr.env

# Run agent
./zig-out/bin/cerberus --config /root/cerberus/configs/sdr-agent.json --cli
```

### Step 2: Test Email Drafting
```
> Draft a cold email for John Doe, CTO at Acme Corp. They just raised Series A funding ($10M).
```

**Expected Behavior**:
- Agent researches Acme Corp (or uses provided info)
- Drafts personalized email using template
- Includes:
  - Personalized hook (Series A mention)
  - Value proposition for their use case
  - Relevant social proof
  - Low-commitment CTA

**Example Output**:
```
Subject: Quick question about Acme's Series A growth plans

Hi John,

I noticed Acme just raised $10M Series A — congrats on the milestone.

Many post-Series A SaaS companies face [pain point] during rapid scaling. 
We've helped [similar company] solve this by [approach], leading to 
[32% increase in metric].

Worth a 15-minute conversation?

[calendar link]

Best,
[Your Name]

---
Quality Score: 8/10
Personalization: High
Risk: Low (initial outreach)

[Approve to send?]
```

### Step 3: Test Follow-up Sequence
```
> John Doe opened the email but didn't reply. Draft follow-up #1.
```

**Expected Behavior**:
- Agent uses follow-up template
- Adds new value (case study or resource)
- No guilt or pressure tone
- Requests approval before scheduling

### Step 4: Test Reply Handling
```
> John replied: "Interested, let's schedule a call next Tuesday"
```

**Expected Behavior**:
- Agent recognizes positive reply
- Offers to send calendar link
- Updates prospect status to "interested"
- Logs interaction in CRM

---

## Test 4: SDR Agent — Email Templates

### Step 1: Review Templates
```bash
cat ~/.cerberus/memory/sdr/templates/initial-email.md
cat ~/.cerberus/memory/sdr/templates/followup-1.md
cat ~/.cerberus/memory/sdr/templates/breakup.md
```

**Expected Content**:
- Subject line patterns
- Personalization variables ({{first_name}}, {{company}}, etc.)
- Value-focused messaging
- Clear CTAs

### Step 2: Create Test Prospect
```bash
cat > ~/.cerberus/memory/sdr/prospects/test-prospect.md <<EOF
# Prospect: Jane Smith - TechCo

## Basic Info
- Name: Jane Smith
- Email: jane@techco.com
- Company: TechCo
- Title: VP Engineering
- Status: New

## Research Notes
- Company raised Series B (\$25M) in Jan 2026
- Hiring 10+ engineers (scaling pain)
- Using React + Node.js stack
- Pain point: Developer productivity

## Personalization Hooks
- Recent Series B (congratulate)
- Rapid hiring (infrastructure pain point)
- Tech stack match (relevant case study)
EOF
```

### Step 3: Test Personalized Email
```
> Draft email for Jane Smith at TechCo using the research notes
```

**Expected Behavior**:
- Uses research notes for personalization
- Mentions Series B funding
- Addresses developer productivity pain
- References relevant case study
- All variables filled in (no {{placeholders}} left)

---

## Test 5: Database Integrity

### Step 1: Verify Tables Created
```sql
-- Connect to Supabase
psql $DATABASE_URL

-- Check Career Twin tables
SELECT * FROM career_applications LIMIT 5;
SELECT * FROM career_interactions LIMIT 5;

-- Check SDR tables
SELECT * FROM sdr_campaigns LIMIT 5;
SELECT * FROM sdr_prospects LIMIT 5;
SELECT * FROM sdr_emails LIMIT 5;
SELECT * FROM sdr_analytics LIMIT 5;
```

### Step 2: Test RLS Policies
```sql
-- Should only return current user's data
SET request.jwt.claim.sub = 'user-uuid';
SELECT * FROM career_applications;

-- Should be empty for different user
SET request.jwt.claim.sub = 'different-user-uuid';
SELECT * FROM career_applications;  -- Should return 0 rows
```

### Step 3: Test Triggers
```sql
-- Insert email
INSERT INTO sdr_emails (user_id, prospect_id, campaign_id, subject, body, status)
VALUES ('user-uuid', 'prospect-uuid', 'campaign-uuid', 'Test', 'Test body', 'sent');

-- Check analytics updated
SELECT * FROM sdr_analytics WHERE campaign_id = 'campaign-uuid';
-- Should show emails_sent = 1
```

---

## Test 6: Cost Tracking

### Step 1: Enable Cost Logging
```bash
# Check Cerberus cost logs
tail -f ~/.cerberus/logs/cost.log
```

### Step 2: Run Multiple Queries
```
> Tell me about my projects
> Draft an email for John Doe
> Summarize my experience
```

### Step 3: Review Token Usage
```bash
# Parse cost log
grep "tokens" ~/.cerberus/logs/cost.log | tail -10
```

**Expected Output**:
```
2026-03-03 10:15:23 | career_twin | query | 487 tokens | $0.004
2026-03-03 10:16:01 | career_twin | query | 623 tokens | $0.005
2026-03-03 10:17:45 | sdr | email_draft | 312 tokens | $0.003
```

---

## Test 7: HITL Gates

### Step 1: Test Email Approval Flow
```
# As Career Twin
> Send an email to john@acme.com
```

**Expected Flow**:
1. Agent drafts email
2. Shows draft to user
3. **Requests approval**: "This action requires approval. Send email? (yes/no)"
4. If yes → sends via Resend
5. If no → saves as draft

### Step 2: Test Campaign Launch Approval
```
# As SDR Agent
> Launch the "Q1 Outreach" campaign
```

**Expected Flow**:
1. Agent reviews campaign details
2. Checks prospect count
3. **Requests approval**: "Launch campaign to 50 prospects? (yes/no)"
4. If yes → schedules first batch of emails
5. If no → keeps campaign in draft status

---

## Test 8: Error Handling

### Step 1: Test Missing API Key
```bash
# Remove API key temporarily
unset OPENROUTER_API_KEY

# Try to run agent
./zig-out/bin/cerberus --config /root/cerberus/configs/career-twin-agent.json --cli
```

**Expected Behavior**:
- Clear error message: "OPENROUTER_API_KEY not set"
- Agent exits gracefully (no crash)

### Step 2: Test Invalid Email Address
```
# As SDR Agent
> Send email to invalid-email@
```

**Expected Behavior**:
- Validates email format
- Returns error: "Invalid email address format"
- Does not attempt to send

### Step 3: Test Database Connection Failure
```bash
# Temporarily break Supabase connection
export DATABASE_URL="invalid-url"

# Try to access Career Twin dashboard
curl http://localhost:3000/career-twin
```

**Expected Behavior**:
- Error page or fallback message
- Logs error (does not expose connection string)
- Graceful degradation

---

## Test 9: Security Checks

### Step 1: Verify No Secrets in Logs
```bash
# Check logs for API keys
grep -i "api" ~/.cerberus/logs/*.log
grep -i "key" ~/.cerberus/logs/*.log
grep -i "token" ~/.cerberus/logs/*.log
```

**Expected Result**: No actual API keys or tokens visible

### Step 2: Verify RLS Policies
```bash
# Try to access another user's data via API
curl http://localhost:3000/api/career-twin/applications/OTHER_USER_UUID \
  -H "Authorization: Bearer YOUR_TOKEN"
```

**Expected Response**: 404 Not Found (RLS blocks access)

### Step 3: Check Audit Logs
```bash
# Review audit trail
cat ~/.cerberus/logs/audit.log | tail -20
```

**Expected Content**:
- Timestamps
- User actions
- HITL decisions (approved/rejected)
- No PII or secrets

---

## Test 10: Performance Benchmarks

### Step 1: Measure Response Time
```bash
# Time a query
time echo "Tell me about my projects" | ./zig-out/bin/cerberus --config /root/cerberus/configs/career-twin-agent.json --cli
```

**Target**: <3 seconds for simple queries

### Step 2: Measure Email Draft Time
```bash
# Time email drafting
time echo "Draft email for John Doe at Acme Corp" | ./zig-out/bin/cerberus --config /root/cerberus/configs/sdr-agent.json --cli
```

**Target**: <5 seconds including research

### Step 3: Load Test API
```bash
# Simple load test (requires `ab` tool)
ab -n 100 -c 10 http://localhost:3000/api/career-twin/applications \
  -H "Authorization: Bearer YOUR_TOKEN"
```

**Target**: >90% success rate, <500ms average response time

---

## Test Checklist

### Career Digital Twin
- [ ] Agent starts without errors
- [ ] Responds accurately to profile queries
- [ ] HITL gates trigger for email sending
- [ ] Web dashboard loads and displays applications
- [ ] API endpoints work (GET, POST, PUT, DELETE)
- [ ] Database RLS policies enforce access control
- [ ] Cost logging captures token usage
- [ ] No secrets in logs

### SDR Agent
- [ ] Agent starts without errors
- [ ] Drafts personalized emails with research
- [ ] Follow-up sequences work correctly
- [ ] HITL gates trigger for first emails
- [ ] Templates have proper variables
- [ ] Email validation works
- [ ] Analytics auto-update on status changes
- [ ] Resend integration configured (optional, for sending)

### Overall
- [ ] No memory leaks (Zig tests pass)
- [ ] Error handling graceful
- [ ] Performance meets targets
- [ ] Security checks pass
- [ ] Documentation complete

---

## Troubleshooting

### Issue: Agent won't start
**Check**:
```bash
# Verify config syntax
cat /root/cerberus/configs/career-twin-agent.json | jq .

# Check API key
echo $OPENROUTER_API_KEY

# Verify build
cd /root/cerberus/runtime/cerberus-core
zig build test --summary all
```

### Issue: Database migrations fail
**Check**:
```bash
# Verify Supabase connection
npm run db:check

# Check migration files
ls -la /root/dragun-app/supabase/migrations/

# Manual migration
cd /root/dragun-app
supabase db push --linked
```

### Issue: Email sending fails
**Check**:
```bash
# Test Resend API
curl -X POST https://api.resend.com/emails \
  -H "Authorization: Bearer $RESEND_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"from":"test@yourdomain.com","to":"test@example.com","subject":"Test","html":"<p>Test</p>"}'
```

---

## Next Steps After Testing

1. **Deploy to VPS** (see QUICKSTART.md)
2. **Set up monitoring** (journalctl, cost logs)
3. **Add real job applications** (Career Twin)
4. **Launch first SDR campaign** (5-10 prospects)
5. **Iterate based on feedback**

---

**Testing complete? Proceed to deployment: `/root/QUICKSTART.md`**
