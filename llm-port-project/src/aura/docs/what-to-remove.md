# What to remove

*Safe-to-remove list. Order = by impact (space/friction) and risk.*

---

## 1. Remove now (saves space, zero impact on running stack)

| Item | Where | Size / reason |
|------|--------|----------------|
| **Aura-Archive-Legacy.zip** | `scratch/` | ~81 MB. One-off legacy zip; not used by start or night_ops. |
| **_ARCHIVE/** | `scratch/_ARCHIVE` | ~402 MB. Old projects (x-lead-gen, authless-node, etc.). Already archived; not in start/night_ops path. |

**Command (from scratch):**
```bash
rm -f Aura-Archive-Legacy.zip
rm -rf _ARCHIVE
```
**Saves:** ~483 MB.

---

## 2. Remove if you don’t use them (optional scripts)

| Item | Where | Reason |
|------|--------|--------|
| **night_ops_final.sh** | scratch | Variant of night_ops (thermal/power). Keep only if you run it. |
| **night_ops_glacial.sh** | scratch | Same. |
| **night_ops_ram.sh** | scratch | Same. |
| **night_ops_thermal.sh** | scratch | Same. |
| **emergency-deploy.ts** | scratch | Calls /approve with test payloads. Remove if you never run it. |

If you only ever run **night_ops.sh**, you can delete the four `night_ops_*.sh` variants and `emergency-deploy.ts`.

---

## 3. Remove only if you’re sure (small / experimental)

| Item | Where | Reason |
|------|--------|--------|
| **ghost-protocol/** | scratch | Small dir; not referenced in start.sh or night_ops.sh. Likely experiment. |
| **sovereign-probe-zig/** | scratch | Zig probe; not in start.sh. Optional. |
| **aura-core-zig/** | scratch | Tiny (e.g. stub); not in start. Optional. |

Check inside each; if you don’t need them, remove. If in doubt, leave or move to `_ARCHIVE` first.

---

## 4. Do not remove

- **start.sh**, **night_ops.sh**, **aura-garbage-cleanup.sh** — launchers and cleanup.
- **quick-cash-backend**, **war-machine-ui**, **upwork-scraper**, **sniper-node**, **sniper-node-zig**, **soc-cert-node**, **attention-sucker**, **agent-hub**, **va-coder** — live nodes or UI.
- **.env**, **.env.example**, **.gitignore** — config.
- **build-release.sh**, **e2e.sh**, **aura-cli.js**, **prompt-library.md**, **BUILD_SPEC.md**, **README.md**, **DOCTRINE.md**, etc. — build, ops, docs.

---

## Summary

- **Remove first:** `Aura-Archive-Legacy.zip` + `_ARCHIVE/` → ~483 MB, no impact on current run.
- **Then (optional):** extra night_ops variants + `emergency-deploy.ts` if you don’t use them.
- **Last (only if sure):** ghost-protocol, sovereign-probe-zig, aura-core-zig.
