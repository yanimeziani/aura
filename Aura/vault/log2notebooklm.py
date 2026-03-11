import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path


BASE_DIR = Path("/home/yani/Aura/vault")


DEFAULT_LOGS = {
    "payment_server": "/home/yani/Aura/ai_agency_wealth/server.log",
    "payment_server_debug": "/home/yani/Aura/ai_agency_wealth/server_debug.log",
    "agency_metrics": "/home/yani/Aura/ai_agency_wealth/agency_metrics.log",
    "n8n": "/home/yani/Aura/ai_agency_wealth/n8n.log",
    "fulfiller": "/home/yani/Aura/ai_agency_wealth/fulfiller.log",
}


def _now_stamp() -> str:
    return datetime.now().strftime("%Y%m%d_%H%M%S")


def _safe_mkdir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def _read_tail_lines(path: Path, max_lines: int) -> list[str]:
    if not path.exists():
        return []
    try:
        with path.open("r", errors="replace") as f:
            lines = f.readlines()
        return lines[-max_lines:]
    except Exception:
        return []


_ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")


def _strip_ansi(s: str) -> str:
    return _ANSI_RE.sub("", s)


def _classify_line(line: str) -> str:
    low = line.lower()
    if "traceback (most recent call last)" in low or "exception" in low:
        return "EXC"
    if " error" in low or low.startswith("error") or " 500 " in low:
        return "ERR"
    if " warn" in low or low.startswith("warn"):
        return "WRN"
    if " started" in low or "listening" in low or "ready" in low:
        return "OK"
    return "LOG"


