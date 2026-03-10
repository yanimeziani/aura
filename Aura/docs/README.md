# 🤖 AI Agency System

> **Onboarding (one place):** **[docs/ONBOARDING.md](ONBOARDING.md)** — setup, modes, `aura` CLI, logs, gateway, chat.

> **Autonomous business infrastructure**  
> Multi-agent systems working 24/7 under your command
> 
> ⚠️ **Reality Check**: Zero employees ≠ zero effort. You become the systems operator. We provide the infrastructure, training, and support—you provide the expertise.

<div align="center">

[![React](https://img.shields.io/badge/React-19.2.0-61DAFB?logo=react)](https://reactjs.org/)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.9.3-3178C6?logo=typescript)](https://www.typescriptlang.org/)
[![Python](https://img.shields.io/badge/Python-3.11+-3776AB?logo=python)](https://python.org/)
[![CrewAI](https://img.shields.io/badge/CrewAI-Latest-00D4AA)](https://crewai.com/)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker)](https://docker.com/)

</div>

## 🚀 Quick Start (30 seconds)

```bash
# 1. Clone & enter
git clone <repo> && cd <repo>

# 2. Start the system
cd sovereign-stack && docker-compose up -d

# 3. Access your AI agency
open http://localhost:3000     # Dashboard
open http://localhost:8080     # n8n workflows
```

## 📋 What You're Building

This isn't just another app—it's a complete autonomous business infrastructure:

| Component | Purpose | Tech Stack |
|-----------|---------|------------|
| 🎛️ **Web Dashboard** | Real-time monitoring & control | React 19 + TypeScript + Vite |
| 🧠 **AI Agents** | Autonomous wealth generation | Python + CrewAI + LangChain |
| 🏗️ **Infrastructure** | Self-hosted deployment | Docker + Caddy + PostgreSQL |

## 🎯 Step-by-Step Setup

### Step 0: Knowledge Investment (30 minutes)
**Before you start**: Understand what you're building
- 🎧 Listen to our [NotebookLM audio walkthrough](your-link-here)
- 📺 Watch the [system explainer video](your-link-here) 
- 📚 Read the [captain's handbook](your-link-here)

💡 **Reality**: You're becoming a fleet commander. These 30 minutes save 30 hours later.

### Step 1: Infrastructure (2 minutes)
```bash
cd sovereign-stack
docker-compose up -d
# ✅ Caddy, PostgreSQL, Redis, n8n running
```

### Step 2: AI Wealth Agents (1 minute)
```bash
cd ai_agency_wealth
docker build -t ai-agency-wealth .
docker run -d --name wealth-agent ai-agency-wealth
# ✅ Multi-agent system activated
```

### Step 3: Web Dashboard (30 seconds)
```bash
cd ai_agency_web
npm install && npm run dev
# ✅ Dashboard at http://localhost:3000
```

## 📚 Training & Support

### Free Learning Resources
- 🎧 **Audio Guides**: NotebookLM-generated explanations for every component
- 📺 **Video Tutorials**: Step-by-step walkthroughs of complex systems
- 📖 **Documentation**: Auto-generated guides that evolve with the system

### Paid Training Programs
| Program | Duration | Cost | Outcome |
|---------|----------|------|---------|
| **Captain's Course** | 2 weeks | $497 | Full system mastery |
| **Agent Programming** | 1 week | $297 | Custom agent development |
| **Infrastructure Ops** | 3 days | $197 | Production deployment |
| **Trading Strategies** | 1 week | $397 | Algorithmic trading setup |

### Support Options
- 📧 **Email Support**: training@aiagency.system
- 💬 **Discord Community**: Join 500+ captains sharing strategies
- 🎫 **Priority Support**: $97/month for 24/7 access to engineers

## 🏢 Your AI Company Structure

```
AI AGENCY ENTERPRISE
├── 📊 Research Department (AI-powered)
│   ├── Market trend analysis
│   ├── Opportunity identification  
│   └── Competitor monitoring
│
├── 💰 Trading Department (Autonomous)
│   ├── Automated position management
│   ├── Multi-exchange operations (Coinbase, Wealthsimple)
│   └── Risk assessment
│
├── 🧮 Accounting Department (Real-time)
│   ├── Portfolio tracking
│   ├── Tax reporting
│   └── Profitability analysis
│
├── 🏥 Health Department (Monitoring)
│   ├── System monitoring
│   ├── Performance optimization
│   └── Error recovery
│
└── 🪙 Crypto Department (DeFi Focus)
    ├── DeFi opportunities
    ├── Staking strategies
    └── Yield farming

⚠️  YOU ARE HERE: The human captain managing the fleet
```

## 🚨 Systems Operator Reality Check

### What "Zero Employee" Actually Means
- ✅ **No payroll, no HR, no office politics**
- ✅ **24/7 operation without breaks**
- ✅ **Consistent execution without emotions**
- ❌ **No human intuition or creativity**
- ❌ **No adaptability to black swan events**
- ❌ **No legal or regulatory navigation**

### Your Role as Systems Operator
```
TRADITIONAL COMPANY          AI AGENCY SYSTEM
├─ CEO                       ├─ YOU (Strategic oversight)
├─ CTO                       ├─ YOU (System architecture)  
├─ Dev Team                  ├─ AI Agents (Execution)
├─ Trading Floor             ├─ AI Agents (Execution)
├─ Accounting Dept           ├─ AI Agents (Execution)
└─ Operations                └─ Infrastructure (Automated)

You don't manage people. You manage complex systems.
You don't solve operational problems. You prevent them.
You don't execute trades. You design and monitor strategies.
```

### Required Knowledge Areas
| Area | Why You Need It | Learning Resource |
|------|----------------|-------------------|
| **System Architecture** | Debug when agents fail | 📺 [Video: System Overview](link) |
| **Trading Concepts** | Set realistic parameters | 📚 [Trading Primer](link) |
| **Risk Management** | Prevent catastrophic losses | 🎧 [Risk Audio Guide](link) |
| **Docker Basics** | Fix deployment issues | 📖 [Docker Essentials](link) |
| **Database Queries** | Analyze performance | 🔧 [SQL Quickstart](link) |

## 💡 How It Works

### 1. Autonomous Decision Making (You Set Parameters)
```python
# You configure the strategy
strategy = {
    'risk_tolerance': 0.02,      # 2% max loss per trade
    'profit_target': 0.05,       # 5% profit target
    'max_positions': 10,         # Maximum concurrent positions
    'stop_loss': 0.03            # 3% stop loss
}

# AI executes within your boundaries
opportunity = research_agent.analyze_market(strategy)
trade = trading_agent.execute(opportunity, strategy)
```

### 2. Real-Time Dashboard (You Monitor)
```typescript
// You watch the metrics
const alerts = useCriticalAlerts();  // Immediate attention
const trends = usePerformanceTrends(); // Weekly patterns
const anomalies = useAnomalies();      // Unusual behavior

// AI handles the execution
const execution = aiAgent.execute();   // Automated
```

### 3. Infrastructure Automation (You Maintain)
```yaml
# You design the system
services:
  monitoring:    # What to watch
  alerting:    # When to notify  
  recovery:    # How to fix issues

# Infrastructure runs itself
# But you need to understand logs
# And know when to intervene
```

## 🎛️ Control Your Agency

### Dashboard Commands
```bash
# View real-time logs
cd ai_agency_web && npm run dev

# Check agent status
curl http://localhost:8000/status

# Monitor workflows
open http://localhost:8080
```

### Wealth Management
```bash
# Start trading agents
cd ai_agency_wealth && python main.py

# View portfolio
curl http://localhost:8000/portfolio

# Check profits
curl http://localhost:8000/pnl
```

## 🛠️ Development Commands

| Command | Purpose | Location |
|---------|---------|----------|
| `npm run dev` | Start dashboard | `ai_agency_web/` |
| `npm run build` | Build for production | `ai_agency_web/` |
| `npm run lint` | Check code quality | `ai_agency_web/` |
| `docker build -t ai-agency-wealth .` | Build agents | `ai_agency_wealth/` |
| `docker-compose up -d` | Start infrastructure | `sovereign-stack/` |

## 🔧 Configuration

### Environment Variables
```bash
# Required for AI agents
OPENAI_API_KEY=your_key_here
COINBASE_API_KEY=your_key_here
WEALTHSIMPLE_API_KEY=your_key_here

# Database settings
POSTGRES_DB=ai_agency
REDIS_URL=redis://localhost:6379
```

### API Endpoints
```
GET  /api/portfolio        # Current holdings
GET  /api/performance       # P&L tracking
GET  /api/agents/status    # Agent health
POST /api/trades/execute   # Manual trades
GET  /api/market/data     # Market insights
```

## 📊 Monitoring & Alerts

### Built-in Monitoring
- **Agent Health**: Real-time status of all AI agents
- **Portfolio Tracking**: Live P&L across all exchanges
- **System Metrics**: CPU, memory, network usage
- **Trade History**: Complete audit trail

### Automated Alerts
```typescript
// Configure alerts in dashboard
const alerts = {
  profitTarget: 1000,      // $1000 daily profit
  lossLimit: -500,         // Stop at $500 loss
  agentTimeout: 300,       // 5 minutes
  marketVolatility: 0.1    // 10% price swing
};
```

## 🚀 Deployment Options

### Quick Deploy (Recommended)
```bash
cd sovereign-stack
docker-compose up -d
```

### Production Deploy
```bash
# Build optimized images
docker-compose -f docker-compose.prod.yml up -d

# SSL certificates auto-renewed
# Database backups automated
# Monitoring via Prometheus/Grafana
```

### Development Mode
```bash
# Frontend hot-reload
cd ai_agency_web && npm run dev

# Backend debug mode
cd ai_agency_wealth && python main.py --debug
```

## 🎯 Success Metrics (Systems Performance)

Track your operational excellence, not just financial outcomes:

| Metric | Target | What It Measures |
|--------|--------|------------------|
| **System Uptime** | 99.9% | Infrastructure reliability |
| **Response Time** | <5 minutes | Your alertness to anomalies |
| **Parameter Optimization** | 2-3/week | Your continuous improvement |
| **Learning Hours** | 5/week | Your professional development |
| **Documentation Updates** | Weekly | Your systematic approach |

### Financial Outcomes (Secondary Metrics)
| Target | Timeline | Operator Action Required |
|--------|----------|------------------------|
| **Consistent Operation** | Week 1-2** | System validation |
| **Strategy Refinement** | Month 1** | Parameter tuning |
| **Risk Management** | Month 3** | Advanced safeguards |
| **Portfolio Diversification** | Year 1** | Multi-strategy deployment |

**Financial results vary based on market conditions, strategy parameters, and operational expertise**

## 🆘 Troubleshooting (Captain's Emergency Kit)

### When Agents Stop Trading
```bash
# 1. Check agent health
curl http://localhost:8000/health

# 2. Review logs for errors
docker logs wealth-agent | tail -50

# 3. Verify API connections
curl -H "Authorization: Bearer $API_KEY" https://api.coinbase.com

# 4. Restart with fresh config
docker-compose restart
```

### When Dashboard Shows Red
```bash
# 1. Check service status
docker ps

# 2. Review infrastructure logs
docker-compose logs | grep ERROR

# 3. Reset if needed (data preserved)
docker-compose down && docker-compose up -d
```

### When Profits Drop
- 📊 **Check market conditions**: Bear market?
- 🔧 **Review strategy parameters**: Too aggressive?
- 📈 **Analyze trade history**: Pattern breakdown?
- 🎯 **Backtest new parameters**: Simulation first

### Emergency Contacts
- 📧 **Technical Issues**: support@aiagency.system
- 💬 **Strategy Discussion**: Discord community
- 🚨 **Critical Outage**: 24/7 hotline (paid support)

## 📚 Training & Support

### Free Learning Resources
- 🎧 **Audio Guides**: NotebookLM-generated explanations for every component
- 📺 **Video Tutorials**: Step-by-step walkthroughs of complex systems
- 📖 **Documentation**: Auto-generated guides that evolve with the system

### Paid Training Programs
| Program | Duration | Cost | Outcome |
|---------|----------|------|---------|
| **Captain's Course** | 2 weeks | $497 | Full system mastery |
| **Agent Programming** | 1 week | $297 | Custom agent development |
| **Infrastructure Ops** | 3 days | $197 | Production deployment |
| **Trading Strategies** | 1 week | $397 | Algorithmic trading setup |

### Support Options
- 📧 **Email Support**: training@aiagency.system
- 💬 **Discord Community**: Join 500+ captains sharing strategies
- 🎫 **Priority Support**: $97/month for 24/7 access to engineers

## 🔮 Next Steps

1. **Customize your agents** in `ai_agency_wealth/agents/`
2. **Add new exchanges** by extending the trading agents
3. **Create workflows** in n8n at `http://localhost:8080`
4. **Monitor performance** and optimize strategies
5. **Scale horizontally** with Docker Swarm or Kubernetes

---

<div align="center">

**Built for systems operators who understand: Infrastructure scales, but expertise compounds.**

*Zero employees. Zero shortcuts. Full operational responsibility.*

### 🎧 Learning Resources
- [NotebookLM Audio Overview](link) - Listen while you build
- [Video Walkthrough Series](link) - See it in action  
- [Systems Documentation](link) - Deep dive reference

</div>