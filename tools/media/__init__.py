"""
Media Gen AI Forge — audit, paths, and cinematic orchestration.

Import from ``media`` with ``tools/`` on ``sys.path`` (see CLI shims in ``tools/``).
"""

from media.audit import AuditResult, audit_media_copy, evaluate_media_copy
from media.forge import orchestrate_movie, run_step
from media.paths import repo_root, staging_dir

__all__ = [
    "AuditResult",
    "audit_media_copy",
    "evaluate_media_copy",
    "orchestrate_movie",
    "repo_root",
    "run_step",
    "staging_dir",
]
