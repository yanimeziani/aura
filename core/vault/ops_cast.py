import argparse
import json
import os
import re
import urllib.error
import urllib.request
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

from log2notebooklm import BASE_DIR, DEFAULT_LOGS, _fingerprint, _now_stamp, _safe_mkdir, make_packet
from log_radio import make_audio_and_video_from_script


REPO_ROOT = Path(os.environ.get("AURA_ROOT", BASE_DIR.parent.parent))
OUT_DIR = BASE_DIR / "ops_cast"
DOC_ROOT = REPO_ROOT / "docs"

SAFE_DOC_SOURCES = [
    REPO_ROOT / "README.md",
    DOC_ROOT / "QUICKSTART.md",
    DOC_ROOT / "AGENTS.md",
]

SECRET_PATTERNS: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----.*?-----END [A-Z ]*PRIVATE KEY-----", re.DOTALL), "[REDACTED_PRIVATE_KEY]"),
    (re.compile(r"(?i)\bBearer\s+[A-Za-z0-9._~+/=-]+\b"), "Bearer [REDACTED_TOKEN]"),
    (re.compile(r"\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b"), "[REDACTED_JWT]"),
    (re.compile(r"(?i)\b(?:api[_-]?key|secret|token|password|passwd|authorization|cookie|session[_-]?id)\b([^\n]{0,24}?)([:=]\s*[\"']?)([^\"'\s,;]+)"), r"\g<0>".replace(r"\g<0>", "")),
    (re.compile(r"\b\d{1,3}(?:\.\d{1,3}){3}\b"), "[REDACTED_IP]"),
    (re.compile(r"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b", re.IGNORECASE), "[REDACTED_EMAIL]"),
    (re.compile(r"\b[0-9a-fA-F]{32,}\b"), "[REDACTED_HEX_SECRET]"),
]

KEY_VALUE_RE = re.compile(
    r"(?i)\b(api[_-]?key|secret|token|password|passwd|authorization|cookie|session[_-]?id)\b([^\n]{0,24}?)([:=]\s*[\"']?)([^\"'\s,;]+)"
)
WORD_RE = re.compile(r"[a-zA-Z][a-zA-Z0-9_.-]{3,}")
STOPWORDS = {
    "this",
    "that",
    "with",
    "from",
    "into",
    "current",
    "state",
    "error",
    "errors",
    "exception",
    "signals",
    "detected",
    "recent",
    "window",
    "high",
    "signal",
    "none",
    "were",
    "what",
    "when",
    "have",
    "will",
    "would",
    "should",
    "must",
}


@dataclass
class EpisodePackage:
    title: str
    source_name: str
    source_path: str
    created_at: str
    provider: str
    model: str
    target_minutes: int
    target_words: int
    bulletin_state: str
    summary: list[str]
    key_events: list[str]
    errors: list[str]
    rag_context: list[dict[str, Any]]
    script: str
    files: dict[str, str]


def redact_text(text: str) -> str:
    out = text
    out = KEY_VALUE_RE.sub(lambda m: f"{m.group(1)}{m.group(2)}{m.group(3)}[REDACTED_SECRET]", out)
    for pattern, replacement in SECRET_PATTERNS:
        if replacement:
            out = pattern.sub(replacement, out)
    return out


def sanitize_packet(packet: Any) -> dict[str, Any]:
    return {
        "title": redact_text(packet.title),
        "source": str(packet.source),
        "created_at": packet.created_at,
        "window": packet.window,
        "summary": [redact_text(item) for item in packet.summary],
        "key_events": [redact_text(item) for item in packet.key_events],
        "errors": [redact_text(item) for item in packet.errors],
        "raw_excerpt": redact_text(packet.raw_excerpt),
    }


def load_safe_doc_chunks(max_chars: int = 80_000) -> list[dict[str, str]]:
    chunks: list[dict[str, str]] = []
    remaining = max_chars

    sources = list(SAFE_DOC_SOURCES)
    updates_dir = DOC_ROOT / "updates"
    if updates_dir.exists():
        sources.extend(sorted(updates_dir.glob("*.md"), reverse=True)[:8])

    for path in sources:
        if not path.exists() or remaining <= 0:
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue

        text = redact_text(text)
        paragraphs = [p.strip() for p in text.split("\n\n") if p.strip()]
        for index, paragraph in enumerate(paragraphs, start=1):
            if remaining <= 0:
                break
            if "```" in paragraph:
                continue
            trimmed = paragraph[: min(len(paragraph), 1200, remaining)]
            if len(trimmed) < 80:
                continue
            chunks.append(
                {
                    "path": str(path),
                    "chunk_id": f"{path.name}:{index}",
                    "text": trimmed,
                }
            )
            remaining -= len(trimmed)
    return chunks


