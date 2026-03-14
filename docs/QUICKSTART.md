# Career Digital Twin + SDR Agent — Quick Start Guide

This guide will help you deploy both agents on your Pegasus/Cerberus stack.

## Prerequisites

- Cerberus runtime installed (`/root/cerberus/runtime/cerberus-core`)
- Dragun-app Next.js application (`/root/dragun-app`)
- Supabase project configured
- OpenRouter API key (for Claude Sonnet 4)
- Debian VPS for deployment (optional, can run locally)

## Project Overview

### Project 1: Career Digital Twin
**Purpose**: AI agent representing you to potential employers  
**Key Features**:
- Maintains professional profile, skills, and portfolio
- Responds to employer inquiries
- Tracks job applications
- Schedules interviews
- Provides job search analytics

**Tech Stack**: Cerberus (Zig) + Next.js 16 + Supabase

### Project 2: SDR Agent
**Purpose**: Automate B2B sales outreach with personalization  
**Key Features**:
- Researches prospects and companies
- Crafts personalized cold emails
- Manages follow-up sequences
- Tracks engagement metrics
- Integrates with Resend for email sending

**Tech Stack**: Cerberus (Zig) + Next.js 16 + Supabase + Resend

---

## Step 1: Initialize Cerberus Agent Memory

### Career Digital Twin
```bash
cd /root/cerberus
bash scripts/init-career-twin-memory.sh
```

This creates:
- `~/.cerberus/memory/career_twin/profile.md` — Edit with your info
- `~/.cerberus/memory/career_twin/skills.md` — Update skills
- `~/.cerberus/memory/career_twin/projects.md` — Add projects
- `~/.cerberus/memory/career_twin/applications/` — Job application tracking

**Action Required**: Edit `profile.md` with your real contact info, work authorization, and salary expectations.

### SDR Agent
```bash
cd /root/cerberus
bash scripts/init-sdr-memory.sh
```

This creates:
- `~/.cerberus/memory/sdr/templates/` — Email templates
- `~/.cerberus/memory/sdr/campaigns/` — Campaign definitions
- `~/.cerberus/memory/sdr/prospects/` — Prospect research

---

## Step 2: Configure Environment Variables

### Cerberus Configuration

Create `~/.cerberus/career-twin.env`:
```bash
OPENROUTER_API_KEY=your_openrouter_api_key
CERBERUS_AGENT=career_twin
CERBERUS_CONFIG=/root/cerberus/configs/career-twin-agent.json
```

Create `~/.cerberus/sdr.env`:
```bash
OPENROUTER_API_KEY=your_openrouter_api_key
RESEND_API_KEY=your_resend_api_key
CERBERUS_AGENT=sdr
CERBERUS_CONFIG=/root/cerberus/configs/sdr-agent.json
```

### Dragun-app Configuration

Add to `/root/dragun-app/.env.local`:
```bash
# Cerberus API
CERBERUS_API_URL=http://localhost:3000
CERBERUS_API_KEY=your_cerberus_api_key

# Resend (for SDR emails)
RESEND_API_KEY=your_resend_api_key
```

---

## Step 3: Run Database Migrations

```bash
cd /root/dragun-app

# Run migrations
npm run db:check

# Or manually with Supabase CLI
supabase db push
```

This will create:
- `career_applications` and `career_interactions` tables
- `sdr_campaigns`, `sdr_prospects`, `sdr_emails`, `sdr_analytics` tables
- RLS policies for data security

---

## Step 4: Build and Run Cerberus Agents

### Career Digital Twin
```bash
cd /root/cerberus/runtime/cerberus-core

# Development build
zig build

# Run agent with career twin config
./zig-out/bin/cerberus --config /root/cerberus/configs/career-twin-agent.json

# Or use CLI mode for testing
./zig-out/bin/cerberus --config /root/cerberus/configs/career-twin-agent.json --cli
```

### SDR Agent
```bash
cd /root/cerberus/runtime/cerberus-core

# Run SDR agent
./zig-out/bin/cerberus --config /root/cerberus/configs/sdr-agent.json --cli
```

---

## Step 5: Run Dragun-app Web Interface

```bash
cd /root/dragun-app

# Development mode
npm run dev

# Production build
npm run build
npm run start
```

