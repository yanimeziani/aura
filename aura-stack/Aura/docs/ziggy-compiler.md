# Ziggy compiler — our own compiler

Our own compiler for **Ziggy** (language branching from Zig 0.15.2). Goals: **ultra fast**, **efficient**, **transparent to the developer**, with **real-time logs** and **alarming** when security issues, major performance problems, or syntax/architecture errors occur.

## Principles

1. **Ultra fast and efficient** — Compilation is streaming and incremental where possible; low memory and CPU footprint; no unnecessary passes. Target: sub-second feedback for typical single-file or small-project edits.
2. **Transparent to dev** — No black box. The compiler explains what it is doing (phases, decisions, where time is spent). Output is human-readable and machine-parseable for tooling.
3. **Real-time logs** — Logs stream as the compiler runs, not only at the end. Developer sees progress (parsing, typecheck, codegen, link) and issues as they appear. No "wait then dump."
4. **Alarming when it matters** — Certain conditions are treated as **alarms** (high visibility, possible interrupt or CI failure):
   - **Security:** Unsafe patterns, potential data leaks, dangerous crypto use, unchecked external input, hardcoded secrets.
   - **Major performance:** Accidental quadratic (or worse) complexity, unnecessary allocations in hot paths, blocking in async context, large copies.
   - **Syntax / architecture:** Parse errors, type errors, visibility/export violations, layering or architectural rule breaches (e.g. network code depending on UI).

## Real-time log stream

- **Format:** Structured lines (e.g. JSON or a simple key=value line protocol) so editors and scripts can consume them.
- **Levels:** `progress` (phase/task), `info`, `warn`, `alarm`, `error`.
- **Alarms:** Emit `alarm` with category (`security` | `performance` | `syntax` | `architecture`), location (file:line:col), and a short message. Optionally trigger a distinct sound or UI state in the IDE.
- **Progress:** Emit at phase start/end (e.g. `lex`, `parse`, `typecheck`, `codegen`, `link`) so the dev sees where time is spent.

## Alarm categories (what we alarm on)

| Category       | Examples |
|----------------|----------|
| **security**   | Use of `@ptrCast` without audit hint; `extern` without allowlist; string that looks like secret in source; crypto API misuse; buffer used before init. |
| **performance**| Loop with O(n²) or worse pattern; alloc in loop with no reuse; large by-value copy of struct; sync I/O in async path. |
| **syntax**     | Parse error; invalid escape; missing required attribute. |
| **architecture**| Module A imports module B in violation of layering; forbidden dependency (e.g. UI → network); public API change without explicit opt-in. |

## Transparency

- **Phase timing:** Log duration per phase (lex, parse, typecheck, codegen, link). Option: `--report time` summary at the end.
- **Why this code path:** For alarms and key errors, include a one-line "why we're flagging this" (e.g. "loop body allocates; consider moving alloc outside loop").
- **Docs:** Compiler flags and log format documented; no hidden behaviour. Our repo, our compiler, our rules.

## Linting

- **Integrated with compiler** — Lint rules run in the same pipeline (or as a dedicated pass). Same real-time log stream and **alarm** level for lint violations that are security/performance/architecture-critical; style/naming as `warn` unless configured stricter.
- **Lint-only mode** — `ziggy lint` (or `ziggy build --lint-only`) runs lex/parse/typecheck + lint only; no codegen. Fast feedback for style and policy without producing binaries.
- **Rules (examples):** Naming (e.g. `snake_case` for vars, `PascalCase` for types); no unused locals; explicit error handling in public APIs; no `_ = x` without comment; dependency layering; alarm-level rules match the alarm categories (security, performance, syntax, architecture).
- **Config:** Repo-level or project-level config (e.g. `ziggy.lint.toml` or section in existing config) to enable/disable rules and set severity. Default: alarms for security/performance/architecture; warns for style.
- **Output as artifact** — Lint results are emitted on the real-time stream and can be written to a **lint report artifact** (see Distribution of artifacts).

### Lint report artifact format

One line per finding. Machine-parseable: **JSON Lines** (one JSON object per line) or **key=value** line protocol. Required fields per finding:

| Field      | Description |
|------------|-------------|
| `file`     | Source file path (relative or absolute). |
| `line`     | 1-based line number. |
| `col`      | 1-based column (optional; 0 if unknown). |
| `severity` | `error`, `warn`, `alarm`, or policy-specific. |
| `rule_id`  | Lint rule identifier (e.g. `unused_local`, `naming`). |
| `message`  | Human-readable description. |

Example (JSON Lines): `{"file":"src/main.zig","line":10,"col":2,"severity":"warn","rule_id":"naming","message":"use snake_case"}`. Written to `out/lint/report.jsonl` (or configurable path).

## Distribution of artifacts

- **What we produce:** Binaries (executables, static libs), lint reports, and optionally diagnostics bundles (e.g. for CI/IDE). All are **artifacts** with a clear layout and format.
- **Layout:** Single output root (e.g. `out/` or `dist/`) with predictable structure:
  - `out/bin/` — executables.
  - `out/lib/` — static libraries or other linkable artifacts.
  - `out/lint/` — lint reports (e.g. one per package or one per run).
  - `out/reports/` — optional timing/diagnostics (e.g. `--report time` output, alarm summary).
- **Formats:** Binaries are native (e.g. ELF/Mach-O); lint report is machine-parseable (JSON or same line protocol as real-time logs) so CI and editors can consume it. Optional manifest (e.g. `artifacts.json`) listing paths, checksums, and metadata.
- **Consumption:** CI uploads or publishes from the output root; IDE/editor reads lint report and real-time stream. No hidden locations; paths are documented and configurable (e.g. `--out-dir`, `--lint-report`).
- **Optional:** Checksums or signing for distribution integrity; version and build-id in artifact metadata.

## Implementation notes (from here we build)

- **Input:** Ziggy source (Zig 0.15.2–compatible subset to start; extend with Ziggy-specific syntax/semantics).
- **Output:** Native code (or IR), real-time log stream (stderr / socket / IDE protocol), **lint report artifact**, and **distributed artifacts** under a single output root.
- **Location:** Compiler implementation lives in our repo (e.g. `ziggy-compiler/`). Bootstrap: can be implemented in Zig 0.15.2; later consider self-hosted Ziggy.

This doc is the spec. We take from here and build the compiler; real-time logs, alarming, **linting**, and **distribution of artifacts** are first-class requirements.
