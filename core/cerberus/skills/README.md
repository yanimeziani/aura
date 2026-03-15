# Aura Skills Belt (repo-local)

Aura skills are **versioned with this repo** and tailored to Aura’s constraints:

- **Safe ops by default** (no destructive/irreversible actions unless explicitly instructed)
- **Sovereign stack rules** (Zig components: Zig 0.15.2, no external Zig deps)
- **One entrypoint**: `aura` CLI
- **Docs flow**: drop docs into `vault/docs_inbox/`, sweep with `aura docs-maid`

## Use

```bash
aura skill list
aura skill show aura-safe-ops
```

## Structure

```
skills/<name>/
  SKILL.md
  scripts/          # optional
    run             # optional executable entrypoint (called by `aura skill run <name>`)
```
