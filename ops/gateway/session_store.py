"""In-process session store for gateway sync. Keyed by workspace_id; persisted under the Nexa runtime root."""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import Any, Optional

GATEWAY_DIR = Path(__file__).resolve().parent
OPS_DIR = GATEWAY_DIR.parent
REPO_ROOT = OPS_DIR.parent
for candidate in (OPS_DIR, REPO_ROOT):
    candidate_str = str(candidate)
    if candidate_str not in sys.path:
        sys.path.insert(0, candidate_str)

from aura_runtime import sessions_file
try:
    from gateway.spec_models import SessionRecord, validate_workspace_id
except ImportError:
    from spec_models import SessionRecord, validate_workspace_id


def _sessions_path() -> Path:
    return sessions_file()


def _load_all() -> dict[str, Any]:
    p = _sessions_path()
    if not p.exists():
        return {}
    try:
        with open(p, "r") as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError):
        return {}


def _save_all(data: dict[str, Any]) -> None:
    p = _sessions_path()
    p.parent.mkdir(parents=True, exist_ok=True)
    with open(p, "w") as f:
        json.dump(data, f, indent=2)
    try:
        os.chmod(p, 0o600)
    except OSError:
        pass


def get_session(workspace_id: str) -> Optional[dict[str, Any]]:
    workspace_id = validate_workspace_id(workspace_id)
    return _load_all().get(workspace_id)


def set_session(workspace_id: str, payload: dict[str, Any]) -> None:
    record = SessionRecord.from_values(workspace_id, payload)
    data = _load_all()
    data[record.workspace_id] = record.payload
    _save_all(data)


def delete_session(workspace_id: str) -> bool:
    workspace_id = validate_workspace_id(workspace_id)
    data = _load_all()
    if workspace_id not in data:
        return False
    del data[workspace_id]
    _save_all(data)
    return True
