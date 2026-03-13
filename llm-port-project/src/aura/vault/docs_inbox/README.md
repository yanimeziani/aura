# Docs inbox — one place for all docs

**All docs go here first.** The **docs maid** (persistent process) sweeps this folder and files documents to their final locations.

## Layout

| Path in inbox | Swept to |
|---------------|----------|
| `docs/*`      | → `docs/` (repo root) |
| `channel/*`   | → content **appended** to `vault/roster/CHANNEL.md`, then file removed |
| `vault/*`     | → `vault/` (repo root) |
| `*.md` (here) | → `docs/` (root-level `.md` in inbox go to `docs/`) |

## Workflow

1. **Agents or you** write/copy docs into `vault/docs_inbox/` (or into `docs/`, `channel/`, `vault/` subdirs).
2. **Docs maid** runs continuously (e.g. `aura docs-maid` or `aura stub -- bin/docs-maid run`). Every sweep interval it:
   - Moves `docs_inbox/docs/*` → `docs/`
   - Appends `docs_inbox/channel/*` to `vault/roster/CHANNEL.md` and deletes the source file
   - Moves `docs_inbox/vault/*` → `vault/`
   - Moves root-level `*.md` in inbox → `docs/`
3. Inbox stays clean; canonical docs stay in one place.

## Start the maid

```bash
aura docs-maid          # persistent (run loop)
aura docs-maid sweep    # one-shot sweep
```

Run the maid in the background or under `aura stub` so it keeps sweeping while you code with agents.