def _fingerprint(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8", errors="ignore")).hexdigest()[:16]


@dataclass
class Packet:
    title: str
    source: str
    created_at: str
    window: str
    summary: list[str]
    key_events: list[str]
    errors: list[str]
    raw_excerpt: str

    def to_markdown(self) -> str:
        lines: list[str] = []
        lines.append(f"# {self.title}")
        lines.append("")
        lines.append("## Metadata")
        lines.append(f"- Source: `{self.source}`")
        lines.append(f"- Created: `{self.created_at}`")
        lines.append(f"- Window: `{self.window}`")
        lines.append("")
        lines.append("## Executive summary")
        if self.summary:
            for item in self.summary:
                lines.append(f"- {item}")
        else:
            lines.append("- No summary available.")
        lines.append("")
        lines.append("## Key events (high signal)")
        if self.key_events:
            for ev in self.key_events:
                lines.append(f"- {ev}")
        else:
            lines.append("- None detected.")
        lines.append("")
        lines.append("## Errors / risk")
        if self.errors:
            for err in self.errors:
                lines.append(f"- {err}")
        else:
            lines.append("- None detected.")
        lines.append("")
        lines.append("## Raw excerpt")
        lines.append("```")
        lines.append(self.raw_excerpt.rstrip())
        lines.append("```")
        lines.append("")
        return "\n".join(lines)


def _summarize(lines: list[str], *, max_events: int = 12, max_errors: int = 12) -> tuple[list[str], list[str], list[str]]:
    """
    Deterministic summarizer (fast, no network):
    - Pulls recent ERR/EXC/WRN/OK lines as "events"
    - Condenses duplicates
    """
    events: list[str] = []
    errors: list[str] = []

    seen = set()
    for raw in reversed(lines):
        s = _strip_ansi(raw).rstrip()
        if not s:
            continue
        kind = _classify_line(s)
        if kind in ("ERR", "EXC"):
            key = ("E", s)
            if key not in seen:
                seen.add(key)
                errors.append(s)
        if kind in ("WRN", "ERR", "EXC", "OK"):
            key = ("K", s)
            if key not in seen:
                seen.add(key)
                events.append(s)
        if len(events) >= max_events and len(errors) >= max_errors:
            break

    events = list(reversed(events))[-max_events:]
    errors = list(reversed(errors))[-max_errors:]

    summary: list[str] = []
    if errors:
        summary.append(f"{len(errors)} error/exception signals detected in the recent window.")
    else:
        summary.append("No error/exception signals detected in the recent window.")
    if events:
        summary.append(f"{len(events)} high-signal events extracted (warn/ok/error).")

    return summary, events, errors


def make_packet(source_path: Path, *, tail_lines: int) -> Packet:
    raw_lines = _read_tail_lines(source_path, tail_lines)
    created_at = datetime.now().isoformat(timespec="seconds")
    window = f"tail({tail_lines})"

    if not raw_lines:
        return Packet(
            title=f"NotebookLM Packet — {source_path.name}",
            source=str(source_path),
            created_at=created_at,
            window=window,
            summary=["Log file missing or empty."],
            key_events=[],
            errors=[],
            raw_excerpt="",
        )

    summary, events, errors = _summarize(raw_lines)
    excerpt = "".join(raw_lines)
    excerpt = _strip_ansi(excerpt)
    # Keep excerpt to a sane size for NotebookLM ingestion.
    if len(excerpt) > 60_000:
        excerpt = excerpt[-60_000:]

    return Packet(
        title=f"NotebookLM Packet — {source_path.name}",
        source=str(source_path),
        created_at=created_at,
        window=window,
        summary=summary,
        key_events=events,
        errors=errors,
        raw_excerpt=excerpt,
    )


def _ffmpeg_exists() -> bool:
    try:
        subprocess.run(["ffmpeg", "-version"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
        return True
    except Exception:
        return False


def _flite_exists() -> bool:
    return subprocess.run(["bash", "-lc", "command -v flite"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0


def _espeak_exists() -> bool:
    return subprocess.run(["bash", "-lc", "command -v espeak-ng || command -v espeak"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0


def _make_tts_wav(text: str, out_wav: Path) -> tuple[bool, str]:
    """
    Produces a WAV using local TTS if available:
    - flite (preferred)
    - espeak-ng/espeak
    """
    _safe_mkdir(out_wav.parent)
    if _flite_exists():
        try:
            r = subprocess.run(["flite", "-t", text, "-o", str(out_wav)], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
            return (r.returncode == 0, r.stderr.strip())
        except Exception as e:
            return False, str(e)

    if _espeak_exists():
        try:
            # espeak outputs to wav with -w
            r = subprocess.run(["bash", "-lc", f"espeak-ng -w {sh_quote(str(out_wav))} {sh_quote(text)} || espeak -w {sh_quote(str(out_wav))} {sh_quote(text)}"], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
            return (r.returncode == 0, r.stderr.strip())
        except Exception as e:
            return False, str(e)

    return False, "No local TTS engine found (install `flite` or `espeak-ng`)."


def sh_quote(s: str) -> str:
    return "'" + s.replace("'", "'\"'\"'") + "'"


def _render_script(packet: Packet) -> str:
    parts: list[str] = []
    parts.append(f"Mission control packet for {Path(packet.source).name}.")
    for item in packet.summary[:5]:
        parts.append(item)
    if packet.errors:
        parts.append("Errors detected. Top items:")
        for e in packet.errors[:5]:
            parts.append(e)
    elif packet.key_events:
        parts.append("High-signal events:")
        for ev in packet.key_events[:5]:
            parts.append(ev)
    return "\n".join(parts)


def _make_audio_and_video(packet: Packet, out_dir: Path, *, basename: str) -> dict:
    """
    Creates:
    - <basename>.wav (via local TTS)
    - <basename>.mp3 (ffmpeg transcode)
    - <basename>.mp4 (simple waveform video)
    - <basename>.srt (very rough captions: whole script as one cue)
    """
    result: dict = {"ok": False, "reason": "", "files": {}}
    if not _ffmpeg_exists():
        result["reason"] = "ffmpeg not available"
        return result

    script_text = _render_script(packet)
    wav = out_dir / f"{basename}.wav"
    mp3 = out_dir / f"{basename}.mp3"
    mp4 = out_dir / f"{basename}.mp4"
    srt = out_dir / f"{basename}.srt"

    ok, reason = _make_tts_wav(script_text, wav)
    if not ok:
        result["reason"] = reason
        return result

    _safe_mkdir(out_dir)
    srt.write_text("1\n00:00:00,000 --> 99:00:00,000\n" + script_text + "\n", encoding="utf-8")

    # wav -> mp3
    r1 = subprocess.run(["ffmpeg", "-y", "-i", str(wav), "-codec:a", "libmp3lame", "-q:a", "4", str(mp3)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if r1.returncode != 0:
        result["reason"] = "ffmpeg mp3 transcode failed"
        return result

    # mp3 -> waveform mp4 (with burned-in captions)
    # Use a black background + showwaves. Burn the single cue captions in.
    r2 = subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-i",
            str(mp3),
            "-filter_complex",
            "color=c=black:s=1280x720:d=3600[bg];"
            "[0:a]showwaves=s=1280x360:mode=cline:colors=white,format=yuv420p[w];"
            "[bg][w]overlay=(W-w)/2:(H-h)/2,subtitles=" + str(srt),
            "-shortest",
            "-c:v",
            "libx264",
            "-crf",
            "23",
            "-preset",
            "veryfast",
            "-c:a",
            "aac",
            "-b:a",
            "128k",
            str(mp4),
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if r2.returncode != 0:
        result["reason"] = "ffmpeg mp4 render failed"
        return result

    result["ok"] = True
    result["files"] = {"wav": str(wav), "mp3": str(mp3), "mp4": str(mp4), "srt": str(srt)}
    return result


def main(argv: list[str] | None = None) -> int:
    if argv is None:
        argv = sys.argv[1:]

    parser = argparse.ArgumentParser(description="Convert logs into NotebookLM packets (and optional audio/video).")
    parser.add_argument("--source", default="agency_metrics", help="Named source or file path.")
    parser.add_argument("--tail", type=int, default=1500, help="Tail N lines from the log.")
    parser.add_argument("--out", default=str(BASE_DIR / "notebooklm_packets"), help="Output directory.")
    parser.add_argument("--audio", action="store_true", help="Also generate TTS audio/video artifacts if possible.")
    args = parser.parse_args(argv)

    source_arg = args.source
    source_path = Path(DEFAULT_LOGS.get(source_arg, source_arg)).expanduser()

    packet = make_packet(source_path, tail_lines=args.tail)

    out_dir = Path(args.out).expanduser()
    _safe_mkdir(out_dir)

    md = packet.to_markdown()
    fp = _fingerprint(md)
    stamp = _now_stamp()
    basename = f"{stamp}_{source_path.name}_{fp}"

    md_path = out_dir / f"{basename}.md"
    json_path = out_dir / f"{basename}.json"

    md_path.write_text(md, encoding="utf-8")
    json_path.write_text(
        json.dumps(
            {
                "title": packet.title,
                "source": packet.source,
                "created_at": packet.created_at,
                "window": packet.window,
                "summary": packet.summary,
                "key_events": packet.key_events,
                "errors": packet.errors,
            },
            indent=2,
        ),
        encoding="utf-8",
    )

    print(f"Wrote: {md_path}")

    if args.audio:
        av = _make_audio_and_video(packet, out_dir, basename=basename)
        if av.get("ok"):
            files = av.get("files", {})
            print(f"Wrote: {files.get('mp3')}")
            print(f"Wrote: {files.get('mp4')}")
        else:
            print(f"Audio/video not generated: {av.get('reason')}")
            print("Tip: install `flite` or `espeak-ng` for local TTS.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

