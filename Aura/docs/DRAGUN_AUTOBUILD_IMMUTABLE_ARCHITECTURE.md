# Aura -> Dragun.app: Immutable Autobuild Architecture

**Purpose:** lock the architecture for Aura to build, verify, and operate `dragun-app` by itself, with local voice as an operator ingress and not as the core execution surface.

**Mission boundary:** Aura is the sovereign control plane. `dragun-app` is a managed workload. `opencode` is an operator workstation surface. Voice is an optional local-first command ingress. None of those roles are interchangeable.

---

## 1. Canonical inputs we are designing around

### Aura control-plane surfaces

- `bin/aura` is the single local operator CLI.
- `gateway/README.md` defines the syncing gateway as the shared entry point for IDEs, TUIs, and LLM clients.
- `docs/ONBOARDING.md` is the one-place onboarding entry.
- `vault/` is the secrets and durable operator-state boundary.

### Dragun workload surfaces

- `dragun-app/package.json` defines the executable build gates: `lint`, `i18n:check`, `test:unit`, `test:e2e`, `build`, `db:check`.
- `dragun-app/README.md` defines the product stack and deployment target.
- `dragun-app/PROD_READINESS_REPORT.md` and `dragun-app/docs/PRODUCTION-BLOCKERS-DEMO.md` define the real production blockers and env contract.

### Local operator surfaces

- `opencode` is installed locally and resolves config from user and project config locations.
- The installed `opencode` build is operational, but upstream is archived; therefore it is treated as a client surface, not a strategic platform dependency.
- Local machine facts today: Fedora Linux on Wayland, `ffmpeg`, `arecord`, and `wl-copy` are available; direct Wayland text injection tools are not present.

---

## 2. North star

Aura must be able to take `dragun-app` from intent to verified state with the fewest possible moving parts:

1. Accept operator intent by text or local voice.
2. Convert intent into a tracked build objective.
3. Execute the build pipeline against `dragun-app`.
4. Prove the result with machine-readable evidence.
5. Store that evidence in Aura-owned state.
6. Repeat the cycle without depending on cloud-only orchestration.

This means the architecture cannot be "voice inside opencode" or "automation inside dragun". Those shapes are too narrow and do not generalize to the rest of Aura.

---

## 3. Cross-match: where each responsibility belongs

| Responsibility | `opencode` plugin/client | `dragun-app` app layer | Aura control plane | Decision |
|---|---|---|---|---|
| Operator text chat | Good | No | Good | Aura + client surface |
| Local voice capture | Weak as core dependency | No | Strong | Aura owns |
| Build orchestration | Weak | Wrong layer | Strong | Aura owns |
| Secret resolution | Weak | Partial | Strong | Aura owns |
| Cross-project reuse | Weak | None | Strong | Aura owns |
| Evidence storage | Weak | Wrong layer | Strong | Aura owns |
| Deploy verification | Weak | Partial | Strong | Aura owns |
| Sovereign/local-first posture | Medium | Medium | Strong | Aura owns |

**Result:** voice, planning, build execution, verification, and evidence retention all belong in Aura. `opencode` remains a workstation front-end that talks to Aura-owned primitives.

---

## 4. Cross-match: candidate voice architectures

| Option | Local-first | Wayland-safe | Reusable across Aura | Good for `dragun-app` autobuild | Decision |
|---|---|---|---|---|---|
| Native `opencode` voice integration | Unclear | Unclear | Weak | Weak | Reject |
| Desktop dictation app as the whole solution | Medium | Medium | Weak | Weak | Reject as core |
| Voice embedded into `dragun-app` | Wrong layer | N/A | None | Wrong scope | Reject |
| Aura-owned local STT service with clipboard/transcript output | Strong | Strong | Strong | Strong | Choose |

**Chosen shape:** an Aura-owned local STT service, backed by Whisper-class models, feeding Aura commands and transcript queues. If `opencode` is in the loop, it consumes Aura output rather than owning the voice stack.

---

## 5. Immutable decisions

These are fixed unless the project owner explicitly changes the architecture.

1. **Aura is the only control plane.** No autonomous build logic lives primarily inside `dragun-app`.
2. **`dragun-app` stays a workload.** It exposes build, test, deploy, and runtime surfaces; Aura owns orchestration.
3. **Voice is an ingress, not the orchestrator.** The system must work fully by text with voice layered on top.
4. **Speech-to-text stays local-first.** Preferred stack is local Whisper-family inference, not a cloud speech API.
5. **Wayland constraints are first-class.** Primary output is transcript queue plus clipboard handoff; synthetic keystroke injection is optional, never required.
6. **All secrets resolve from Aura-owned secret stores.** No secret sprawl across ad hoc shell history or editor-local config.
7. **Every autonomous action emits evidence.** Plans, command logs, gate results, deploy results, and health checks are persisted under Aura-owned state.
8. **`opencode` is replaceable.** Useful client, non-canonical backend. Aura cannot depend on `opencode` internals for core operation.
9. **Build gates are machine-enforced.** `dragun-app` is not "done" because text said so; it is done when gates pass.
10. **Docs become the contract.** This document is the architecture baseline for implementation.

---

## 6. Final architecture

