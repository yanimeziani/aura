#!/bin/sh
# Agent container entrypoint — sets up Claude CLI credentials then runs agent

# Copy auth credentials to a writable tmpfs location so claude CLI can write session state
if [ -d /mnt/claude-auth ] && [ "$(ls -A /mnt/claude-auth 2>/dev/null)" ]; then
    mkdir -p /tmp/claude-cfg
    cp -r /mnt/claude-auth/. /tmp/claude-cfg/
    export CLAUDE_CONFIG_DIR=/tmp/claude-cfg
    echo "[entrypoint] Claude credentials loaded"
else
    echo "[entrypoint] WARNING: /mnt/claude-auth is empty — run 'claude auth login' on the VPS host first"
fi

exec "$@"
