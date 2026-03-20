import argparse
import json
import os
import shutil
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Any

from faster_whisper import WhisperModel

# Optional radio integration if it exists
try:
    from log_radio import DEFAULT_OUT_DIR as RADIO_OUT_DIR
    from log_radio import write_radio_artifacts
    RADIO_AVAILABLE = True
except ImportError:
    RADIO_AVAILABLE = False


AURA_ROOT = Path(os.environ.get("AURA_ROOT", "/home/yani/Aura"))
VOICE_DIR = AURA_ROOT / ".aura" / "voice"
VOICE_CHUNKS_DIR = VOICE_DIR / "chunks"
VOICE_LOG_PATH = VOICE_DIR / "voice.log"
VOICE_TRANSCRIPTS_PATH = VOICE_DIR / "transcripts.jsonl"
VOICE_STATE_PATH = VOICE_DIR / "state.json"
VOICE_LATEST_PATH = VOICE_DIR / "latest.txt"


def _env_int(name: str, default: int) -> int:
    try:
        return int(os.environ.get(name, default))
    except Exception:
        return default


def _safe_mkdir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def _write_json(path: Path, payload: dict[str, Any]) -> None:
    _safe_mkdir(path.parent)
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def _read_json(path: Path) -> dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}


def _now() -> str:
    return datetime.now().isoformat(timespec="seconds")


def _model_name() -> str:
    # Upgrade default to large-v3-turbo for "Super" mode
    return os.environ.get("AURA_VOICE_MODEL", "large-v3-turbo")


def _language() -> str | None:
    language = os.environ.get("AURA_VOICE_LANGUAGE", "").strip()
    return language or None


def _device() -> str:
    return os.environ.get("AURA_VOICE_DEVICE", "cpu")


def _compute_type() -> str:
    return os.environ.get("AURA_VOICE_COMPUTE_TYPE", "int8")


def _chunk_seconds() -> int:
    # Super mode defaults to 4s for lower latency
    return max(2, _env_int("AURA_VOICE_CHUNK_SECONDS", 4))


def _radio_enabled() -> bool:
    return os.environ.get("AURA_VOICE_RADIO", "1").strip().lower() not in {"0", "false", "no", "off"}


def _radio_audio_enabled() -> bool:
    return os.environ.get("AURA_VOICE_RADIO_AUDIO", "1").strip().lower() not in {"0", "false", "no", "off"}


def _radio_provider() -> str:
    return os.environ.get("AURA_VOICE_RADIO_PROVIDER", "auto").strip().lower() or "auto"


def _radio_interval() -> int:
    return max(10, _env_int("AURA_VOICE_RADIO_MIN_INTERVAL_SEC", 60))


def _radio_tail_lines() -> int:
    return max(10, _env_int("AURA_VOICE_RADIO_TAIL_LINES", 80))

def _clipboard_enabled() -> bool:
    # Default to ON for super whisper experience
    return os.environ.get("AURA_VOICE_CLIPBOARD", "1").strip().lower() not in {"0", "false", "no", "off"}


def _pick_recorder() -> list[str]:
    if shutil.which("pw-record"):
        return ["pw-record", "--rate", "16000", "--channels", "1", "--format", "s16"]
    if shutil.which("arecord"):
        return ["arecord", "-q", "-f", "S16_LE", "-r", "16000", "-c", "1"]
    raise RuntimeError("no compatible recorder found; expected pw-record or arecord on Fedora")


def record_chunk(output_path: Path, *, seconds: int) -> dict[str, Any]:
    _safe_mkdir(output_path.parent)
    if output_path.exists():
        output_path.unlink()

    cmd = ["timeout", "--signal=INT", f"{seconds}s", *_pick_recorder(), str(output_path)]
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    # Allow small chunks
    ok = output_path.exists() and output_path.stat().st_size > 44
    return {
        "ok": ok,
        "returncode": result.returncode,
        "stdout": result.stdout.strip(),
        "stderr": result.stderr.strip(),
        "path": str(output_path),
        "size": output_path.stat().st_size if output_path.exists() else 0,
        "seconds": seconds,
    }


def load_model() -> WhisperModel:
    return WhisperModel(_model_name(), device=_device(), compute_type=_compute_type())


def transcribe_file(model: WhisperModel, audio_path: Path, *, language: str | None) -> dict[str, Any]:
    # Super settings for speed: beam_size=1, best_of=1
    segments_iter, info = model.transcribe(
        str(audio_path),
        language=language,
        beam_size=1,
        best_of=1,
        condition_on_previous_text=False,
        vad_filter=True,
        temperature=0.0,
    )
    segments = list(segments_iter)
    text = " ".join(segment.text.strip() for segment in segments if segment.text.strip()).strip()
    return {
        "text": text,
        "language": getattr(info, "language", None),
        "language_probability": getattr(info, "language_probability", None),
        "duration": getattr(info, "duration", None),
        "segments": [
            {
                "start": segment.start,
                "end": segment.end,
                "text": segment.text.strip(),
            }
            for segment in segments
            if segment.text.strip()
        ],
    }


def append_transcript(text: str, *, meta: dict[str, Any]) -> None:
    payload = {
        "at": _now(),
        "text": text,
        **meta,
    }
    _safe_mkdir(VOICE_DIR)
    
    # 1. Permanent logs
    with VOICE_TRANSCRIPTS_PATH.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(payload, ensure_ascii=True) + "\n")
    with VOICE_LOG_PATH.open("a", encoding="utf-8") as handle:
        handle.write(f"{payload['at']} VOICE READY: {text}\n")
    
    # 2. Latest file for other agents to read
    VOICE_LATEST_PATH.write_text(text + "\n", encoding="utf-8")
    
    # 3. Clipboard Bridge (Super Whisper Experience)
    if _clipboard_enabled():
        if shutil.which("wl-copy"):
            subprocess.run(["wl-copy", text], check=False)
        elif shutil.which("xclip"):
            subprocess.run(["xclip", "-selection", "clipboard"], input=text.encode("utf-8"), check=False)


