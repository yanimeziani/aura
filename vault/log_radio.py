import argparse
import json
import os
from datetime import datetime
from pathlib import Path
from typing import Any

import httpx

from log2notebooklm import (
    BASE_DIR,
    DEFAULT_LOGS,
    _fingerprint,
    _now_stamp,
    _safe_mkdir,
    make_audio_and_video_from_script,
    make_packet,
)


VAULT_FILE = Path(os.environ.get("AURA_VAULT_FILE", str(BASE_DIR / "aura-vault.json")))
DEFAULT_OUT_DIR = BASE_DIR / "radio"


def load_vault() -> dict[str, str]:
    if not VAULT_FILE.exists():
        return {}
    try:
        return json.loads(VAULT_FILE.read_text(encoding="utf-8"))
    except Exception:
        return {}


def _clean_str(value: Any) -> str | None:
    if value is None:
        return None
    if isinstance(value, str):
        out = value.strip()
        return out or None
    return None


def _pick_provider(requested: str, vault: dict[str, str]) -> str:
    requested = (requested or "auto").strip().lower()
    has_gemini = bool(vault.get("GEMINI_API_KEY") or os.environ.get("GEMINI_API_KEY"))
    has_groq = bool(vault.get("GROQ_API_KEY") or os.environ.get("GROQ_API_KEY"))

    if requested == "auto":
        if has_gemini:
            return "gemini"
        if has_groq:
            return "groq"
        return "local"

    if requested == "gemini" and not has_gemini:
        raise RuntimeError("gemini requested but GEMINI_API_KEY is not configured")
    if requested == "groq" and not has_groq:
        raise RuntimeError("groq requested but GROQ_API_KEY is not configured")
    if requested not in {"gemini", "groq", "local"}:
        raise RuntimeError(f"unsupported provider: {requested}")
    return requested


def _radio_prompt(packet_dict: dict[str, Any]) -> str:
    payload = json.dumps(packet_dict, ensure_ascii=True, indent=2)
    return (
        "You are Aura Radio, a concise live operations host.\n"
        "Turn the structured log packet into a short spoken bulletin.\n"
        "Rules:\n"
        "- 90 to 140 words.\n"
        "- Sound like live mission control radio, not marketing.\n"
        "- Lead with the source name and current state.\n"
        "- Mention the highest-signal events.\n"
        "- If there are errors, say that clearly.\n"
        "- No bullets, no markdown, no intro labels.\n"
        "- Plain text only.\n\n"
        f"Packet:\n{payload}\n"
    )


def _generate_gemini(packet_dict: dict[str, Any], vault: dict[str, str], model: str | None) -> tuple[str, str]:
    key = vault.get("GEMINI_API_KEY") or os.environ.get("GEMINI_API_KEY")
    if not key:
        raise RuntimeError("GEMINI_API_KEY is not configured")
    selected_model = model or "gemini-2.5-flash"
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{selected_model}:generateContent?key={key}"
    body = {
        "contents": [
            {
                "role": "user",
                "parts": [{"text": _radio_prompt(packet_dict)}],
            }
        ],
        "generationConfig": {"temperature": 0.4, "maxOutputTokens": 220},
    }
    with httpx.Client(timeout=40.0) as client:
        response = client.post(url, json=body, headers={"Content-Type": "application/json"})
        response.raise_for_status()
    payload = response.json()
    candidates = payload.get("candidates", [])
    if not candidates:
        raise RuntimeError("Gemini returned no candidates")
    parts = candidates[0].get("content", {}).get("parts", [])
    text = "".join(part.get("text", "") for part in parts).strip()
    if not text:
        raise RuntimeError("Gemini returned empty text")
    return text, selected_model


def _generate_groq(packet_dict: dict[str, Any], vault: dict[str, str], model: str | None) -> tuple[str, str]:
    key = vault.get("GROQ_API_KEY") or os.environ.get("GROQ_API_KEY")
    if not key:
        raise RuntimeError("GROQ_API_KEY is not configured")
    selected_model = (
        model
        or _clean_str(vault.get("OPENAI_MODEL_NAME"))
        or _clean_str(os.environ.get("OPENAI_MODEL_NAME"))
        or "llama-3.3-70b-versatile"
    )
    api_base = (vault.get("OPENAI_API_BASE") or os.environ.get("OPENAI_API_BASE") or "https://api.groq.com/openai/v1").rstrip("/")
    body = {
        "model": selected_model,
        "messages": [{"role": "user", "content": _radio_prompt(packet_dict)}],
        "temperature": 0.4,
        "max_tokens": 220,
    }
    with httpx.Client(timeout=40.0) as client:
        response = client.post(
            f"{api_base}/chat/completions",
            json=body,
            headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
        )
        response.raise_for_status()
    payload = response.json()
    choices = payload.get("choices") or []
    if not choices:
        raise RuntimeError("Groq returned no choices")
    text = ((choices[0].get("message") or {}).get("content") or "").strip()
    if not text:
        raise RuntimeError("Groq returned empty text")
    return text, selected_model


def _generate_local(packet_dict: dict[str, Any]) -> tuple[str, str]:
    source = packet_dict["source_name"]
    summary = packet_dict.get("summary") or []
    events = packet_dict.get("key_events") or []
    errors = packet_dict.get("errors") or []

    lines = [f"Aura Radio, {source}."]
    if errors:
        lines.append(f"Alert state. {len(errors)} error signals are active in the latest window.")
    else:
        lines.append("System state is stable in the latest window, with no error signals detected.")

    if summary:
        lines.append(summary[0])
    if events:
        lines.append("Top signal. " + events[0])
    if len(events) > 1:
        lines.append("Next signal. " + events[1])
    if errors:
        lines.append("Priority item. " + errors[0])

    return " ".join(lines).strip(), "deterministic-local"


