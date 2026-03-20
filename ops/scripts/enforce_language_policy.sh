#!/bin/bash
# Strict Language Policy Enforcer for Yani Meziani
# Allowed: Zig, HTML, CSS, TS, JSON, MD, Build Configs

ARCHIVE_BASE="/root/archive/non_compliant_code"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ARCHIVE_DIR="$ARCHIVE_BASE/$TIMESTAMP"
mkdir -p "$ARCHIVE_DIR"

echo "=== Meziani AI: Strict Language Policy Enforcement ==="

# Define preservation patterns
KEEP_EXTS=("zig" "html" "css" "ts" "json" "md" "txt" "toml" "yaml" "yml" "pem" "enc")
KEEP_FILES=("Makefile" "build.zig" "package.json" "tsconfig.json" ".gitignore" "LICENSE" "PRD.md" "SOVEREIGN_SHIELD_MANIFESTO.md")

# Ensure critical ops scripts are kept
KEEP_SCRIPTS=("enforce_language_policy.sh" "defense-sanitize-android.sh" "defense-setup-termux.sh" "defense-setup-proot.sh" "versailles_transfer.sh")

is_protected_script() {
    local base=$(basename "$1")
    for s in "${KEEP_SCRIPTS[@]}"; do
        [[ "$base" == "$s" ]] && return 0
    done
    return 1
}

is_allowed_ext() {
    local ext="${1##*.}"
    for e in "${KEEP_EXTS[@]}"; do
        [[ "$ext" == "$e" ]] && return 0
    done
    return 1
}

is_allowed_file() {
    local base=$(basename "$1")
    for f in "${KEEP_FILES[@]}"; do
        [[ "$base" == "$f" ]] && return 0
    done
    return 1
}

# Traverse and archive
find /root -type d \( -path "/root/.git" -o -path "/root/archive" -o -path "/root/node_modules" -o -path "/root/.gemini" -o -path "/root/.local/zig-*" \) -prune -o -type f -print | while read -r file; do
    
    # Skip if it's an allowed extension or file
    if is_allowed_ext "$file" || is_allowed_file "$file" || is_protected_script "$file"; then
        continue
    fi

    # Archive everything else
    rel_path="${file#/root/}"
    mkdir -p "$ARCHIVE_DIR/$(dirname "$rel_path")"
    mv "$file" "$ARCHIVE_DIR/$rel_path"
done

echo "Archival complete. Cleaning ghost regions..."

# Delete empty directories recursively (except protected roots)
find /root -type d \( -path "/root/.git" -o -path "/root/archive" -o -path "/root/node_modules" -o -path "/root/.gemini" \) -prune -o -type d -empty -delete 2>/dev/null
find /root -type d \( -path "/root/.git" -o -path "/root/archive" -o -path "/root/node_modules" -o -path "/root/.gemini" \) -prune -o -type d -empty -delete 2>/dev/null

echo "=== Policy Enforced. Codebase is now Sovereign Zig/Web. ==="