def maybe_broadcast_radio(*, last_radio_at: float, provider: str, audio: bool) -> float:
    if not RADIO_AVAILABLE:
        return last_radio_at
        
    now = time.time()
    if now - last_radio_at < _radio_interval():
        return last_radio_at

    try:
        write_radio_artifacts(
            VOICE_LOG_PATH,
            source_name="voice_stream",
            tail_lines=_radio_tail_lines(),
            provider=provider,
            model=None,
            out_dir=RADIO_OUT_DIR,
            audio=audio,
        )
    except Exception as exc:
        print(f"Radio broadcast error: {exc}", file=sys.stderr)

    return now


def listen_forever(*, keep_audio: bool, iterations: int) -> int:
    _safe_mkdir(VOICE_DIR)
    _safe_mkdir(VOICE_CHUNKS_DIR)

    print(f"🔮 AURA SUPER WHISPER: Loading {_model_name()} on {_device()}...")
    model = load_model()
    print(f"📡 LISTEN ACTIVE (chunk={_chunk_seconds()}s, clipboard={_clipboard_enabled()})")

    last_radio_at = 0.0
    state = _read_json(VOICE_STATE_PATH)
    transcript_count = int(state.get("transcript_count") or 0)

    loops = 0
    while True:
        stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        chunk_path = VOICE_CHUNKS_DIR / f"{stamp}.wav"
        capture = record_chunk(chunk_path, seconds=_chunk_seconds())

        state = {
            "running": True,
            "at": _now(),
            "model": _model_name(),
            "device": _device(),
            "compute_type": _compute_type(),
            "language": _language(),
            "chunk_seconds": _chunk_seconds(),
            "recorder_path": capture["path"],
            "recorder_ok": capture["ok"],
            "recorder_returncode": capture["returncode"],
            "recorder_size": capture["size"],
            "transcript_count": transcript_count,
            "radio_enabled": _radio_enabled(),
            "clipboard_enabled": _clipboard_enabled(),
            "last_error": "",
        }

        if not capture["ok"]:
            # Normal on silences/recorder reset
            _write_json(VOICE_STATE_PATH, state)
            time.sleep(0.5)
            continue

        try:
            result = transcribe_file(model, chunk_path, language=_language())
        except Exception as exc:
            state["last_error"] = str(exc)
            _write_json(VOICE_STATE_PATH, state)
            if not keep_audio:
                chunk_path.unlink(missing_ok=True)
            time.sleep(1.0)
            continue

        text = (result["text"] or "").strip()
        if text:
            transcript_count += 1
            append_transcript(
                text,
                meta={
                    "language": result["language"],
                    "language_probability": result["language_probability"],
                    "duration": result["duration"],
                    "audio_path": str(chunk_path),
                },
            )
            print(f"[{_now()}] Captured: {text}")
            state["last_transcript_at"] = _now()
            state["last_transcript"] = text
            state["transcript_count"] = transcript_count
            if _radio_enabled():
                last_radio_at = maybe_broadcast_radio(
                    last_radio_at=last_radio_at,
                    provider=_radio_provider(),
                    audio=_radio_audio_enabled(),
                )
                state["last_radio_at"] = datetime.fromtimestamp(last_radio_at).isoformat(timespec="seconds")
        else:
            state["last_transcript"] = ""

        _write_json(VOICE_STATE_PATH, state)

        if not keep_audio:
            chunk_path.unlink(missing_ok=True)

        loops += 1
        if iterations > 0 and loops >= iterations:
            break

    final_state = _read_json(VOICE_STATE_PATH)
    final_state["running"] = False
    final_state["stopped_at"] = _now()
    _write_json(VOICE_STATE_PATH, final_state)
    return 0


def show_state() -> int:
    state = _read_json(VOICE_STATE_PATH)
    latest = ""
    if VOICE_LATEST_PATH.exists():
        latest = VOICE_LATEST_PATH.read_text(encoding="utf-8").strip()
    print(json.dumps({"state": state, "latest": latest}, indent=2))
    return 0


def main(argv: list[str] | None = None) -> int:
    if argv is None:
        argv = sys.argv[1:]

    parser = argparse.ArgumentParser(description="Aura local voice ingress using faster-whisper on Fedora.")
    sub = parser.add_subparsers(dest="cmd", required=True)

    transcribe_cmd = sub.add_parser("transcribe", help="Transcribe a local audio file.")
    transcribe_cmd.add_argument("audio_path")
    transcribe_cmd.add_argument("--json", action="store_true", help="Emit JSON instead of plain text.")

    listen_cmd = sub.add_parser("listen", help="Run the continuous microphone transcription loop.")
    listen_cmd.add_argument("--keep-audio", action="store_true", help="Keep chunk WAV files for debugging.")
    listen_cmd.add_argument("--iterations", type=int, default=0, help="Run N chunks and then exit (0 = forever).")

    sub.add_parser("show", help="Print current voice state and latest transcript.")

    args = parser.parse_args(argv)

    if args.cmd == "transcribe":
        model = load_model()
        result = transcribe_file(model, Path(args.audio_path).expanduser(), language=_language())
        if args.json:
            print(json.dumps(result, indent=2))
        else:
            print(result["text"])
        return 0

    if args.cmd == "listen":
        return listen_forever(keep_audio=bool(args.keep_audio), iterations=max(0, int(args.iterations or 0)))

    if args.cmd == "show":
        return show_state()

    return 1


if __name__ == "__main__":
    raise SystemExit(main())