def retrieve_context(packet_dict: dict[str, Any], *, top_k: int = 6) -> list[dict[str, Any]]:
    docs = load_safe_doc_chunks()
    query = " ".join(packet_dict["summary"] + packet_dict["key_events"] + packet_dict["errors"])
    terms = {word.lower() for word in WORD_RE.findall(query) if word.lower() not in STOPWORDS}
    if not terms:
        return docs[:top_k]

    ranked: list[tuple[int, dict[str, str]]] = []
    for chunk in docs:
        haystack = chunk["text"].lower()
        score = sum(haystack.count(term) for term in terms)
        if score > 0:
            ranked.append((score, chunk))

    ranked.sort(key=lambda item: item[0], reverse=True)
    if ranked:
        return [{"score": score, **chunk} for score, chunk in ranked[:top_k]]
    return [{"score": 0, **chunk} for chunk in docs[:top_k]]


def build_prompt(packet_dict: dict[str, Any], rag_context: list[dict[str, Any]], *, source_name: str, target_minutes: int, target_words: int) -> str:
    context_payload = json.dumps(
        {
            "telemetry": packet_dict,
            "rag_context": [{"path": item["path"], "chunk_id": item["chunk_id"], "text": item["text"]} for item in rag_context],
        },
        ensure_ascii=True,
        indent=2,
    )
    return (
        "You are generating an internal Aura Stack operations podcast episode.\n"
        "Strict rules:\n"
        "- Two speakers only: HOST_A and HOST_B.\n"
        "- Use only the telemetry and curated docs context provided.\n"
        "- Never invent incidents, outages, fixes, or metrics.\n"
        "- Treat any missing data as unknown.\n"
        "- Speak like operators during a serious handoff, not marketing.\n"
        "- Mention when signals are degraded or stale.\n"
        "- Do not reveal secrets, credentials, IP addresses, emails, or tokens.\n"
        f"- Target about {target_words} words, suitable for roughly {target_minutes} minutes when narrated with pauses and transitions.\n"
        "- Output plain text only.\n"
        "- Start every paragraph with HOST_A: or HOST_B:.\n"
        "- Cover: current state, recent changes, top risks, anomalies, operator actions, and what must be verified next hour.\n\n"
        f"Source name: {source_name}\n"
        f"Episode target minutes: {target_minutes}\n"
        f"Episode target words: {target_words}\n\n"
        f"Context:\n{context_payload}\n"
    )


def generate_with_ollama(prompt: str, *, model: str) -> str:
    body = json.dumps(
        {
            "model": model,
            "prompt": prompt,
            "stream": False,
            "options": {
                "temperature": 0.2,
                "num_ctx": 16384,
            },
        }
    ).encode("utf-8")
    req = urllib.request.Request(
        os.environ.get("AURA_OLLAMA_URL", "http://127.0.0.1:11434/api/generate"),
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=240) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.URLError as exc:
        raise RuntimeError(f"ollama request failed: {exc}") from exc

    text = (payload.get("response") or "").strip()
    if not text:
        raise RuntimeError("ollama returned empty response")
    return redact_text(text)


def generate_deterministic_script(packet_dict: dict[str, Any], rag_context: list[dict[str, Any]], *, source_name: str, target_minutes: int) -> str:
    intro = [
        f"HOST_A: This is the hourly Aura Stack operations handoff for {source_name}. The aim of this episode is a {target_minutes}-minute operator briefing built from sanitized telemetry and curated project documentation.",
        "HOST_B: This run is deterministic fallback mode, so the script is concise and should be treated as a control-plane summary, not a long-form narrative. The production path should use a local OSS model inside the isolated generation zone.",
    ]

    summary_lines = packet_dict["summary"] or ["No summary signals were extracted."]
    event_lines = packet_dict["key_events"] or ["No high-signal events were extracted from the current window."]
    error_lines = packet_dict["errors"] or ["No explicit errors were extracted from the current window."]
    context_lines = rag_context or []

    body: list[str] = []
    for item in summary_lines[:3]:
        body.append(f"HOST_A: Current state. {item}")
    for item in event_lines[:6]:
        body.append(f"HOST_B: Recent event. {item}")
    for item in error_lines[:4]:
        body.append(f"HOST_A: Risk signal. {item}")
    for item in context_lines[:4]:
        snippet = item["text"].replace("\n", " ").strip()
        body.append(f"HOST_B: Project context from {Path(item['path']).name}. {snippet[:320]}")

    outro = [
        "HOST_A: Operator actions for the next cycle are to verify the underlying service health, confirm the telemetry source is still fresh, and check whether any alerts require human approval before remediation.",
        "HOST_B: Security note. This episode was generated from sanitized telemetry and curated documentation only. Raw logs, vault material, and public documentation remain separate trust zones.",
    ]

    return "\n\n".join(intro + body + outro)


