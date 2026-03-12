# Agentic AI Projects Built Today

## 🎯 What We Built

Two production-ready agentic AI applications using our Pegasus/Cerberus stack:

1. **Career Digital Twin** - AI agent representing you to employers
2. **SDR Agent** - Automated B2B sales outreach with personalization

## 📁 Project Structure

```
/root/
├── cerberus/
│   ├── configs/
│   │   ├── career-twin-agent.json          # Career Twin config
│   │   └── sdr-agent.json                   # SDR config
│   ├── runtime/cerberus-core/prompts/
│   │   ├── career_twin_prompt.txt           # 1,400-word system prompt
│   │   └── sdr_agent_prompt.txt             # 1,800-word system prompt
│   ├── scripts/
│   │   ├── init-career-twin-memory.sh       # Memory initialization
│   │   └── init-sdr-memory.sh               # Memory initialization
│   └── specs/
│       ├── career-digital-twin.md           # Full architecture
│       └── sdr-agent.md                     # Full architecture
│
├── dragun-app/
│   ├── app/
│   │   ├── [locale]/career-twin/           # Web interface
│   │   └── api/career-twin/                # REST APIs
│   ├── components/career-twin/
│   │   └── CareerTwinDashboard.tsx         # React dashboard
│   └── supabase/migrations/
│       ├── 20260303000001_career_twin_tables.sql
│       └── 20260303000002_sdr_tables.sql
│
├── QUICKSTART.md           # Step-by-step deployment guide
├── TESTING_GUIDE.md        # Testing instructions
├── PROJECT_SUMMARY.md      # Detailed project overview
└── README_AGENTS.md        # This file
```

## 🚀 Quick Deploy (5 Commands)

```bash
# 1. Initialize memory structures
cd /root/cerberus
bash scripts/init-career-twin-memory.sh
bash scripts/init-sdr-memory.sh

# 2. Configure API keys (replace YOUR_KEY)
cat > ~/.cerberus/career-twin.env <<EOF
OPENROUTER_API_KEY=YOUR_KEY
CERBERUS_AGENT=career_twin
CERBERUS_CONFIG=/root/cerberus/configs/career-twin-agent.json
