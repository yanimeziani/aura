# Production Readiness: Cerberus & Pegasus

Assessment of production readiness for the Cerberus runtime and Pegasus control plane (Android + pegasus-compat API).

---

## Summary

| Component | Readiness | Notes |
|-----------|-----------|--------|
| **Cerberus runtime** | **Deployable with caveats** | Mature core, 3,230+ tests, strong security; pre-1.0, no API/CLI stability guarantee |
| **pegasus-compat API** | **Operational** | Full REST surface for Pegasus app; used in VPS deploy; change default credentials |
| **Pegasus (Android)** | **Alpha** | Feature-complete for current flows; operator UI (Spec 006) proposed, not built |

---

## 1. Cerberus Runtime

### Strengths

- **Test coverage:** 3,230+ Zig tests; CI referenced in upstream README.
- **Binary:** ~678 KB ReleaseSmall, ~1 MB RAM, &lt;2 ms startup; single static binary, no runtime deps.
- **Security (documented):**
  - Gateway binds `127.0.0.1` by default; no public bind without tunnel or `allow_public_bind`.
  - Pairing required for Web/gateway access.
  - Workspace-only filesystem, sandbox (Landlock/Firejail/Bubblewrap/Docker), encrypted secrets (ChaCha20-Poly1305), resource limits, audit logging.
- **Deployment:** VPS path via `deploy/meziani-dragun/deploy_vps.sh` (binary + config + systemd). Spec 005 defines production-ready roster (meziani-main, dragun-devsecops, dragun-growth).
- **Observability:** `cerberus doctor`, `cerberus status`, `channel status`; file/log observer backends; Prometheus/OTel-ready observer vtable.

### Caveats

- **Pre-1.0:** README states *"No stability guarantees yet — the project is pre-1.0, config and CLI may change between releases."*
- **Zig version:** Must use **Zig 0.15.2** exactly; other versions unsupported.
- **Claude CLI:** If using Claude Pro path, `claude auth login` must be validated on the VPS (noted in Spec 005).

**Verdict:** Suitable for production deployment **if** you accept possible config/CLI churn and pin Zig 0.15.2. Security and operational story are strong.

---

## 2. pegasus-compat API (pegasus-api)

### Role

Python FastAPI app that exposes the Pegasus API so the Pegasus Android app can talk to Cerberus. Deployed as `pegasus-api` (default port 8080) alongside the Cerberus gateway on the VPS.

### Endpoints (aligned with Pegasus app)

- **Auth:** `POST /auth/login`, `/auth/logout`, `/auth/change-password`
- **Health:** `GET /health`
- **Agents:** `GET /agents`, `GET /agents/{id}`, `POST /agents/{id}/start`, `POST /agents/{id}/stop`, `GET /agents/{id}/stream`
- **HITL:** `GET /hitl/queue`, `GET /hitl/{id}`, `POST /hitl/approve|reject/{id}`, `POST /hitl/submit`
- **Costs:** `GET /costs/today`, `GET /costs/status`, `POST /costs/record`
- **Panic:** `GET /panic`, `POST /panic`
- **Tasks:** `POST /tasks/submit`, `GET /tasks/queue/{agent_id}`
- **Events:** `GET /events/replay`, `POST /events/ingest`

Auth is Bearer token after login; internal/agent traffic can bypass (e.g. Caddy routing).

### Strengths

- Contract matches Pegasus Kotlin client; used in real VPS deploys.
- Config via env: `PEGASUS_ADMIN_USERNAME`, `PEGASUS_ADMIN_PASSWORD`, caps, panic threshold, trail retention, etc.
- Optional Caddy + domain for HTTPS (`CERBERUS_ENABLE_CADDY=1`, `CERBERUS_DOMAIN`).

### Gaps / Actions

- **Default credentials:** Default `yani` / `cerberus2026`. **Must change in production** (env override or change-password after first login).
- **operator UI (Spec 006):** Event multiplexer, normalized stream (`/events/ws`), steer API, and trail persistence are **not yet implemented** in pegasus-compat. Current API supports existing Pegasus “simple” flows only.

**Verdict:** **Production-ready for current Pegasus feature set** provided default credentials are changed and API is behind HTTPS (e.g. Caddy).

---

## 3. Pegasus (Android App)

### Role

Kotlin/Jetpack Compose (Material 3) app for phone/fold — dashboard, HITL queue, costs, panic, SSH terminal, settings. Targets Cerberus via pegasus-compat API.

### Strengths

- Clear auth flow (login → Bearer token → DataStore persistence).
- Feature set matches current API: dashboard, HITL, costs, panic, terminal, API URL/SSH settings.
- Documented default API URL and credentials with “change password after first login.”

### Caveats

- **Explicitly Alpha** in README (“Features (Alpha)”).
- **operator UI (Spec 006):** Multi-pane real-time view, live trail timeline, steer controls, replay — **proposed only**. App does not depend on them yet; they require backend additions (event multiplexer, steer API, etc.).

**Verdict:** **Alpha but usable** for current “simple” operator flows (dashboard, HITL, costs, terminal). operator UI is a future phase.

---

## 4. Checklist for Production Use

### Cerberus

- [ ] Build with Zig **0.15.2** and `-Doptimize=ReleaseSmall`.
- [ ] Run `zig build test --summary all` before deploy.
- [ ] Use VPS deploy script and systemd; verify `curl http://127.0.0.1:3000/health` (or configured port).
- [ ] If using Claude Pro: run `claude auth login` on the VPS and validate.
- [ ] Restrict gateway bind or use tunnel; do not set `allow_public_bind` without need.
- [ ] Set API keys and secrets via env or encrypted config; never commit.

### pegasus-compat API

- [ ] Set `PEGASUS_ADMIN_USERNAME` and `PEGASUS_ADMIN_PASSWORD` (or change password after first login).
- [ ] Put API behind HTTPS (e.g. `CERBERUS_ENABLE_CADDY=1`, `CERBERUS_DOMAIN=ops.meziani.org`).
- [ ] Configure spend caps and panic threshold (`DAILY_SPEND_CAP_USD`, `PANIC_THRESHOLD_USD`, etc.).

### Pegasus app

- [ ] Point to production API URL (e.g. `https://pegasus.meziani.org`).
- [ ] Ensure SSH host/port/user are correct for production VPS.
- [ ] Treat as Alpha: monitor for regressions and plan for operator UI when backend supports it.

---

## 5. Roadmap (from specs)

- **Spec 005 (Meziani–Dragun roster):** In progress; VPS path and roster defined.
- **Spec 006 (Pegasus operator UI):** Proposed. Phase 1 (read-only real-time events), Phase 2 (steer API + Pane D), Phase 3 (replay/forensics) will increase production capability for power users but are not required for current production use.

---

## 6. References

- Cerberus runtime: `cerberus/README.md`, `cerberus/runtime/cerberus-core/README.md`, `cerberus/runtime/cerberus-core/SECURITY.md`
- Deployment: `cerberus/deploy/meziani-dragun/`, `cerberus/README.md` (Meziani + Dragun Roster Deploy)
- Specs: `cerberus/specs/005-meziani-dragun-roster-deploy.md`, `cerberus/specs/006-pegasus-mission-control-ux.md`
- Pegasus app: `pegasus/README.md`
- pegasus-compat: `cerberus/deploy/pegasus-compat/app.py`