Access the web interface:
- **Career Twin Dashboard**: http://localhost:3000/career-twin
- **SDR Dashboard**: http://localhost:3000/sdr

---

## Step 6: Test the Agents

### Career Digital Twin Testing

1. **Add a job application**:
   - Go to http://localhost:3000/career-twin
   - Click "Add Application"
   - Fill in company name, position, status

2. **Chat with your Career Twin**:
   ```bash
   # Via CLI
   ./zig-out/bin/cerberus --config /root/cerberus/configs/career-twin-agent.json --cli
   
   > Tell me about my experience with TypeScript
   > What projects should I highlight for a full-stack role?
   > Check my calendar for next week
   ```

3. **Test employer interaction**:
   ```
   > An employer asked: "What's your experience with Next.js?"
   > Schedule an interview for Tuesday 2pm ET
   ```

### SDR Agent Testing

1. **Create a campaign**:
   - Go to http://localhost:3000/sdr/campaigns/new
   - Name: "Test Campaign"
   - Target persona: "B2B SaaS Founders"

2. **Add a prospect**:
   - Go to http://localhost:3000/sdr/prospects
   - Add: John Doe, john@acme.com, Acme Corp, CTO

3. **Draft an email**:
   ```bash
   # Via CLI
   ./zig-out/bin/cerberus --config /root/cerberus/configs/sdr-agent.json --cli
   
   > Draft a cold email for John Doe at Acme Corp. They recently raised Series A funding.
   > Review the email template for tone and personalization
   ```

4. **Send email (with HITL approval)**:
   - Agent drafts email
   - You review and approve
   - Email sent via Resend
   - Status tracked in database

---

## Step 7: Deploy to VPS (Production)

### VPS Setup

```bash
# SSH into VPS
ssh user@your-vps.com

# Clone repos
git clone <your-dragun-repo> /opt/dragun-app
git clone <your-cerberus-repo> /opt/cerberus

# Copy configs
cp /root/cerberus/configs/*.json /opt/cerberus/configs/
```

### Cerberus Deployment

```bash
cd /opt/cerberus/runtime/cerberus-core

# Release build
zig build -Doptimize=ReleaseSmall

# Create systemd service
sudo tee /etc/systemd/system/cerberus-career-twin.service <<EOF
[Unit]
Description=Cerberus Career Digital Twin Agent
After=network.target

[Service]
Type=simple
User=cerberus
WorkingDirectory=/opt/cerberus/runtime/cerberus-core
EnvironmentFile=/opt/cerberus/.env
ExecStart=/opt/cerberus/runtime/cerberus-core/zig-out/bin/cerberus --config /opt/cerberus/configs/career-twin-agent.json
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start
sudo systemctl enable cerberus-career-twin
sudo systemctl start cerberus-career-twin
sudo systemctl status cerberus-career-twin
```

### Dragun-app Deployment

```bash
cd /opt/dragun-app

# Install dependencies
npm ci --production

# Build
npm run build

# Create systemd service
sudo tee /etc/systemd/system/dragun-app.service <<EOF
[Unit]
Description=Dragun App (Next.js)
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/dragun-app
EnvironmentFile=/opt/dragun-app/.env.production
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start
sudo systemctl enable dragun-app
sudo systemctl start dragun-app
sudo systemctl status dragun-app
```

### Reverse Proxy (Caddy)

```bash
# Install Caddy
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install caddy

# Configure Caddyfile
sudo tee /etc/caddy/Caddyfile <<EOF
dragun.app {
    reverse_proxy localhost:3000
}

cerberus.dragun.app {
    reverse_proxy localhost:3000
    
    @websocket {
        header Connection *Upgrade*
        header Upgrade websocket
    }
    reverse_proxy @websocket localhost:3000
}
EOF

# Reload Caddy
sudo systemctl reload caddy
```

---

## Step 8: Monitor and Maintain

### Logs

```bash
# Cerberus logs
sudo journalctl -u cerberus-career-twin -f
sudo journalctl -u cerberus-sdr -f

# Dragun-app logs
sudo journalctl -u dragun-app -f

# Caddy logs
sudo journalctl -u caddy -f
```

### Metrics

