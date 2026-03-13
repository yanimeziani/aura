# 1-Hour Execution Prompt

**Timebox:** 1 hour on this machine  
**Workspace:** `/home/yani`  
**Context:** AI Agency codebase (ai_agency_web, ai_agency_wealth, sovereign-stack). Single public entry: one domain → Hostinger KVM2 VPS → secure client funnel/onboarding. Follow **AGENTS.md** for commands and conventions.

---

## Your objective

Execute the phases below in order. Stay within 1 hour. If you run over, complete the current phase and stop; note what’s left for the next run. Prefer automation (scripts/commands) over manual steps where possible.

---

## Phase 1 — Environment and build verification (~15 min)

1. **Confirm workspace layout**  
   Ensure these exist under `/home/yani`: `ai_agency_web/`, `ai_agency_wealth/`, `sovereign-stack/`, and `AGENTS.md`.

2. **Frontend**  
   - From `/home/yani`: run `cd ai_agency_web && npm ci` (or `npm install` if no lockfile).  
   - Run `npm run lint`. Fix any reported errors.  
   - Run `npm run build`. Build must succeed.

3. **Backend**  
   - From `/home/yani`: run `cd ai_agency_wealth && docker build -t ai-agency-wealth .`.  
   - Build must succeed (no need to run the container yet).

4. **Infrastructure**  
   - From `/home/yani`: ensure `sovereign-stack/.env` exists and has at least `DOMAIN` set (single domain for Hostinger KVM2).  
   - Run `cd sovereign-stack && docker-compose config`. Config must be valid.

**Exit condition:** All builds and config checks pass; lint clean for frontend.

---

## Phase 2 — Stack and smoke checks (~20 min)

1. **Start stack**  
   From `/home/yani`: `cd sovereign-stack && docker-compose up -d`.  
   Wait for services to be healthy (e.g. Caddy, n8n, Postgres, Redis).

2. **Caddy / single-domain entry**  
   - Inspect `sovereign-stack/Caddyfile`: it must use `{$DOMAIN}` as the sole public server block (single-domain funnel).  
   - If `DOMAIN` is a real hostname and this machine can resolve it: curl the domain (or `https://$DOMAIN/automation/` / `/api/` as appropriate) and confirm non-5xx. If no DNS or TLS yet, note “DNS/TLS not validated on this run.”

3. **Frontend dev smoke**  
   - Start frontend: `cd ai_agency_web && npm run dev` (background).  
   - Request `http://localhost:5173` (or the port Vite prints). Expect 200 and the app shell.  
   - Stop the dev server when done.

4. **Backend container smoke**  
   - Run: `docker run --rm ai-agency-wealth` (or the same run command from AGENTS.md) with a short timeout.  
   - Confirm it starts without immediate crash (logs show startup; no need to run a full workflow).

**Exit condition:** Stack up; Caddyfile correct; frontend and backend start successfully.

---

## Phase 3 — Security and config audit (~15 min)

1. **Secrets**  
   - Ensure no API keys, passwords, or tokens are committed in repo files (especially under ai_agency_web, ai_agency_wealth, sovereign-stack).  
   - Confirm sensitive values are only in `.env` or env and that `.env` is gitignored.

2. **Single entry**  
   - Re-read “Deployment Architecture” in AGENTS.md.  
   - Confirm no other public entry points are documented or configured (only the one domain → Hostinger KVM2).

3. **Infrastructure**  
   - Check sovereign-stack: exposed ports (80/443 on Caddy are expected); n8n bound to 127.0.0.1 only if intended.  
   - Note any finding (e.g. “n8n only on localhost” or “ports 80/443 public”).

**Exit condition:** No secrets in repo; single-entry principle confirmed; infra exposure noted.

---

## Phase 4 — Documentation and handoff (~10 min)

1. **AGENTS.md**  
   - If you changed build/lint/run steps or added env vars, update AGENTS.md so the next run has accurate commands.

2. **Execution log**  
   - Append a short “Run log” to this file or create `EXECUTION_LOG_1H.txt` with:  
     - Date and time.  
     - Phases completed (1–4).  
     - Any failures or skipped steps and why.  
     - One-line “Next run: …” if something was left for later.

**Exit condition:** AGENTS.md accurate; run summarized for next execution.

---

## If you have extra time

- Add a single `.env.example` in sovereign-stack (no real values) listing required variables (e.g. `DOMAIN`, `N8N_*`, `POSTGRES_*`).  
- Propose one concrete improvement to the onboarding funnel (e.g. a health/readiness endpoint or a single “status” page path) and add it as a one-line “Suggested improvement” in the run log.

---

## Success criteria (end of hour)

- Frontend: lint clean, build passes.  
- Backend: Docker image builds.  
- Sovereign-stack: `docker-compose config` valid; stack starts; Caddyfile uses single `{$DOMAIN}`.  
- No secrets in repo; single-entry architecture confirmed.  
- AGENTS.md and run log updated so the next 1-hour run can continue from a clear state.

Execute this prompt on this machine; report what you did and what you deferred.
