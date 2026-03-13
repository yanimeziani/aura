# Zig version lock and Ziggy

## Locked version: **0.15.2**

Aura uses **exactly one** Zig version across the repo:

- **Version:** `0.15.2`
- **Source of truth:** This file and `.zig-version` at repo root.
- **Packages:** Every Zig package in this repo sets `minimum_zig_version = "0.15.2"` in its `build.zig.zon` (aura-edge, aura-tailscale, aura-mcp, tui).

Use `zig 0.15.2` (or a compatible 0.15.x build) for all builds and tooling. Do not upgrade Zig version without updating this doc, `.zig-version`, and all `build.zig.zon` in lockstep.

## Documentation localised to 0.15.2

All Zig-related documentation in this repo is written for **Zig 0.15.2**:

- **API and std:** Descriptions of `std.*` (e.g. `std.crypto`, `std.json`, `std.fs`) refer to the behaviour and types in Zig 0.15.2.
- **Build:** `zig build`, `zig build run`, `zig build test` and any build options are for the 0.15.2 build system.
- **Language:** Syntax and semantics (e.g. `std.json.Value`, `parseFromSlice`, `.object.get`) are as in 0.15.2.

When adding or editing Zig docs, assume 0.15.2 and mention this file if the version is relevant.

## Branch out to Ziggy

From this locked baseline (**Zig 0.15.2**) we branch out to the **Ziggy** language:

- Zig 0.15.2 is the **reference implementation** and the version we lock to for Aura’s Zig code and docs.
- **Ziggy** is our evolution from that baseline (dialect, fork, or derived language). Design and experimentation for Ziggy start from 0.15.2 semantics and APIs documented here.
- **Our own compiler for Ziggy:** Ultra fast, efficient, transparent to the dev, with **real-time logs** and **alarming** for security issues, major performance problems, and syntax/architecture errors. Spec: [docs/ziggy-compiler.md](ziggy-compiler.md). Implementation: `ziggy-compiler/`.
- New Zig code in Aura targets 0.15.2 unless explicitly noted as Ziggy or experimental. Ziggy-specific docs and tooling will reference Ziggy separately while keeping 0.15.2 as the documented baseline.

**Summary:** One Zig version (0.15.2), all docs localised to it; we take from there and branch out to Ziggy and our own Ziggy compiler.
