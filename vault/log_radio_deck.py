import argparse
import json
import os
import signal
import time
from datetime import datetime
from pathlib import Path

from log2notebooklm import DEFAULT_LOGS, _fingerprint, make_packet
from log_radio import DEFAULT_OUT_DIR, write_radio_artifacts


RADIO_DIR = DEFAULT_OUT_DIR
STATE_PATH = RADIO_DIR / "deck_state.json"
PID_PATH = RADIO_DIR / "deck.pid"

_running = True


def _safe_mkdir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def _write_state(payload: dict) -> None:
    _safe_mkdir(RADIO_DIR)
    STATE_PATH.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def _read_state() -> dict:
    try:
        return json.loads(STATE_PATH.read_text(encoding="utf-8"))
    except Exception:
        return {}


def _source_snapshot(path: Path) -> dict:
    if not path.exists():
        return {"state": "missing", "size": 0, "mtime": None, "mtime_ts": 0.0}
    try:
        stat = path.stat()
    except OSError:
        return {"state": "missing", "size": 0, "mtime": None, "mtime_ts": 0.0}
    state = "live" if stat.st_size > 0 else "empty"
    return {
        "state": state,
        "size": stat.st_size,
        "mtime": datetime.fromtimestamp(stat.st_mtime).isoformat(timespec="seconds"),
        "mtime_ts": stat.st_mtime,
    }


def _resolve_source(source_arg: str) -> dict:
    requested_path = Path(DEFAULT_LOGS.get(source_arg, source_arg)).expanduser()
    requested_name = source_arg if source_arg in DEFAULT_LOGS else requested_path.name
    requested_snapshot = _source_snapshot(requested_path)

    if requested_snapshot["state"] == "live":
        return {
            "requested_source": requested_name,
            "requested_path": requested_path,
            "requested_state": requested_snapshot["state"],
            "source_name": requested_name,
            "source_path": requested_path,
            "source_state": requested_snapshot["state"],
            "source_size": requested_snapshot["size"],
            "source_mtime": requested_snapshot["mtime"],
            "fallback": False,
            "degraded_reason": "",
        }

    if source_arg in DEFAULT_LOGS:
        candidates: list[tuple[float, str, Path, dict]] = []
        for name, raw_path in DEFAULT_LOGS.items():
            path = Path(raw_path).expanduser()
            snapshot = _source_snapshot(path)
            if snapshot["state"] == "live":
                candidates.append((snapshot["mtime_ts"], name, path, snapshot))

        if candidates:
            _mtime_ts, name, path, snapshot = max(candidates, key=lambda item: item[0])
            return {
                "requested_source": requested_name,
                "requested_path": requested_path,
                "requested_state": requested_snapshot["state"],
                "source_name": name,
                "source_path": path,
                "source_state": snapshot["state"],
                "source_size": snapshot["size"],
                "source_mtime": snapshot["mtime"],
                "fallback": True,
                "degraded_reason": f"requested source {requested_name} is {requested_snapshot['state']}; using {name}",
            }

    return {
        "requested_source": requested_name,
        "requested_path": requested_path,
        "requested_state": requested_snapshot["state"],
        "source_name": requested_name,
        "source_path": requested_path,
        "source_state": requested_snapshot["state"],
        "source_size": requested_snapshot["size"],
        "source_mtime": requested_snapshot["mtime"],
        "fallback": False,
        "degraded_reason": "no live log sources available",
    }


def _stop(*_args) -> None:
    global _running
    _running = False


