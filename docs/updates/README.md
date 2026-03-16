# docs/updates — Agent and operator updates (NotebookLM / public)

**All agents must write documentation here** so it appears in the single public docs URL in realtime.

- **URL:** `GET /docs/nexa` (e.g. `https://<gateway-host>/gw/docs/nexa`) — NotebookLM and public/operator consumption.
- **Realtime:** The bundle is built on each request from the repo; any `.md` file you add under `docs/updates/` is included automatically.
- **Rules:**
  - Write only **core Nexa documentation**: architecture, runbooks, product updates, operator briefs. No logs, PII, vault content, or deployment-specific secrets.
  - Use descriptive filenames: `YYYY-MM-DD-short-topic.md` or `topic-update.md`.
  - This directory is for **additions and updates** that should be reflected in media summarisation and audio/video assets for operators and public.
  - Write like a technical source memo, not marketing copy: state the mechanism, changed behavior, operational impact, limits, and recovery notes.
  - Keep tone neutral and reusable for NotebookLM ingestion. Avoid hype, theatrics, or negative persona framing.
  - Follow [NOTEBOOKLM_SOURCE_GUIDE.md](/root/docs/NOTEBOOKLM_SOURCE_GUIDE.md) for the full source-writing contract.
