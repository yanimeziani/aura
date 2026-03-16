# Aura Ops Cast Architecture

## Security first

You cannot make a large distributed system "secure against literally any possible danger." The real target is stricter:

- reduce blast radius
- isolate trust zones
- remove secret-bearing data before generation
- make offensive testing explicit and controlled
- keep human approval on destructive actions

For Aura, that means the ops podcast generator must never have direct access to the vault, production control plane, or public documentation endpoint.

## Required trust zones

1. Production zone
Raw services, node agents, databases, queues, vault, private mesh, and original logs. No LLM generation here.

2. Sanitization zone
A one-way export job tails the required logs, strips secrets and identifiers, normalizes events, and writes sanitized packets. This zone can read production telemetry but cannot execute control actions back into production.

3. Generation zone
An isolated worker or node runs only OSS local models plus TTS. It reads sanitized packets and curated docs, generates the two-host script, and publishes audio artifacts. No vault. No prod SSH. No write path into production.

4. Operator zone
Mission Control, dashboards, and human review. Operators can listen, inspect the sanitized packet, and decide whether any follow-up action should be pushed into the HITL queue.

## Data split

Use two different knowledge feeds:

- Ops telemetry feed: sanitized hourly packets from `core/vault/ops_cast.py`
- Project-state RAG feed: curated docs only, such as `README.md`, `docs/QUICKSTART.md`, `docs/AGENTS.md`, and `docs/updates/*.md`

Do not mix raw logs into the same index as public or shareable documentation. Raw logs are transient and secret-prone. Curated docs are durable and safe for NotebookLM-style retrieval.

## Hourly pipeline

1. Tail the production logs you actually need.
2. Sanitize and redact before any model sees them.
3. Retrieve only curated project docs for background context.
4. Generate a two-speaker script with a local OSS model through Ollama.
5. Render audio locally if needed.
6. Publish the episode package plus metadata to an internal-only artifact directory.

Example:

```bash
python3 core/vault/ops_cast.py \
  --source agency_metrics \
  --provider ollama \
  --model qwen2.5:14b-instruct \
  --target-minutes 60 \
  --target-words 7000 \
  --audio
```

Run that from a systemd timer every hour in the generation zone, not on the production hosts.

## Minimum controls

- Separate Unix users for prod collection, sanitization, generation, and dashboard serving.
- Separate hosts or VMs for production and generation.
- Egress-deny by default in generation except for local model and internal artifact storage.
- Read-only mounts for sanitized packets and curated docs.
- Immutable artifact directory for completed episodes.
- Signed metadata for each episode package.
- HITL gate for any remediation actions derived from the episode.
- Regular red-team validation against the redaction layer.

## What exists now

- `core/vault/log2notebooklm.py`: deterministic log packetization
- `core/vault/log_radio.py`: short radio bulletin generation
- `core/vault/ops_cast.py`: sanitized two-host episode packaging with safe-doc RAG and optional local Ollama generation

The remaining production work is operational:

- move generation off the prod node
- feed `ops_cast.py` only sanitized exports
- schedule it hourly
- add artifact signing and alert review
