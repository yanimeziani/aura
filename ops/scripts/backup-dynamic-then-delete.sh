#!/usr/bin/env bash
# Backup all dynamic runtime files (logs, json, markdown) then delete/clear them.
# For org devices and VPS: run before or during deploy so state is archived and system starts clean.
# Does NOT touch vault secrets (e.g. nexa-vault.json); only org-registry, sessions, telemetry, leads, logs, exports.
# If NEXA_BACKUP_NODES_FILE is set (or vault/backup-nodes.json exists), routes this backup to the org node
# with the largest available storage (via SSH df + rsync).
# Usage:
#   ./ops/scripts/backup-dynamic-then-delete.sh           # backup then delete
#   ./ops/scripts/backup-dynamic-then-delete.sh --backup-only   # backup only, do not delete
#   NEXA_ROOT=/opt/nexa ./ops/scripts/backup-dynamic-then-delete.sh
set -euo pipefail

resolve_realpath() {
  local target="$1"
  python3 - "$target" <<'PY'
import os
import sys
print(os.path.realpath(sys.argv[1]))
PY
}

SCRIPT_PATH="$(resolve_realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

first_existing_path() {
  local candidate
  for candidate in "$@"; do
    if [[ -e "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  printf '%s\n' "$1"
}

BACKUP_ONLY=false
for arg in "$@"; do
  case "$arg" in
    --backup-only) BACKUP_ONLY=true ;;
  esac
done

NEXA_ROOT="${NEXA_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
NEXA_BACKUP_DIR="${NEXA_BACKUP_DIR:-$(first_existing_path "$NEXA_ROOT/.nexa/backups" "$NEXA_ROOT/backups")}"
NEXA_LOG_DIR="${NEXA_LOG_DIR:-$(first_existing_path "$NEXA_ROOT/logs" "$NEXA_ROOT/.nexa/logs")}"
NEXA_DATA_DIR="${NEXA_DATA_DIR:-$(first_existing_path "$NEXA_ROOT/data" "$NEXA_ROOT/.nexa/data")}"
NEXA_VAULT_DIR="${NEXA_VAULT_DIR:-$(first_existing_path "$NEXA_ROOT/vault" "$NEXA_ROOT/vault")}"
NEXA_DOCS_INBOX_DIR="${NEXA_DOCS_INBOX_DIR:-$(first_existing_path "$NEXA_ROOT/vault/docs_inbox" "$NEXA_ROOT/vault/docs_inbox")}"

# Dynamic paths (same env names as gateway / session_store where applicable)
TELEMETRY_FILE="${NEXA_TELEMETRY_FILE:-$(first_existing_path "$NEXA_DATA_DIR/telemetry_visits.json" "$NEXA_ROOT/.nexa/data/telemetry_visits.json")}"
LEADS_FILE="${NEXA_LEADS_FILE:-$(first_existing_path "$NEXA_ROOT/apps/wealth/leads.json" "$NEXA_ROOT/ai_agency_wealth/leads.json" "$NEXA_DATA_DIR/leads.json")}"
ORG_REGISTRY_FILE="${NEXA_ORG_REGISTRY:-$(first_existing_path "$NEXA_VAULT_DIR/org-registry.json" "$NEXA_ROOT/vault/org-registry.json" "$NEXA_ROOT/vault/org-registry.json")}"
GATEWAY_SESSIONS_FILE="${NEXA_GATEWAY_SESSIONS:-}"
if [[ -z "$GATEWAY_SESSIONS_FILE" ]]; then
  GATEWAY_SESSIONS_FILE="$(first_existing_path "$NEXA_ROOT/.nexa/gateway_sessions.json" "$NEXA_DATA_DIR/gateway_sessions.json")"
fi
EXPORT_FILE="${NEXA_EXPORT_FILE:-$(first_existing_path "$NEXA_ROOT/.nexa/exports/Nexa_Full_Documentation_Export.txt" "$NEXA_ROOT/Nexa_Full_Documentation_Export.txt")}"
NEXA_BACKUP_NODES_FILE="${NEXA_BACKUP_NODES_FILE:-$(first_existing_path "$NEXA_VAULT_DIR/backup-nodes.json" "$NEXA_ROOT/vault/backup-nodes.json" "$NEXA_ROOT/vault/backup-nodes.json")}"

STAMP=$(date -u +%Y-%m-%d_%H%M%S)
BACKUP_SUBDIR="$NEXA_BACKUP_DIR/$STAMP"
mkdir -p "$BACKUP_SUBDIR"

echo "[backup-dynamic] NEXA_ROOT=$NEXA_ROOT"
echo "[backup-dynamic] Backup to $BACKUP_SUBDIR"

# --- Backup helpers ---
backup_file() {
  local src="$1"
  if [[ -e "$src" ]]; then
    local base; base=$(basename "$src")
    local dir; dir=$(dirname "$src")
    local rel="${dir#$NEXA_ROOT/}"
    [[ "$rel" == "$dir" ]] && rel="$base"
    mkdir -p "$BACKUP_SUBDIR/files/$(dirname "$rel")"
    cp -a "$src" "$BACKUP_SUBDIR/files/$rel" 2>/dev/null || cp "$src" "$BACKUP_SUBDIR/files/$rel"
    echo "  backed up: $src"
    return 0
  fi
  return 1
}

backup_dir_contents() {
  local dir="$1"
  if [[ -d "$dir" ]]; then
    while IFS= read -r f; do
      backup_file "$f" || true
    done < <(find "$dir" -type f ! -path "*/.git/*" 2>/dev/null)
    echo "  backed up dir: $dir"
    return 0
  fi
  return 1
}

delete_file() {
  local src="$1"
  if [[ -f "$src" ]]; then
    rm -f "$src"
    echo "  deleted: $src"
  fi
}

delete_or_truncate_log() {
  local src="$1"
  if [[ -f "$src" ]]; then
    : > "$src"
    echo "  truncated: $src"
  fi
}

# --- 1. Log directory: backup all *.log and any json/md, then truncate logs (so process can keep writing) or delete ---
if [[ -d "$NEXA_LOG_DIR" ]]; then
  mkdir -p "$BACKUP_SUBDIR/logs"
  shopt -s nullglob 2>/dev/null || true
  for f in "$NEXA_LOG_DIR"/*.log "$NEXA_LOG_DIR"/*.json "$NEXA_LOG_DIR"/*.md; do
    [[ -e "$f" ]] || continue
    cp -a "$f" "$BACKUP_SUBDIR/logs/" 2>/dev/null || cp "$f" "$BACKUP_SUBDIR/logs/"
    echo "  backed up: $f"
  done
  if ! "$BACKUP_ONLY"; then
    for f in "$NEXA_LOG_DIR"/*.log; do
      [[ -e "$f" ]] && { : > "$f"; echo "  truncated: $f"; }
    done
  fi
  shopt -u nullglob 2>/dev/null || true
fi

# --- 2. Single dynamic files (backup then delete) ---
for path in "$TELEMETRY_FILE" "$LEADS_FILE" "$ORG_REGISTRY_FILE" "$GATEWAY_SESSIONS_FILE" "$EXPORT_FILE"; do
  backup_file "$path" || true
  if ! "$BACKUP_ONLY" && [[ -e "$path" ]]; then
    delete_file "$path"
  fi
done

# --- 3. Runtime dirs under .nexa ---
for runtime_root in "$NEXA_ROOT/.nexa"; do
  for sub in "logs" "voice" "gateway_sessions.json"; do
    p="$runtime_root/$sub"
    if [[ -f "$p" ]]; then
      backup_file "$p" || true
      if ! "$BACKUP_ONLY"; then delete_file "$p"; fi
    fi
    if [[ -d "$p" ]]; then
      backup_dir_contents "$p" || true
      if ! "$BACKUP_ONLY"; then
        for f in "$p"/*; do [[ -e "$f" ]] && { : > "$f" 2>/dev/null || rm -f "$f"; } done
      fi
    fi
  done
done

# --- 4. Data dir: any json/md (e.g. telemetry already done; catch other dynamic files) ---
if [[ -d "$NEXA_DATA_DIR" ]]; then
  shopt -s nullglob 2>/dev/null || true
  for f in "$NEXA_DATA_DIR"/*.json "$NEXA_DATA_DIR"/*.md; do
    [[ -e "$f" ]] || continue
    backup_file "$f" || true
    if ! "$BACKUP_ONLY"; then delete_file "$f"; fi
  done
  shopt -u nullglob 2>/dev/null || true
fi

# --- 5. Vault docs_inbox: dynamic markdown/json ---
if [[ -d "$NEXA_DOCS_INBOX_DIR" ]]; then
  find "$NEXA_DOCS_INBOX_DIR" -maxdepth 6 -type f \( -name "*.json" -o -name "*.md" \) ! -path "*/.git/*" 2>/dev/null | while read -r f; do
    [[ -f "$f" ]] || continue
    backup_file "$f" || true
    if ! "$BACKUP_ONLY"; then delete_file "$f"; fi
  done
fi

# Manifest
MANIFEST="$BACKUP_SUBDIR/manifest.txt"
MANIFEST_JSON="$BACKUP_SUBDIR/manifest.json"
{
  echo "backup_dynamic $STAMP"
  echo "NEXA_ROOT=$NEXA_ROOT"
  echo "BACKUP_ONLY=$BACKUP_ONLY"
  date -u +"%Y-%m-%dT%H:%M:%SZ"
} > "$MANIFEST"
python3 - "$STAMP" "$NEXA_ROOT" "$BACKUP_ONLY" "$BACKUP_SUBDIR" "$NEXA_LOG_DIR" "$NEXA_DATA_DIR" "$NEXA_VAULT_DIR" "$NEXA_DOCS_INBOX_DIR" "$MANIFEST_JSON" <<'PY'
import json
import sys

stamp, nexa_root, backup_only, backup_subdir, log_dir, data_dir, vault_dir, docs_inbox_dir, manifest_json = sys.argv[1:]
with open(manifest_json, "w", encoding="utf-8") as handle:
    json.dump(
        {
            "stamp": stamp,
            "nexa_root": nexa_root,
            "backup_only": backup_only.lower() == "true",
            "backup_subdir": backup_subdir,
            "resolved_paths": {
                "log_dir": log_dir,
                "data_dir": data_dir,
                "vault_dir": vault_dir,
                "docs_inbox_dir": docs_inbox_dir,
            },
        },
        handle,
        indent=2,
    )
PY
ln -sfn "$BACKUP_SUBDIR" "$NEXA_BACKUP_DIR/latest"

# --- Route backup to org node with largest free storage ---
route_backup_to_largest_node() {
  local nodes_file="$1"
  [[ -f "$nodes_file" ]] || return 0
  local winner_host="" winner_path="" winner_avail=0
  local host path avail

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    host="${line%%	*}"
    path="${line#*	}"
    path="${path%%	*}"
    avail="${line##*	}"
    if [[ -n "$avail" ]] && [[ "$avail" =~ ^[0-9]+$ ]] && [[ "$avail" -gt "$winner_avail" ]]; then
      winner_avail="$avail"
      winner_host="$host"
      winner_path="$path"
    fi
  done < <(
    python3 -c "
import json, sys, subprocess
try:
    with open(sys.argv[1]) as f:
        nodes = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    sys.exit(0)
for n in nodes:
    host = n.get('host', '')
    path = n.get('storage_path', '/')
    if not host: continue
    try:
        r = subprocess.run(['ssh', '-o', 'ConnectTimeout=5', '-o', 'BatchMode=yes', host, 'df', '-k', path], capture_output=True, text=True, timeout=10)
        if r.returncode != 0: continue
        lines = r.stdout.strip().splitlines()
        if len(lines) < 2: continue
        parts = lines[-1].split()
        if len(parts) >= 4:
            avail = int(parts[3])
            print(host + chr(9) + path + chr(9) + str(avail))
    except Exception:
        pass
" "$nodes_file" 2>/dev/null
  )

  if [[ -n "$winner_host" ]] && [[ -n "$winner_path" ]]; then
    echo "[backup-dynamic] Routing backup to largest storage: $winner_host ($winner_path) (${winner_avail} KB free)"
    ssh -o ConnectTimeout=10 -o BatchMode=yes "$winner_host" "mkdir -p $winner_path/$STAMP" 2>/dev/null || true
    if rsync -az -e "ssh -o ConnectTimeout=10 -o BatchMode=yes" --delete "$BACKUP_SUBDIR/" "$winner_host:$winner_path/$STAMP/" 2>/dev/null; then
      echo "[backup-dynamic] Synced to $winner_host:$winner_path/$STAMP/"
    else
      echo "[backup-dynamic] rsync to $winner_host failed; backup remains at $BACKUP_SUBDIR"
    fi
  else
    echo "[backup-dynamic] No org nodes reachable or no NEXA_BACKUP_NODES_FILE; backup only local."
  fi
}

route_backup_to_largest_node "$NEXA_BACKUP_NODES_FILE"

echo "[backup-dynamic] Done. Backup at $BACKUP_SUBDIR"
if ! "$BACKUP_ONLY"; then
  echo "[backup-dynamic] Dynamic logs/json/md backed up and removed; system is clean for deploy."
fi
