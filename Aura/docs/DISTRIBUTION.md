# Distributing Aura state to the 3 machines

This doc defines how the **same Aura state** (repo, docs, bin, vault layout, config) reaches all **3 machines** on the network so you stay good on distribution.

## Principles

- **Single source of truth:** The repo (with internal remote) is the source. All 3 machines get the same state by syncing from that repo.
- **No manual copy-paste:** Use git (and optionally a small script) so distribution is repeatable and traceable.
- **Vault and secrets:** Sensitive state (vault, keys) may be synced separately or per-machine; document where the canonical vault lives and how it is deployed to each machine.

## The 3 machines

Define your 3 machines here (names, roles, and how they get state):

| Machine | Role | How it gets Aura state |
|---------|------|------------------------|
| **1**   | *(e.g. dev / primary)* | Git pull from internal remote (or push from here first). |
| **2**   | *(e.g. VPS / services)* | `aura-deploy-worker` or git pull; runs services (autopilot, ai_pay, ai_agency_web). |
| **3**   | *(e.g. second node / mesh)* | Git pull from internal remote (or rsync if no git). |

Fill in the actual hostnames or labels. Example: `laptop`, `vps.hostinger`, `pi.home`.

## Distribution flow

1. **On the machine where you make changes (e.g. dev):**
   - Commit and push to your **internal** remote (e.g. `git push internal main`).
   - Optionally run **`bin/distribute-state.sh`** (see below) to trigger or remind sync on the other machines.

2. **On each of the other 2 machines:**
   - Pull latest from internal: `cd $AURA_ROOT && git fetch internal && git reset --hard internal/main` (or `git pull internal main` if you prefer merge).
   - If that machine runs services, the **aura-deploy-worker** (when triggered via `.deploy/latest_sha`) does the same and restarts services.

3. **Vault / secrets:** If vault or keys differ per machine, document in this section how each machine gets its vault (e.g. copy from primary once, or use a secure sync). For same vault on all 3, rsync or git (if vault is in repo and safe) from the canonical source.

## Are we good?

You are **good on distribution** when:

- [ ] All 3 machines have the same **git ref** (same commit SHA) for the Aura repo (or you explicitly accept different refs per role).
- [ ] **bin/** (aura, docs-maid, forge-run.sh, aura-stub, etc.) is present and executable on each machine.
- [ ] **docs/** and **vault/** layout (docs_inbox, roster, mcp_registry, forge_checkpoint, etc.) exist and are up to date.
- [ ] On the service machine(s), **aura-deploy-worker** (or your deploy path) runs after sync so that services see the new state.
- [ ] **AURA_ROOT** (or equivalent) is set the same way on each machine so `aura` and scripts find the repo.

## Deploy worker (VPS / service machine)

**bin/aura-deploy-worker.sh** runs on the machine that hosts Aura services. It:

- Watches **.deploy/latest_sha** (written by your CI or by you after pushing).
- Fetches **internal** remote and resets the working tree to that commit.
- Restarts **aura_autopilot.service**, **ai_pay.service**, **ai_agency_web.service**.

So for that machine, distribution = push to internal, write latest SHA to `.deploy/latest_sha`, and let the worker run (or run the worker manually once).

## Optional: distribute-state script

**bin/distribute-state.sh** can:

- Push the current branch to **internal** from this machine.
- Optionally SSH to the other two machines and run `git fetch internal && git reset --hard internal/main` (if you set **AURA_MACHINES** or **AURA_DISTRIBUTE_HOSTS**).

That way one command from your dev machine can push and pull-on-others so all 3 have the new state. See the script for required env vars.

## Checklist after big changes

When you add new state (e.g. docs maid, COMMUNITY_AND_PRIVATE, new bin scripts):

1. Commit and push to **internal**.
2. On machine 2 and 3: pull (or run distribute-state.sh).
3. Confirm `aura help` and key paths (e.g. `vault/docs_inbox`, `bin/docs-maid`) exist on all 3.
4. If any machine runs services, ensure deploy worker has run or restart services so they see new code/config.

Summary: **you’re good on distribution when all 3 machines share the same Aura repo state from the internal remote and the checklist above is satisfied.**
