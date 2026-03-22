"""Repository paths for the media forge (single source of truth)."""

from __future__ import annotations

from pathlib import Path


def repo_root() -> Path:
    """Nexa repository root (parent of ``tools``)."""
    return Path(__file__).resolve().parent.parent.parent


def staging_dir(root: Path | None = None) -> Path:
    """Approved staging directory for media outputs pending HITL review."""
    base = root if root is not None else repo_root()
    return base / "vault" / "media_staging"
