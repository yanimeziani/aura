# Language unification — minimal, careful set

**Goal:** One primary application language + one ops language. Zig only where it clearly pays.

---

## Current state

| Where | TS | JS | Zig | Shell |
|-------|----|----|-----|-------|
| **pi-mono** | 244 | 52 | 4 (mams-script) | 9 |
| **scratch (AURA)** | 9 | 15 | 8 | 7 |

- **pi-mono:** TypeScript-first (ai, agent, coding-agent, mom, web-ui, tui, pods, mams). One Zig package: **mams-script** (M-Script LSP + compiler).
- **scratch:** Mixed JS/TS (upwork-scraper, quick-cash-backend, sniper-node, etc.), Zig (sniper-node-zig, sovereign-probe), Bash (night_ops, start, cleanup).

---

## Recommended set (3 → 2.5)

| Language | Role | Keep / reduce |
|----------|------|----------------|
| **TypeScript (Node)** | All app code: APIs, agents, automation, tools, MAMS, Eye, Sniper logic | **Primary.** Unify all JS → TS. |
| **Bash** | Ops only: night_ops, start.sh, cleanup, cron | **Keep.** Don’t grow; don’t rewrite in TS. |
| **Zig** | Only mams-script (LSP + compiler). Optional: one “native” node if you need single-binary/speed. | **Shrink.** Scratch Zig → TS where possible. |

**Target:** **TypeScript + Bash**, with Zig only for mams-script (and optionally one sniper binary if you keep it).

---

## Why these

- **TypeScript:** One runtime (Node), one type system, one build. Fits pi-mono, agents, LLM tooling, and scratch services. Consolidating JS → TS cuts cognitive load and bugs.
- **Bash:** For launchers, cron, and cleanup you don’t need another language. Keep scripts short and obvious.
- **Zig:** Keep only where it’s clearly worth the extra language: mams-script (language tooling). For scratch, prefer one TS codebase and call it from Bash; only keep Zig there if you need a single binary or hard perf.

---

## Concrete steps (order)

1. **pi-mono:** Already TS-heavy. Convert remaining **.js** to **.ts** (or delete dead code). Enforce “no new JS” in lint/PRs.
2. **scratch:**  
   - Move **upwork-scraper** (and any other plain JS services) to **TypeScript** (same repo or a `scratch/ts-services` with one tsconfig).  
   - **sniper-node-zig:** Either (a) port to TS and call from Node like other nodes, or (b) keep as the only Zig in scratch and document “Zig = this one binary.”  
   - Leave **sovereign-probe** and other Zig experiments as TS when you touch them, or archive.
3. **Bash:** Don’t add features. Keep night_ops, start.sh, aura-garbage-cleanup as-is. New automation logic → TS; Bash only starts processes and env.
4. **Zig:** Keep **mams-script** only. No new Zig elsewhere unless you explicitly choose “one native binary” and accept the extra language.

---

## After unification

- **Application / product code:** TypeScript only (pi-mono + scratch services).
- **Ops / glue:** Bash only (start, stop, cleanup, cron).
- **Exception:** Zig only in `mams-script` (and optionally one scratch binary).  

That’s a **minimal, carefully selected** set: **2 main languages (TS + Bash)** and **1 optional (Zig)** in one place.
