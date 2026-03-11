# Next Steps — Aura Project
**Updated:** 2026-03-11

---

## Immediate (Today)

### 1. Restart the Trader
- Last cycle: 252 at `2026-03-10T14:52` — offline since yesterday afternoon
- F&G at 13 (Extreme Fear) → potential mean-reversion opportunity
- Check env vars are set, then:
  ```bash
  cd ai_agency_wealth && python algo_trader.py
  # or paper mode:
  python algo_trader.py --live false
  ```

### 2. Set AURA_VAULT_TOKEN
- Added to vault registry but not yet provisioned
- Run vault manager to generate and store:
  ```bash
  python vault/vault_manager.py
  ```
- Confirm it's exported in `.env` and accessible to `prod_payment_server.py`

### 3. Verify Payment Server on Port 8765
- Caddyfile now proxies `/api/*` → `host.docker.internal:8765`
- Previous port was 8000 — confirm `prod_payment_server.py` is bound to 8765:
  ```bash
  ss -tulpn | grep 8765
  # or check uvicorn startup args in prod_payment_server.py / service file
  ```

---

## This Week

### 4. Newsletter Distribution (Issue 001 Ready)
- `latest_newsletter.md` is polished and production-ready
- Send via `global_newsletter_dept.py` or n8n automation
- Hook up subscribe endpoint (`subscribe@thesovereignpulse.com` needs a real mailbox or redirect)

### 5. Trader Signal Tuning
- 230+ cycles with zero trades suggests thresholds are too conservative under current regime
- F&G at extreme fear = potential entry regime — check composite score floor
- Review `quant_signals.py` sentiment weight (20%) — F&G=13 should be pushing buy signal
- Consider lowering composite entry threshold temporarily for ranging/fear market

### 6. meziani.ai Static Deploy
- Caddyfile now routes meziani.ai to `/srv/landing_page` only (no backend proxies)
- Build and deploy `aura-landing-next`:
  ```bash
  cd aura-landing-next && npm run build
  # deploy /out to /srv/landing_page on VPS
  ```

### 7. `/sys/network` Endpoint Security Audit
- New endpoint in `prod_payment_server.py` runs `ss -tulpn` via subprocess
- Confirm Tailscale mesh IP guard is actually blocking public access before exposing
- Consider rate-limiting or restricting to `VAULT_TOKEN` only (not just private IP)

---

## Upcoming / Backlog

### Zig Network Stack
- **Phase 2:** TLS termination in `aura-edge` (cert.zig, sni.zig need wiring into main)
- **Phase 2.5:** Complete WireGuard handshake in `aura-tailscale` (loop.zig daemon is stub)
- **Phase 3:** XDP/eBPF rate limiting layer

### Ziggy Compiler
- `main.zig` only runs lex + parse — wire in sema, lint, alarms, artifacts
- Log streaming + real-time alarm output (modules exist, not connected)

### Vault
- `aura-vault.json` chrome backup pipeline — ensure backup rotation works
- `vault_manager.py` — add OWNER_EMAIL to active use (notifications, auth fallback)

### Dragun.app
- Debtor portal `/pay/:id` — Stripe checkout integration
- RAG pipeline with Groq — pgvector schema migrations needed
- Merchant dashboard `/dashboard` — recovery queue KPIs

---

## Metrics to Watch

| Metric | Current | Target |
|--------|---------|--------|
| Trader cycles/day | ~60 | 60+ (continuous) |
| Open positions | 0 | 1-3 |
| Daily PnL | $0 | >0 (paper first) |
| F&G index | ~13-50 | — (context signal) |
| Watchdog status | HEALTHY | HEALTHY |
| Payment server port | 8765 | confirmed live |