def generate_script(packet_dict: dict[str, Any], rag_context: list[dict[str, Any]], *, source_name: str, provider: str, model: str, target_minutes: int, target_words: int) -> tuple[str, str]:
    if provider == "ollama":
        prompt = build_prompt(
            packet_dict,
            rag_context,
            source_name=source_name,
            target_minutes=target_minutes,
            target_words=target_words,
        )
        return generate_with_ollama(prompt, model=model), model
    return generate_deterministic_script(packet_dict, rag_context, source_name=source_name, target_minutes=target_minutes), "deterministic-local"


def write_episode_artifacts(
    source_path: Path,
    *,
    source_name: str,
    tail_lines: int,
    provider: str,
    model: str,
    out_dir: Path,
    audio: bool,
    target_minutes: int,
    target_words: int,
) -> EpisodePackage:
    packet = make_packet(source_path, tail_lines=tail_lines)
    packet_dict = sanitize_packet(packet)
    rag_context = retrieve_context(packet_dict)
    script, model_used = generate_script(
        packet_dict,
        rag_context,
        source_name=source_name,
        provider=provider,
        model=model,
        target_minutes=target_minutes,
        target_words=target_words,
    )

    _safe_mkdir(out_dir)
    stamp = _now_stamp()
    fp = _fingerprint(script + source_name + packet.created_at)
    basename = f"{stamp}_{source_path.name}_{provider}_{fp}"

    script_path = out_dir / f"{basename}.txt"
    json_path = out_dir / f"{basename}.json"

    script_path.write_text(script + "\n", encoding="utf-8")

    files = {"script": script_path.name}
    if audio:
        av = make_audio_and_video_from_script(script, out_dir, basename=basename)
        if av.get("ok"):
            files.update({kind: Path(path).name for kind, path in (av.get("files") or {}).items()})

    package = EpisodePackage(
        title=f"Aura Ops Cast — {source_name}",
        source_name=source_name,
        source_path=str(source_path),
        created_at=packet.created_at,
        provider=provider,
        model=model_used,
        target_minutes=target_minutes,
        target_words=target_words,
        bulletin_state="live" if packet.raw_excerpt.strip() else "empty",
        summary=packet_dict["summary"],
        key_events=packet_dict["key_events"],
        errors=packet_dict["errors"],
        rag_context=rag_context,
        script=script,
        files=files,
    )
    json_path.write_text(json.dumps(asdict(package), indent=2), encoding="utf-8")
    package.files["json"] = json_path.name
    json_path.write_text(json.dumps(asdict(package), indent=2), encoding="utf-8")
    return package


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Generate a sanitized two-host Aura operations podcast package.")
    parser.add_argument("--source", default="agency_metrics", help="Named source or explicit path.")
    parser.add_argument("--tail", type=int, default=800, help="Tail N lines from the log.")
    parser.add_argument("--provider", choices=["local", "ollama"], default="local", help="Generation provider.")
    parser.add_argument("--model", default=os.environ.get("AURA_OPS_CAST_MODEL", "qwen2.5:14b-instruct"), help="Local OSS model for Ollama.")
    parser.add_argument("--out", default=str(OUT_DIR), help="Output directory.")
    parser.add_argument("--audio", action="store_true", help="Also render local audio/video artifacts.")
    parser.add_argument("--target-minutes", type=int, default=60, help="Narrative duration target.")
    parser.add_argument("--target-words", type=int, default=7000, help="Word target for LLM generation.")
    args = parser.parse_args(argv)

    source_arg = args.source
    source_path = Path(DEFAULT_LOGS.get(source_arg, source_arg)).expanduser()
    source_name = source_arg if source_arg in DEFAULT_LOGS else source_path.name

    package = write_episode_artifacts(
        source_path,
        source_name=source_name,
        tail_lines=args.tail,
        provider=args.provider,
        model=args.model,
        out_dir=Path(args.out).expanduser(),
        audio=bool(args.audio),
        target_minutes=max(5, args.target_minutes),
        target_words=max(1200, args.target_words),
    )
    print(f"Wrote: {Path(args.out).expanduser() / package.files['json']}")
    print(f"Wrote: {Path(args.out).expanduser() / package.files['script']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