def _source_state(source_path: Path, packet: Any) -> str:
    if not source_path.exists():
        return "missing"
    try:
        if source_path.stat().st_size <= 0:
            return "empty"
    except OSError:
        return "missing"
    if not (packet.raw_excerpt or "").strip():
        return "empty"
    return "live"


def _offline_bulletin(source_name: str, source_path: Path, *, source_state: str, created_at: str) -> str:
    if source_state == "missing":
        return (
            f"Aura Radio, {source_name}. This source is offline. "
            f"The log path {source_path} is missing as of {created_at}, so there is no live signal to report."
        )
    return (
        f"Aura Radio, {source_name}. This source is empty right now. "
        f"The log feed at {source_path} has no current events as of {created_at}, so there is no live signal to report."
    )


def generate_radio_bulletin(source_path: Path, *, source_name: str, tail_lines: int, provider: str, model: str | None) -> dict[str, Any]:
    packet = make_packet(source_path, tail_lines=tail_lines)
    source_state = _source_state(source_path, packet)
    vault = load_vault()
    packet_dict = {
        "source_name": source_name,
        "source_path": str(source_path),
        "created_at": packet.created_at,
        "window": packet.window,
        "summary": packet.summary,
        "key_events": packet.key_events,
        "errors": packet.errors,
    }

    if source_state != "live":
        bulletin = _offline_bulletin(source_name, source_path, source_state=source_state, created_at=packet.created_at)
        provider_used = "local"
        selected_model = "deterministic-empty-source"
    else:
        provider_used = _pick_provider(provider, vault)
        if provider_used == "gemini":
            bulletin, selected_model = _generate_gemini(packet_dict, vault, model)
        elif provider_used == "groq":
            bulletin, selected_model = _generate_groq(packet_dict, vault, model)
        else:
            bulletin, selected_model = _generate_local(packet_dict)

    return {
        "packet": packet,
        "bulletin": bulletin,
        "provider_requested": provider,
        "provider_used": provider_used,
        "model": selected_model,
        "source_state": source_state,
    }


def write_radio_artifacts(source_path: Path, *, source_name: str, tail_lines: int, provider: str, model: str | None, out_dir: Path, audio: bool) -> dict[str, Any]:
    result = generate_radio_bulletin(
        source_path,
        source_name=source_name,
        tail_lines=tail_lines,
        provider=provider,
        model=model,
    )
    packet = result["packet"]
    bulletin = result["bulletin"]
    created_at = datetime.now().isoformat(timespec="seconds")

    _safe_mkdir(out_dir)
    stamp = _now_stamp()
    fp = _fingerprint(bulletin + packet.source + created_at)
    basename = f"{stamp}_{source_path.name}_{result['provider_used']}_{fp}"

    txt_path = out_dir / f"{basename}.txt"
    json_path = out_dir / f"{basename}.json"

    txt_path.write_text(bulletin + "\n", encoding="utf-8")

    files: dict[str, str] = {"txt": txt_path.name}
    audio_result = {"ok": False, "reason": "audio disabled", "files": {}}
    if audio:
        audio_result = make_audio_and_video_from_script(bulletin, out_dir, basename=basename)
        if audio_result.get("ok"):
            files.update({kind: Path(path).name for kind, path in (audio_result.get("files") or {}).items()})

    metadata = {
        "title": f"Aura Radio — {source_name}",
        "source_name": source_name,
        "source_path": str(source_path),
        "source_state": result["source_state"],
        "created_at": created_at,
        "tail_lines": tail_lines,
        "provider_requested": result["provider_requested"],
        "provider_used": result["provider_used"],
        "model": result["model"],
        "bulletin": bulletin,
        "summary": packet.summary,
        "key_events": packet.key_events,
        "errors": packet.errors,
        "audio_ok": bool(audio_result.get("ok")),
        "audio_reason": audio_result.get("reason", ""),
        "files": files,
    }
    json_path.write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    metadata["files"]["json"] = json_path.name
    json_path.write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    return metadata


def main(argv: list[str] | None = None) -> int:
    if argv is None:
        argv = os.sys.argv[1:]

    parser = argparse.ArgumentParser(description="Convert logs into short radio bulletins with optional audio artifacts.")
    parser.add_argument("--source", default="agency_metrics", help="Named source or explicit path.")
    parser.add_argument("--tail", type=int, default=240, help="Tail N lines from the log.")
    parser.add_argument("--provider", default="auto", choices=["auto", "gemini", "groq", "local"], help="Narration provider.")
    parser.add_argument("--model", default=None, help="Optional provider-specific model override.")
    parser.add_argument("--out", default=str(DEFAULT_OUT_DIR), help="Output directory.")
    parser.add_argument("--audio", action="store_true", help="Generate local audio/video artifacts.")
    args = parser.parse_args(argv)

    source_arg = args.source
    source_path = Path(DEFAULT_LOGS.get(source_arg, source_arg)).expanduser()
    source_name = source_arg if source_arg in DEFAULT_LOGS else source_path.name

    meta = write_radio_artifacts(
        source_path,
        source_name=source_name,
        tail_lines=args.tail,
        provider=args.provider,
        model=args.model,
        out_dir=Path(args.out).expanduser(),
        audio=args.audio,
    )

    print(f"Wrote: {Path(args.out).expanduser() / meta['files']['json']}")
    if meta["files"].get("mp3"):
        print(f"Wrote: {Path(args.out).expanduser() / meta['files']['mp3']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
