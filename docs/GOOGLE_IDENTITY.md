# Workspace identity (optional MCP bridge)

This optional path lets Nexa reach a **third-party workspace suite** (mail, calendar, drive) through an MCP server under `core/google-mcp/`. Keep vendor console steps in the provider’s own documentation; do not store **account emails**, **OAuth secrets**, or **refresh tokens** in this repository.

## Accounts

- Configure primary and secondary accounts **only** via environment variables and local vault files ignored by git.
- Never list personal emails in markdown committed to the tree.

## Prerequisites

1. Cloud developer project with OAuth desktop credentials for the workspace APIs you enable.
2. APIs enabled for the surfaces you need (mail, calendar, storage, etc.).
3. OAuth client ID and secret held in env or secret manager — not in `docs/`.

## Setup

```bash
export GOOGLE_OAUTH_CLIENT_ID="your-client-id"
export GOOGLE_OAUTH_CLIENT_SECRET="your-client-secret"
```

## Running

```bash
python nexa.py identity
```

The first tool invocation should return an authorization URL; complete OAuth in the browser. Multi-account flows follow the server’s OAuth 2.1 behavior.
