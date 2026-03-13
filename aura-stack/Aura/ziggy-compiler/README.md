# Ziggy compiler (our own)

Compiler for **Ziggy** — our language branching from Zig 0.15.2. Implemented in our repo; ultra fast, efficient, transparent to the developer, with real-time logs and **alarming** for security, major performance, and syntax/architecture errors.

**Full spec:** [docs/ziggy-compiler.md](../docs/ziggy-compiler.md)

## Requirements (from spec)

- **Ultra fast, efficient** — streaming/incremental where possible; sub-second feedback target.
- **Transparent** — no black box; explain phases, timings, decisions.
- **Real-time logs** — stream progress and issues as the compiler runs; no wait-then-dump.
- **Alarms** — high-visibility alerts for security, performance, syntax, architecture.
- **Linting** — integrated lint pass; same stream and alarms; lint-only mode (`ziggy lint`); configurable rules; lint report emitted as artifact.
- **Distribution of artifacts** — single output root (`out/` or `dist/`): `bin/`, `lib/`, `lint/`, `reports/`; machine-parseable lint report; optional manifest and checksums for CI/IDE.

## Status

Compiler implementation: **TBD**. Spec (including linting and artifact distribution) in `docs/ziggy-compiler.md`. Zig version baseline: 0.15.2 (see `docs/ZIG_VERSION.md`).

## Repo layout (planned)

```
ziggy-compiler/
  README.md           # this file
  build.zig           # when compiler is implemented (Zig 0.15.2)
  src/
    main.zig          # CLI, real-time log stream, artifact layout
    lex.zig
    parse.zig
    typecheck.zig
    codegen.zig
    alarms.zig        # security / performance / syntax / architecture
    lint.zig          # lint rules, lint-only mode, report emission
    artifacts.zig     # output layout, manifest, distribution
```

We take from the spec and branch out to the Ziggy compiler here.
