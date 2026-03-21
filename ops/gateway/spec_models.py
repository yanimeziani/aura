from __future__ import annotations

import json
import re
from functools import lru_cache
from pathlib import Path
from typing import Any

from pydantic import BaseModel, Field


REPO_ROOT = Path(__file__).resolve().parents[2]
SPECS_DIR = REPO_ROOT / "specs"


class IdentifierRule(BaseModel):
    pattern: str
    max_length: int
    default: str | None = None


class ProtocolSpec(BaseModel):
    name: str
    version: str
    actors: list[str]
    identifiers: dict[str, IdentifierRule]
    session: dict[str, Any]
    artifacts: dict[str, Any]


class HitlActionSpec(BaseModel):
    id: str
    method: str
    path: str
    reason: str


class TrustSpec(BaseModel):
    name: str
    version: str
    trust_tiers: list[str]
    allowed_transitions: dict[str, list[str]]
    hitl_actions: list[HitlActionSpec]


class RecoverySpec(BaseModel):
    name: str
    version: str
    invariants: list[str]
    continuity: dict[str, Any]


def _model_validate(cls: type[BaseModel], data: dict[str, Any]) -> BaseModel:
    if hasattr(cls, "model_validate"):
        return cls.model_validate(data)  # type: ignore[attr-defined]
    return cls.parse_obj(data)


def _model_dump(model: BaseModel) -> dict[str, Any]:
    if hasattr(model, "model_dump"):
        return model.model_dump()  # type: ignore[attr-defined]
    return model.dict()


@lru_cache(maxsize=1)
def protocol_spec() -> ProtocolSpec:
    return _model_validate(ProtocolSpec, _load_spec("protocol.json"))  # type: ignore[return-value]


@lru_cache(maxsize=1)
def trust_spec() -> TrustSpec:
    return _model_validate(TrustSpec, _load_spec("trust.json"))  # type: ignore[return-value]


@lru_cache(maxsize=1)
def recovery_spec() -> RecoverySpec:
    return _model_validate(RecoverySpec, _load_spec("recovery.json"))  # type: ignore[return-value]


def _load_spec(name: str) -> dict[str, Any]:
    path = SPECS_DIR / name
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def _identifier_rule(name: str) -> IdentifierRule:
    try:
        return protocol_spec().identifiers[name]
    except KeyError as exc:
        raise ValueError(f"unknown identifier rule: {name}") from exc


def _validate_identifier(name: str, value: str) -> str:
    rule = _identifier_rule(name)
    text = value.strip()
    if not text:
        raise ValueError(f"{name} must not be empty")
    if len(text) > rule.max_length:
        raise ValueError(f"{name} exceeds max length {rule.max_length}")
    if not re.fullmatch(rule.pattern, text):
        raise ValueError(f"{name} does not match required pattern")
    return text


def default_workspace_id() -> str:
    default = protocol_spec().identifiers["workspace_id"].default
    return default or "nexa"


def validate_workspace_id(value: str) -> str:
    return _validate_identifier("workspace_id", value)


def validate_org_id(value: str) -> str:
    return _validate_identifier("org_id", value)


def validate_session_payload(payload: dict[str, Any]) -> dict[str, Any]:
    encoded = json.dumps(payload, separators=(",", ":"), ensure_ascii=True).encode("utf-8")
    max_bytes = int(protocol_spec().session.get("max_payload_bytes", 262144))
    if len(encoded) > max_bytes:
        raise ValueError(f"session payload exceeds {max_bytes} bytes")
    return payload


def trust_tiers() -> list[str]:
    return list(trust_spec().trust_tiers)


def ensure_trust_transition(current: str, target: str) -> str:
    spec = trust_spec()
    if current not in spec.trust_tiers:
        raise ValueError(f"unknown current trust tier: {current}")
    if target not in spec.trust_tiers:
        raise ValueError(f"unknown target trust tier: {target}")
    if current == target:
        return target
    allowed = spec.allowed_transitions.get(current, [])
    if target not in allowed:
        raise ValueError(f"invalid trust transition: {current} -> {target}")
    return target


def hitl_actions() -> list[dict[str, str]]:
    return [_model_dump(action) for action in trust_spec().hitl_actions]


def named_spec(name: str) -> dict[str, Any]:
    mapping = {
        "protocol": _model_dump(protocol_spec()),
        "trust": _model_dump(trust_spec()),
        "recovery": _model_dump(recovery_spec()),
    }
    try:
        return mapping[name]
    except KeyError as exc:
        raise ValueError(f"unknown spec: {name}") from exc


def spec_bundle() -> dict[str, Any]:
    return {
        "protocol": named_spec("protocol"),
        "trust": named_spec("trust"),
        "recovery": named_spec("recovery"),
    }


class SessionRecord(BaseModel):
    workspace_id: str = Field(..., max_length=64)
    payload: dict[str, Any]

    @classmethod
    def from_values(cls, workspace_id: str, payload: dict[str, Any]) -> "SessionRecord":
        validated_workspace_id = validate_workspace_id(workspace_id)
        validated_payload = validate_session_payload(payload)
        return cls(workspace_id=validated_workspace_id, payload=validated_payload)
