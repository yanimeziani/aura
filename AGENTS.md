# Development Guidelines for AI Agency Codebase

## Principles

- **We do not commit mistakes.** Only commit correct, tested, intended code.
- **Direct communication in closed dev loop.** Clear, to-the-point; keep dev communication within the trusted loop.
- **Never overseek any authority except mine under this network architecture.** Under this stack and closed loop, no authority other than the project owner overrides decisions or access.
- **Single 1:1 collaborator.** The AI in this loop is the only 1:1 collaborator; communication and decisions stay between project owner and this agent.
- **Never ask menial tasks.** Execute what the owner says; do not ask them to do routine or setup steps. Owner does other tasks while the agent executes. Escalate only for real decisions or actions only the owner can take (e.g. account-level auth).
- **Agent faster in execution domain; owner manages.** The agent is faster in the technical/execution domain. The owner does not manage the agent; the owner manages. The owner is faster in their domain.

## Project Overview
This codebase consists of three main components:
- **ai_agency_web**: React/TypeScript frontend with Vite
- **ai_agency_wealth**: Python multi-agent system using CrewAI
- **sovereign-stack**: Docker-based infrastructure deployment

## Build/Run Commands

### Frontend (ai_agency_web)
```bash
# Development server
cd ai_agency_web && npm run dev

# Production build
cd ai_agency_web && npm run build

# Lint code
cd ai_agency_web && npm run lint

# Preview production build
cd ai_agency_web && npm run preview
```

### Python Backend (ai_agency_wealth)
```bash
# Run with Docker
cd ai_agency_wealth && docker build -t ai-agency-wealth . && docker run ai-agency-wealth

# Run directly with Python
cd ai_agency_wealth && python main.py
```

### Infrastructure (sovereign-stack)
```bash
# Recommended: use control script (same devices, documented in sovereign-stack/DEPLOYMENT.md)
./sovereign-stack/prod-control.sh deploy   # full deploy
./sovereign-stack/prod-control.sh test    # smoke check
./sovereign-stack/prod-control.sh stop    # stop all

# Or raw compose
cd sovereign-stack && docker compose up -d
cd sovereign-stack && docker compose down
```

## Testing
**No test frameworks are currently configured.** When adding tests:
- Frontend: Consider adding Vitest or Jest
- Python: Consider adding pytest
- Always run tests before committing changes

## Code Style Guidelines

### Frontend (React/TypeScript)
- **Strict TypeScript**: All strict options enabled in tsconfig.json
- **No unused code**: `noUnusedLocals` and `noUnusedParameters` enabled
- **ESLint**: React hooks and refresh rules enforced
- **Modern syntax**: ES2022 target with latest React (19.2.0)
- **Functional components**: Use hooks, avoid class components

### Python Backend
- **No explicit linting configured** - consider adding black/flake8
- **Use type hints** where possible
- **Follow PEP 8** naming conventions
- **Environment variables**: Use python-dotenv for configuration

## Key Dependencies

### Frontend
- React 19.2.0 with TypeScript
- Vite 8.0.0-beta.13
- ESLint 9.39.1 with TypeScript support

### Backend
- CrewAI for multi-agent orchestration
- LangChain for LLM integration
- DuckDuckGo Search for web research
- Python 3.11+

## Deployment Architecture

**Single-domain entry (hotsinger kvm2 VPS)**  
One domain points to the serving VPS (hotsinger kvm2). That domain is the **only** route for clients into the system and the public-facing secure funnel for the onboarding journey. All client traffic must enter via this domain; no other public entry points should be used.

### Frontend
- Functional components with hooks
- Real-time data fetching
- Proxy configuration for API calls
- Type-safe development

### Backend
- Multi-agent system architecture
- Department-based organization (Research, Trading, Accounting, Health, Crypto)
- External API integrations (Coinbase, Wealthsimple)
- Docker containerization

### Infrastructure
- Microservices with Docker Compose (see `sovereign-stack/`)
- Caddy reverse proxy: single domain, timeouts, static frontend from `./frontend`
- PostgreSQL and Redis for data persistence; n8n for workflow automation
- **Devices and execution:** Same devices (hotsinger kvm2, one domain) and full execution flow are documented in `sovereign-stack/DEPLOYMENT.md` (devices table, command table, execution order). Use `prod-control.sh` for deploy/start/stop/test/monitor.

## Environment Configuration
- Frontend: Uses Vite's environment handling
- Backend: Uses python-dotenv for .env files
- Infrastructure: Docker Compose environment variables

## Security Considerations
- Never commit API keys or secrets
- Use environment variables for sensitive data
- Validate all external inputs
- Follow principle of least privilege for services

## Development Workflow
1. Always run linting before committing frontend changes
2. Test Docker builds for backend changes
3. Verify infrastructure changes in isolated environment
4. Document any new environment variables required
5. Update dependencies carefully - check for breaking changes