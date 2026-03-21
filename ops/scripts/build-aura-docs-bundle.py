#!/usr/bin/env python3
"""
Build a single documentation bundle for NotebookLM and public/operator consumption.
Includes only curated core Nexa docs. Never includes: logs, PII, vault contents,
org-registry, backup-nodes, .env, or any deployment-specific data.
Output: one text file suitable for media summarisation and audio/video asset creation.
"""
from pathlib import Path
import os
import sys

# Repo root (set by caller or assume cwd)
REPO_ROOT = Path(os.environ.get("AURA_ROOT", os.environ.get("REPO_ROOT", "."))).resolve()
if not (REPO_ROOT / "README.md").exists() and (REPO_ROOT / "docs").exists() == False:
    REPO_ROOT = Path(__file__).resolve().parent.parent.parent

# Strict allowlist: paths relative to REPO_ROOT. No vault, no logs, no secrets.
DOC_ALLOWLIST = [
    "README.md",
    "DISCLAIMER.md",
    "PRD.md",
    "SECURITY.md",
    "LEGAL.md",
    "MARKETING.md",
    "STACK.md",
    "ICP.md",
    "TASKS.md",
    "docs/AGENTS.md",
    "docs/RAG_CORPUS_MANIFEST.md",
    "docs/SEED.md",
    "docs/FORGE_24H_PLAN.md",
    "docs/MESH_WORLD_MODEL.md",
    "docs/ARCHITECTURE_DISTILL.md",
    "LICENSE.md",
    "ops/gateway/README.md",
]

# Directories to never include (even if someone adds them by mistake)
FORBIDDEN_SUBSTRINGS = [
    "vault",
    ".env",
    "aura-vault",
    "org-registry",
    "backup-nodes",
    "notebooklm_packets",
    "log",
    "leads.json",
    "telemetry_visits",
    "gateway_sessions",
]


def is_forbidden(path: str) -> bool:
    p = path.lower()
    return any(f in p for f in FORBIDDEN_SUBSTRINGS)


def main() -> None:
    out_path = os.environ.get("AURA_DOCS_BUNDLE_OUT", str(REPO_ROOT / "nexa-docs-notebooklm.txt"))
    out_file = Path(out_path)
    out_file.parent.mkdir(parents=True, exist_ok=True)

    buf = []
    buf.append("# Nexa — Core documentation bundle")
    buf.append("")
    buf.append("Single source for NotebookLM ingestion, technical review, and downstream asset generation.")
    buf.append("Primary use: neutral technical summarisation, audio narration, video script generation, and architecture retrieval.")
    buf.append("Reading order: source guides first, then architecture and protocol docs, then deployment and capability docs, then dated updates.")
    buf.append("The bundle is written to be technically precise, operationally useful, and tone-neutral.")
    buf.append("This bundle never contains: system logs, PII, vault secrets, or deployment-specific data.")
    buf.append("")
    buf.append("## Bundle Orientation")
    buf.append("")
    buf.append("Nexa is a sovereign collaboration protocol stack for humans and AI systems.")
    buf.append("When generating media, prefer architecture, trust boundaries, transport design, recovery flows, and implementation status over slogans or personality framing.")
    buf.append("")
    buf.append("---")
    buf.append("")

    for rel in DOC_ALLOWLIST:
        if is_forbidden(rel):
            continue
        full = REPO_ROOT / rel
        if not full.exists():
            continue
        try:
            text = full.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        buf.append(f"## File: {rel}")
        buf.append("")
        buf.append(text.strip())
        buf.append("")
        buf.append("---")
        buf.append("")

    # Agent-written updates (realtime-included in GET /docs/nexa)
    updates_dir = REPO_ROOT / "docs" / "updates"
    if updates_dir.is_dir():
        for f in sorted(updates_dir.glob("*.md")):
            if f.name.startswith("."):
                continue
            try:
                text = f.read_text(encoding="utf-8", errors="replace")
                buf.append(f"## File: docs/updates/{f.name}")
                buf.append("")
                buf.append(text.strip())
                buf.append("")
                buf.append("---")
                buf.append("")
            except OSError:
                pass

    out_file.write_text("\n".join(buf), encoding="utf-8")
    print(f"Written: {out_file}", file=sys.stderr)
    print(str(out_file))


if __name__ == "__main__":
    main()
