# agent.Dockerfile — OpenClaw Agent Runner
# Uses Claude Code CLI (claude -p) — no Anthropic API key required
# Build arg: AGENT_ID (devsecops | growth)

FROM debian:bookworm-slim AS base

ARG AGENT_ID=devsecops
ENV AGENT_ID=${AGENT_ID}

# Security: no root at runtime — proper home dir for claude credentials
RUN groupadd -r agent && useradd -r -m -g agent -d /home/agent agent

# System tools + Node.js for Claude CLI
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git jq python3 python3-pip ca-certificates \
    ripgrep \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Claude Code CLI (OAuth-auth'd via claude auth login on host)
RUN npm install -g @anthropic-ai/claude-code

# Security scanning tools
RUN curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh \
      | sh -s -- -b /usr/local/bin 2>/dev/null || true

RUN curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
      | sh -s -- -b /usr/local/bin 2>/dev/null || true

WORKDIR /app

# Copy agent config (baked in; can be overridden by volume mount)
COPY agents/${AGENT_ID}/ /app/config/

# MCP server config — enables GitHub, filesystem, fetch, memory MCPs
COPY mcp/mcp-servers.json /app/mcp-servers.json

# Install Python dependencies
RUN pip3 install --no-cache-dir --break-system-packages -r /app/config/requirements.txt

# Pre-warm MCP server npm packages so first invocation is fast
RUN npx -y @modelcontextprotocol/server-github --help 2>/dev/null || true \
    && npx -y @modelcontextprotocol/server-filesystem --help 2>/dev/null || true \
    && npx -y @modelcontextprotocol/server-fetch --help 2>/dev/null || true \
    && npx -y @modelcontextprotocol/server-memory --help 2>/dev/null || true \
    && npx -y @modelcontextprotocol/server-sequential-thinking --help 2>/dev/null || true

# Copy credential-setup wrapper
COPY docker/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Runtime user
USER agent

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["python3", "/app/config/entrypoint.py"]
