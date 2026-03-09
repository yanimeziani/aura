"""In-process session store for gateway sync. Keyed by workspace_id; persisted under AURA_ROOT."""
import json
import os
from pathlib import Path
from typing import Any, Optional

DEFAULT_SESSIONS_FILE = os.environ.get("AURA_GATEWAY_SESSIONS", "")


def _sessions_path() -> Path:
    if DEFAULT_SESSIONS_FILE:
        return Path(DEFAULT_SESSIONS_FILE)
    root = os.environ.get("AURA_ROOT", "/home/yani/Aura")
    return Path(root) / ".aura" / "gateway_sessions.json"


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
    return _load_all().get(workspace_id)


def set_session(workspace_id: str, payload: dict[str, Any]) -> None:
    data = _load_all()
    data[workspace_id] = payload
    _save_all(data)


def delete_session(workspace_id: str) -> bool:
    data = _load_all()
    if workspace_id not in data:
        return False
    del data[workspace_id]
    _save_all(data)
    return True