def main(argv: list[str] | None = None) -> int:
    if argv is None:
        argv = os.sys.argv[1:]

    parser = argparse.ArgumentParser(description="Continuous Aura Radio deck.")
    parser.add_argument("--source", default="agency_metrics")
    parser.add_argument("--tail", type=int, default=240)
    parser.add_argument("--provider", default="auto", choices=["auto", "gemini", "groq", "local"])
    parser.add_argument("--model", default=None)
    parser.add_argument("--interval", type=int, default=60)
    parser.add_argument("--out", default=str(RADIO_DIR))
    parser.add_argument("--audio", action="store_true")
    args = parser.parse_args(argv)

    signal.signal(signal.SIGTERM, _stop)
    signal.signal(signal.SIGINT, _stop)

    out_dir = Path(args.out).expanduser()
    _safe_mkdir(out_dir)
    PID_PATH.write_text(str(os.getpid()), encoding="utf-8")

    source_arg = args.source

    state = _read_state()
    same_request = state.get("requested_source") == source_arg
    broadcast_count = int(state.get("broadcast_count") or 0) if same_request else 0
    last_input_fp = (state.get("last_input_fp") or "") if same_request else ""
    last_broadcast_at = state.get("last_broadcast_at") if same_request else None
    last_broadcast_file = state.get("last_broadcast_file") if same_request else None

    try:
        while _running:
            resolved = _resolve_source(source_arg)
            packet = make_packet(resolved["source_path"], tail_lines=args.tail)
            signal_seed = packet.raw_excerpt or "\n".join(packet.summary + packet.key_events + packet.errors)
            current_fp = _fingerprint(f"{resolved['source_name']}\n{signal_seed}")
            now = time.strftime("%Y-%m-%dT%H:%M:%S")

            if resolved["source_state"] == "live" and current_fp != last_input_fp:
                meta = write_radio_artifacts(
                    resolved["source_path"],
                    source_name=resolved["source_name"],
                    tail_lines=args.tail,
                    provider=args.provider,
                    model=args.model,
                    out_dir=out_dir,
                    audio=args.audio,
                )
                broadcast_count += 1
                last_input_fp = current_fp
                last_broadcast_at = now
                last_broadcast_file = (meta.get("files") or {}).get("json")
                _write_state(
                    {
                        "running": True,
                        "pid": os.getpid(),
                        "requested_source": resolved["requested_source"],
                        "requested_state": resolved["requested_state"],
                        "source": resolved["source_name"],
                        "source_state": resolved["source_state"],
                        "source_size": resolved["source_size"],
                        "source_mtime": resolved["source_mtime"],
                        "fallback": resolved["fallback"],
                        "degraded_reason": resolved["degraded_reason"],
                        "provider": args.provider,
                        "model": args.model,
                        "interval": args.interval,
                        "tail": args.tail,
                        "audio": bool(args.audio),
                        "last_input_fp": last_input_fp,
                        "last_polled_at": now,
                        "last_broadcast_at": last_broadcast_at,
                        "last_broadcast_file": last_broadcast_file,
                        "broadcast_count": broadcast_count,
                    }
                )
            else:
                _write_state(
                    {
                        "running": True,
                        "pid": os.getpid(),
                        "requested_source": resolved["requested_source"],
                        "requested_state": resolved["requested_state"],
                        "source": resolved["source_name"],
                        "source_state": resolved["source_state"],
                        "source_size": resolved["source_size"],
                        "source_mtime": resolved["source_mtime"],
                        "fallback": resolved["fallback"],
                        "degraded_reason": resolved["degraded_reason"],
                        "provider": args.provider,
                        "model": args.model,
                        "interval": args.interval,
                        "tail": args.tail,
                        "audio": bool(args.audio),
                        "last_input_fp": last_input_fp,
                        "last_polled_at": now,
                        "last_broadcast_at": last_broadcast_at,
                        "last_broadcast_file": last_broadcast_file,
                        "broadcast_count": broadcast_count,
                    }
                )

            for _ in range(max(args.interval, 1) * 4):
                if not _running:
                    break
                time.sleep(0.25)
    finally:
        final_state = _read_state()
        final_state["running"] = False
        final_state["stopped_at"] = time.strftime("%Y-%m-%dT%H:%M:%S")
        _write_state(final_state)
        try:
            PID_PATH.unlink()
        except FileNotFoundError:
            pass

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