```text
Operator
  -> text CLI / chat / local voice

Aura Ingress Layer
  -> aura CLI
  -> aura gateway
  -> local voice service
  -> transcript queue / clipboard bridge

Aura Orchestration Layer
  -> planner
  -> executor
  -> verifier
  -> docs maid
  -> state/evidence writer

Aura Control Data
  -> vault secrets
  -> .aura runtime state
  -> build manifests
  -> deploy records

Managed Workload Adapters
  -> dragun-app repo and npm scripts
  -> Supabase
  -> Stripe
  -> Vercel
  -> Sentry

Verification Outputs
  -> lint/test/build results
  -> env validation report
  -> preview/prod deploy result
  -> health and smoke checks
```

### Layer roles

- **Ingress layer:** receives operator intent and normalizes it into Aura actions.
- **Orchestration layer:** decides, executes, retries, and verifies.
- **Control data layer:** stores secrets, manifests, transcripts, and evidence.
- **Managed workload adapters:** translate generic Aura actions into `dragun-app`-specific operations.

---

## 7. Build contract for `dragun-app`

Aura owns this contract and must execute it in order.

### Inputs

- Repo root: `dragun-app/`
- Secrets from Aura-owned vault or environment bridge
- Deployment target metadata
- Requested mode: local dev, preview, production, or maintenance

### Mandatory gates

1. Install dependencies in a reproducible way.
2. Validate required environment variables against the app contract.
3. Run `npm run lint`.
4. Run `npm run test:unit`.
5. Run `npm run i18n:check`.
6. Run `npm run build`.
7. Run `npm run test:e2e` or a declared smoke subset when full E2E is intentionally deferred.
8. Run `npm run db:check` when DB credentials are available and the target mode requires it.
9. Run deployment adapter steps for preview or production.
10. Run post-deploy health checks.

### Required evidence

- Timestamped command manifest
- Exit code for every gate
- Captured stderr/stdout summary
- Effective env validation result
- Deploy target identifier
- Post-deploy URL and health status
- Final go/no-go decision

If any mandatory gate fails, Aura must stop the autobuild flow and record the failure as state, not bury it in chat text.

---

## 8. Why voice matters in this architecture

Voice is useful for fast operator intent capture, not for replacing deterministic automation.

### Voice responsibilities

- Capture local speech to text.
- Normalize spoken commands into Aura build intents.
- Store transcript snippets as evidence when they start a run.
- Hand off the normalized command to Aura CLI or Aura gateway.

### Voice non-responsibilities

- It does not decide whether `dragun-app` passed build gates.
- It does not own secrets.
- It does not talk directly to deployment vendors without Aura mediation.
- It does not become a second orchestration plane.

---

## 9. Recommended implementation path

### Phase 1: centralize control

- Extend `bin/aura` with a dedicated Dragun command family such as `aura dragun plan`, `aura dragun build`, `aura dragun verify`, `aura dragun deploy`.
- Standardize Aura-owned build state under `.aura/dragun/`.
- Write a build manifest format that records requested mode, gates, and results.

### Phase 2: local sovereign voice

- Add an Aura-local speech service, preferably Python-based, using local Whisper-family inference.
- Use a transcript queue and clipboard bridge as the default Wayland-safe output.
- Add `aura voice listen` and `aura voice transcribe` commands as the stable interface.

### Phase 3: workload adapter

- Add Dragun-specific env validation, gate execution, and post-deploy smoke checks.
- Make the adapter read `dragun-app/package.json` scripts and `dragun-app` operational docs as canonical inputs.

### Phase 4: autonomous loop

- Let Aura accept a single intent such as "build dragun for preview" and carry the run through plan, execute, verify, and archive.
- Persist the full run under Aura evidence paths so the same run can be inspected from CLI, chat, or future dashboards.

---

## 10. Source-to-decision map

| Source | What it contributed | Resulting architectural decision |
|---|---|---|
| `bin/aura` | Aura already has a central CLI | Keep Aura as the only control plane |
| `gateway/README.md` | Aura already has a shared ingress for clients | Route text and future voice through Aura-owned interfaces |
| `dragun-app/package.json` | Build/test gates already exist | Aura executes existing gates instead of inventing new ones |
| `dragun-app/PROD_READINESS_REPORT.md` | Production work is env- and evidence-heavy | Aura must own validation and proof, not just execution |
| Local machine facts | Wayland blocks naive text injection assumptions | Prefer transcript queue + clipboard as default voice output |
| Local `opencode` install + archived upstream status | Helpful client, unstable strategic dependency | Treat `opencode` as optional front-end only |

---

## 11. Non-goals

- Do not embed orchestration logic into `dragun-app` UI code.
- Do not make cloud STT a hard dependency.
- Do not rely on brittle keystroke automation as the only way voice works.
- Do not treat chat transcripts as sufficient release evidence.
- Do not let editor-specific workflows define Aura's system boundary.

---

## 12. Final statement

The immutable plan is:

- Aura owns intent intake, orchestration, secrets, evidence, and verification.
- `dragun-app` exposes workload gates and deployment surfaces.
- Local voice is implemented once at the Aura layer and reused everywhere.
- `opencode` remains a useful operator client, but not a foundational dependency.

That is the architecture to implement.