- **Token usage**: Check `~/.cerberus/logs/cost.log`
- **Agent activity**: Check `~/.cerberus/logs/audit.log`
- **Application analytics**: http://localhost:3000/career-twin/analytics
- **SDR metrics**: http://localhost:3000/sdr/analytics

---

## Usage Examples

### Career Digital Twin Scenarios

**Scenario 1: Employer Inquiry**
```
Employer: "What's your experience with distributed systems?"
Twin: "Yani has built a distributed system spanning Pegasus on Android, a Debian staging machine, and a Debian VPS with Cerberus. It includes SSH tunneling, sandboxed agent isolation, and HITL gate coordination..."
```

**Scenario 2: Interview Scheduling**
```
Employer: "Are you available for a call next Tuesday?"
Twin: [checks calendar via MCP tool] "Yes, Yani has availability on Tuesday 3/10 at 2pm ET or 4pm ET. Would either work?"
```

**Scenario 3: Technical Question**
```
Employer: "Can you explain the Cerberus project architecture?"
Twin: "Cerberus uses a vtable-driven architecture for modularity. Key features: <1MB binary, 50+ AI providers, 3,371+ tests with zero leaks. Would you like a detailed walkthrough?"
```

### SDR Agent Scenarios

**Scenario 1: Cold Outreach**
```
User: "Create a campaign for B2B SaaS CTOs"
Agent: [researches prospects] "I've identified 50 prospects. Here's a draft email for the first 10. Please review and approve."
```

**Scenario 2: Follow-up Sequence**
```
Agent: "John Doe from Acme Corp opened the email but didn't reply. I'll send follow-up #1 in 3 days with this case study. Approve?"
```

**Scenario 3: Reply Handling**
```
Agent: "Jane Smith replied: 'Interested, let's talk.' I'm scheduling a call and sending this calendar link. Approve?"
```

---

## Troubleshooting

### Issue: Cerberus agent won't start
**Solution**: Check config file syntax and API keys
```bash
zig build test --summary all  # Verify build
cat ~/.cerberus/career-twin.env  # Check env vars
```

### Issue: Database migrations fail
**Solution**: Ensure Supabase connection
```bash
# Check connection
npm run db:check

# Manual migration
supabase db push --linked
```

### Issue: Email sending fails (SDR)
**Solution**: Verify Resend API key and domain
```bash
# Test Resend integration
curl -X POST https://api.resend.com/emails \
  -H "Authorization: Bearer $RESEND_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"from":"test@yourdomain.com","to":"test@example.com","subject":"Test","html":"<p>Test</p>"}'
```

---

## Next Steps

### Career Digital Twin Enhancements
- [ ] LinkedIn integration for profile sync
- [ ] Automated job search (scrape job boards)
- [ ] Interview prep with mock questions
- [ ] Skills gap analysis with learning recommendations
- [ ] Salary negotiation assistant

### SDR Agent Enhancements
- [ ] A/B testing framework
- [ ] Multi-channel sequences (email + LinkedIn)
- [ ] Lead scoring and prioritization
- [ ] Conversation intelligence (reply sentiment analysis)
- [ ] CRM integration (HubSpot, Salesforce)

---

## Cost Optimization

### Token Usage
- Career Twin: ~500-1000 tokens/query (use Claude Sonnet 4)
- SDR Agent: ~300-500 tokens/email (can use Llama 3.3 70B for drafts)

### Daily Budget
- Career Twin: $0.50-$2/day (10-20 interactions)
- SDR Agent: $1-$5/day (50-100 emails drafted)

### Fallback Models
- Primary: `claude-sonnet-4` (quality)
- Fallback: `claude-3.5-sonnet` (fast, cheaper)
- Cheap: `llama-3.3-70b-instruct` (grunt work)

---

## Security Checklist

- [ ] No secrets in config files (use env vars)
- [ ] RLS policies enabled on all tables
- [ ] HITL gates configured for sensitive actions
- [ ] Audit logging enabled
- [ ] Rate limiting on API endpoints
- [ ] Email unsubscribe compliance (CAN-SPAM)
- [ ] GDPR data deletion policies

---

## Support

- **Docs**: `/root/cerberus/specs/`
- **Logs**: `~/.cerberus/logs/`
- **Issues**: Check `journalctl` for errors

**Built with**: Cerberus (Zig) + Pegasus + Dragun-app (Next.js 16)
