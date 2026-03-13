#!/usr/bin/env zsh
# Aura shell integration (zsh):
# - Removes the dangerous `alias aura='cd ...'` footgun
# - Provides `aura cd` to cd in-place (current shell)
# - Adds simple completion for common subcommands

setopt no_aliases 2>/dev/null || true

unalias aura 2>/dev/null || true

_AURA_ZSH_ROOT="${AURA_ROOT:-${0:A:h:h}}"
_AURA_ZSH_BIN="$_AURA_ZSH_ROOT/bin/aura"

aura() {
  if [[ "${1:-}" == "cd" ]]; then
    builtin cd "$_AURA_ZSH_ROOT"
    return $?
  fi
  command "$_AURA_ZSH_BIN" "$@"
}

_aura_complete() {
  local -a cmds
  cmds=(
    "status:System status"
    "start:Start services"
    "stop:Stop services"
    "vault:Vault manager"
    "logs:Tail logs"
    "tui:Launch TUI"
    "mesh:Mesh VPN (up/down/status)"
    "lynx:Text browser"
    "opensea:Internet (status/open)"
    "skill:Skills belt (list/show/run)"
    "api:Run aura-api"
    "gateway:Run gateway"
    "docs-maid:Run docs maid"
    "stub:Persistent stub"
    "stub-duplicate:Stub duplication"
    "cd:cd to Aura repo root"
    "help:Help"
  )

  if (( CURRENT == 2 )); then
    _describe -t aura-cmds "aura command" cmds
    return
  fi

  if [[ "$words[2]" == "mesh" ]]; then
    _values "mesh command" up down status help
    return
  fi

  if [[ "$words[2]" == "skill" ]]; then
    _values "skill command" list show run
    return
  fi
}

if whence -w compdef >/dev/null 2>&1; then
  compdef _aura_complete aura
fi
