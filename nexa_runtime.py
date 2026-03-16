from __future__ import annotations

import os
from pathlib import Path
from typing import Iterable


def nexa_root(explicit: str | Path | None = None) -> Path:
    if explicit:
        return Path(explicit).expanduser().resolve()
    env_root = os.environ.get("NEXA_ROOT")
    if env_root:
        return Path(env_root).expanduser().resolve()
    return Path(__file__).resolve().parent


def _candidate_paths(root: Path, candidates: Iterable[str]) -> list[Path]:
    return [(root / candidate).resolve() for candidate in candidates]


def _first_existing(candidates: Iterable[Path]) -> Path | None:
    for candidate in candidates:
        if candidate.exists():
            return candidate
    return None


def resolve_path(
    *,
    env_name: str,
    root: str | Path | None = None,
    candidates: Iterable[str],
    default: str,
) -> Path:
    env_value = os.environ.get(env_name)
    if env_value:
        return Path(env_value).expanduser().resolve()
    resolved_root = nexa_root(root)
    existing = _first_existing(_candidate_paths(resolved_root, candidates))
    if existing is not None:
        return existing
    return (resolved_root / default).resolve()


def vault_dir(root: str | Path | None = None) -> Path:
    return resolve_path(
        env_name="NEXA_VAULT_DIR",
        root=root,
        candidates=("core/vault", "vault"),
        default="core/vault",
    )


def vault_file(root: str | Path | None = None) -> Path:
    root_path = nexa_root(root)
    env_value = os.environ.get("NEXA_VAULT_FILE")
    if env_value:
        return Path(env_value).expanduser().resolve()
    for candidate in ("nexa-vault.json", "vault.json"):
        existing = _first_existing((vault_dir(root_path) / candidate,))
        if existing is not None:
            return existing
    return (vault_dir(root_path) / "nexa-vault.json").resolve()


def data_dir(root: str | Path | None = None) -> Path:
    return resolve_path(
        env_name="NEXA_DATA_DIR",
        root=root,
        candidates=("data", ".nexa/data"),
        default="data",
    )


def log_dir(root: str | Path | None = None) -> Path:
    return resolve_path(
        env_name="NEXA_LOG_DIR",
        root=root,
        candidates=("logs", ".nexa/logs"),
        default=".nexa/logs",
    )


def backup_dir(root: str | Path | None = None) -> Path:
    return resolve_path(
        env_name="NEXA_BACKUP_DIR",
        root=root,
        candidates=(".nexa/backups", "backups"),
        default=".nexa/backups",
    )


def telemetry_file(root: str | Path | None = None) -> Path:
    root_path = nexa_root(root)
    return resolve_path(
        env_name="NEXA_TELEMETRY_FILE",
        root=root_path,
        candidates=(
            "data/telemetry_visits.json",
            ".nexa/data/telemetry_visits.json",
        ),
        default="data/telemetry_visits.json",
    )


def leads_file(root: str | Path | None = None) -> Path:
    root_path = nexa_root(root)
    return resolve_path(
        env_name="NEXA_LEADS_FILE",
        root=root_path,
        candidates=(
            "core/wealth/leads.json",
            "ai_agency_wealth/leads.json",
            "data/leads.json",
        ),
        default="data/leads.json",
    )


def org_registry_file(root: str | Path | None = None) -> Path:
    root_path = nexa_root(root)
    return resolve_path(
        env_name="NEXA_ORG_REGISTRY",
        root=root_path,
        candidates=("core/vault/org-registry.json", "vault/org-registry.json"),
        default="core/vault/org-registry.json",
    )


def backup_nodes_file(root: str | Path | None = None) -> Path:
    root_path = nexa_root(root)
    return resolve_path(
        env_name="NEXA_BACKUP_NODES_FILE",
        root=root_path,
        candidates=("core/vault/backup-nodes.json", "vault/backup-nodes.json"),
        default="core/vault/backup-nodes.json",
    )


def docs_inbox_dir(root: str | Path | None = None) -> Path:
    root_path = nexa_root(root)
    return resolve_path(
        env_name="NEXA_DOCS_INBOX_DIR",
        root=root_path,
        candidates=("core/vault/docs_inbox", "vault/docs_inbox"),
        default="core/vault/docs_inbox",
    )


def sessions_file(root: str | Path | None = None) -> Path:
    return resolve_path(
        env_name="NEXA_GATEWAY_SESSIONS",
        root=root,
        candidates=(".nexa/gateway_sessions.json", "data/gateway_sessions.json"),
        default=".nexa/gateway_sessions.json",
    )


def export_file(root: str | Path | None = None) -> Path:
    return resolve_path(
        env_name="NEXA_EXPORT_FILE",
        root=root,
        candidates=(
            ".nexa/exports/Nexa_Full_Documentation_Export.txt",
            "Nexa_Full_Documentation_Export.txt",
        ),
        default=".nexa/exports/Nexa_Full_Documentation_Export.txt",
    )
