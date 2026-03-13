#!/usr/bin/env bash
# rotate-secrets.sh — Guided secret rotation helper (VPS-side)
# Called after Yani approves a secrets rotation HITL request.
# Never logs secret values. Idempotent.
# Usage: bash rotate-secrets.sh [--secret anthropic|github|webhook|all]

set -euo pipefail

OPENCLAW_DIR="${OPENCLAW_DIR:-/data/openclaw}"
ENV_FILE="$OPENCLAW_DIR/docker/.env"
LOG_FILE="$OPENCLAW_DIR/logs/secrets-rotation.log"

info() { printf '\033[0;34m[rotate]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[rotate]\033[0m %s\n' "$*"; }
warn() { printf '\033[0;33m[rotate]\033[0m %s\n' "$*"; }
err()  { printf '\033[0;31m[rotate]\033[0m %s\n' "$*" >&2; exit 1; }

audit() {
  # Log rotation event WITHOUT the secret value
  printf '{"event":"secret_rotated","key":"%s","ts":"%s","operator":"yani"}\n' \
    "$1" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$LOG_FILE"
}

[[ ! -f "$ENV_FILE" ]] && err ".env not found at $ENV_FILE"

SECRET="${1:-}"
if [[ "$SECRET" == "--secret" ]]; then SECRET="${2:-all}"; fi

rotate_anthropic() {
  warn "=== ANTHROPIC API KEY ROTATION ==="
  info "Steps:"
  info "  1. Go to console.anthropic.com → API Keys"
  info "  2. Create a new key (name it: openclaw-$(date +%Y%m)"
  info "  3. Paste the new key below (input is hidden)"
  printf "New ANTHROPIC_API_KEY: "
  read -rs NEW_KEY
  printf "\n"
  [[ -z "$NEW_KEY" ]] && err "No key entered, aborting"

  # Update .env — sed in-place, no value in logs
  sed -i "s|^ANTHROPIC_API_KEY=.*|ANTHROPIC_API_KEY=${NEW_KEY}|" "$ENV_FILE"
  ok "ANTHROPIC_API_KEY updated in .env"

  # Restart affected containers
  cd "$OPENCLAW_DIR/docker"
  docker compose restart openclaw agent-devsecops agent-growth
  ok "Containers restarted"

  # Verify (just check containers came back up, don't log key)
  sleep 5
  docker compose ps --filter "status=running" | grep -E "openclaw|agent" \
    && ok "Containers healthy" || warn "Check container status manually"

  audit "ANTHROPIC_API_KEY"
  warn "IMPORTANT: Revoke the OLD key at console.anthropic.com now."
}

rotate_github() {
  warn "=== GITHUB TOKEN ROTATION ==="
  info "Steps:"
  info "  1. Go to github.com/settings/tokens"
  info "  2. Create new token with repo + workflow scopes"
  info "  3. Paste below (input hidden)"
  printf "New GITHUB_TOKEN: "
  read -rs NEW_KEY
  printf "\n"
  [[ -z "$NEW_KEY" ]] && err "No token entered"

  sed -i "s|^GITHUB_TOKEN=.*|GITHUB_TOKEN=${NEW_KEY}|" "$ENV_FILE"
  ok "GITHUB_TOKEN updated in .env"

  # Test the new token
  if git ls-remote --quiet "https://${NEW_KEY}@github.com/yourorg/dragun-app.git" HEAD &>/dev/null; then
    ok "GitHub token verified"
  else
    warn "Token test failed — verify repo access and org name in script"
  fi

  audit "GITHUB_TOKEN"
  warn "IMPORTANT: Revoke the OLD token on GitHub."
}

rotate_webhook() {
  warn "=== ALERT WEBHOOK URL ROTATION ==="
  info "Paste new webhook URL (Telegram/Discord) — input hidden"
  printf "New ALERT_WEBHOOK_URL: "
  read -rs NEW_URL
  printf "\n"
  [[ -z "$NEW_URL" ]] && err "No URL entered"

  sed -i "s|^ALERT_WEBHOOK_URL=.*|ALERT_WEBHOOK_URL=${NEW_URL}|" "$ENV_FILE"
  ok "ALERT_WEBHOOK_URL updated"

  # Test the webhook
  curl -sf "$NEW_URL" -d "text=[openclaw] Webhook rotation test — $(date)" > /dev/null \
    && ok "Webhook test message sent" || warn "Webhook test failed — check URL"

  audit "ALERT_WEBHOOK_URL"
}

# ── dispatch ──────────────────────────────────────────────────────────────────

case "${SECRET:-all}" in
  anthropic) rotate_anthropic ;;
  github)    rotate_github    ;;
  webhook)   rotate_webhook   ;;
  all)
    rotate_anthropic
    rotate_github
    rotate_webhook
    ;;
  *)
    err "Unknown secret: $SECRET. Use: anthropic | github | webhook | all"
    ;;
esac

ok "Rotation complete. Audit log: $LOG_FILE"
info "Next: run gitleaks to confirm no lingering exposure:"
info "  docker run --rm -v /data/dragun/repos/dragun-app:/repo zricethezav/gitleaks detect --source /repo"
