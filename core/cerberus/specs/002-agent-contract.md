# Spec 002 - Agent Contract and Preservation Rules

## Status

Draft

## Scope

Defines the minimum contract Cerberus must honor so existing agent behavior (from the prior OpenClaw stack) can be preserved during migration.

## Preserved Assets

- Agent IDs and roles:
  - `devsecops`
  - `growth`
- Prompt files:
  - `agents/<agent>/prompts/system.md`
  - `agents/<agent>/prompts/task-templates.md`
- MCP definitions:
  - `mcp/mcp-servers.json`
  - `mcp/agent-mcp-config.yaml`
- Policy files:
  - `policies/cost-caps.yaml`
  - `policies/hitl-gates.yaml`
  - `policies/risk-labels.yaml`
  - `policies/model-routing.yaml`

## Behavioral Requirements

1. Per-agent schedules are preserved (`always_on` and `burst`).
2. Cost controls enforce both per-task and daily caps.
3. HITL approval blocks risky actions before execution.
4. Artifact output remains markdown, grouped by agent.
5. Panic mode can pause task execution globally.

## Claude Pro Requirements

- Runtime must support `claude -p` execution.
- Runtime must load host OAuth state from mounted read-only source.
- Runtime may copy credentials to writable ephemeral directory before invocation.
- Runtime must set `CLAUDE_SKIP_AUTO_UPDATE=1`.

## MCP Requirements

- Required MCP servers:
  - `github`
  - `filesystem`
  - `fetch`
  - `memory`
  - `sequential-thinking`
- Filesystem paths must use `/data/cerberus/...` (migrated from legacy `/data/openclaw/...`).

## Compatibility Criteria

- Existing prompt content can run without rewrite.
- Existing task template shape can be adapted with thin translation only.
- Existing runbooks require path/name updates only, not conceptual redesign.
