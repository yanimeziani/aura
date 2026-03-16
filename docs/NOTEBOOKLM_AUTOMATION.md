# NotebookLM Automation

## Purpose

This document describes how to automate the Nexa documentation export and optionally push it into NotebookLM.

## Automation Layers

### 1. Official and stable

Build and publish the canonical bundle:

```bash
./ops/bin/nexa publish-notebooklm
```

This does the following:

- builds `nexa-docs-notebooklm.txt`
- computes SHA-256 and byte size
- writes a manifest to `.nexa/exports/notebooklm-manifest.json`
- maintains `.nexa/exports/notebooklm/latest.txt`
- optionally publishes to IPFS if configured

Primary import targets:

- file: `/root/nexa-docs-notebooklm.txt`
- live URL: `http://<gateway-host>:8765/docs/nexa`

### 2. Unofficial last-mile automation

NotebookLM does not currently expose a documented public import API. The repo therefore includes an optional Playwright uploader:

```bash
./ops/bin/nexa notebooklm-upload
```

This drives the NotebookLM web UI and is therefore brittle compared with the stable bundle build step.

## Environment Variables

For publishing:

- `NEXA_DOCS_BUNDLE_OUT`
- `NEXA_NOTEBOOKLM_EXPORT_DIR`
- `NEXA_NOTEBOOKLM_MANIFEST`
- `NEXA_NOTEBOOKLM_SOURCE_URL`
- `NEXA_NOTEBOOKLM_IPFS_PUBLISH=1`
- `NEXA_VAULT_TOKEN` when IPFS publish is enabled

For NotebookLM upload:

- `NOTEBOOKLM_NOTEBOOK_URL`
- `NOTEBOOKLM_SOURCE_MODE=url` or `file`
- `NOTEBOOKLM_SOURCE_URL`
- `NOTEBOOKLM_SOURCE_FILE`
- `NOTEBOOKLM_USER_DATA_DIR`
- `NOTEBOOKLM_HEADLESS=0`

## Recommended Workflow

1. Publish the current bundle:

```bash
./ops/bin/nexa publish-notebooklm
```

2. Import the live URL into NotebookLM manually at least once:

- `http://<gateway-host>:8765/docs/nexa`

3. Reuse the same notebook with the Playwright uploader:

```bash
NOTEBOOKLM_NOTEBOOK_URL="https://notebooklm.google.com/notebook/..." \
NOTEBOOKLM_SOURCE_MODE="url" \
NOTEBOOKLM_SOURCE_URL="http://127.0.0.1:8765/docs/nexa" \
./ops/bin/nexa notebooklm-upload
```

## Login Model

The Playwright uploader is designed to work with a persistent Chromium profile. On first run, sign in manually in the opened browser window. Subsequent runs reuse that session from `NOTEBOOKLM_USER_DATA_DIR`.

## Operational Recommendation

Treat the build-and-publish step as the real automation boundary. Treat UI automation as optional convenience, not as the foundation of the pipeline.
