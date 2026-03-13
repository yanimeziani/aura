# Chairman — daily ops

*Your stack. Your interface. One place.*

---

## Morning (or whenever you take the chair)

1. **Launch**  
   `./start.sh` (or Night Ops if you want full ritual). Machine online. Dashboard at http://localhost:8181.

2. **Check state**  
   Browser: open dashboard.  
   Terminal: `node aura-cli.js state` — revenue, deals, no browser.

3. **Command**  
   In dashboard: `/` or `Ctrl+K` → command bar. Type `scan`, `sniper`, `revenue`, `audit`, `hud`.  
   Or: `1` scan, `2` sniper, `3` soc, `4` publish, `5` revenue.  
   From shell: `node aura-cli.js run eye` (or sniper, soc, publisher, mco).

4. **Prompts & skills**  
   `~/prompt-library.md` — system prompts (operator, agent, proposals, ops). User templates. Skills table. Permutation matrix. Use in Cursor, Antigravity, Ollama.

---

## Through the day

- **Sync**  
  Night Ops does git push on start and on shutdown. To sync anytime: from scratch, `git add -A && git commit -m "[chairman] sync" --no-verify && git push`.

- **Cleanup**  
  `./cleanup.sh` (or `aura-garbage-cleanup.sh`). Add `--dry-run` to preview. Optional weekly cron.

- **Interface**  
  You’re not stuck with one UI. Dashboard for visuals; CLI for speed; prompts for AI. Same backend, same state.

---

## Evening / handoff

- Shut down nodes (Ctrl+C in the terminal running start.sh), or leave the machine on.  
- Night Ops shutdown syncs to GitHub.  
- Tomorrow: same ops. You’re chairman; the stack runs for you.

---

*One line:* Launch → state (browser or CLI) → command (bar or CLI) → prompts when you need the model. Sync and cleanup when you choose. You’re in the chair.
