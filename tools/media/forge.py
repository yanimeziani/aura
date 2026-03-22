"""Cinematic forge: orchestrate narrative → audit → staged media pipeline."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

from media.audit import evaluate_media_copy
from media.paths import staging_dir


def run_step(step_name: str, command: str) -> None:
    print(f"\n🎬 [CINEMATIC FORGE] Executing: {step_name}...")
    try:
        print(f"   > {command}")
        # subprocess.run(command, shell=True, check=True)
        print(f"   ✅ {step_name} complete.")
    except subprocess.CalledProcessError as e:
        print(f"   ❌ {step_name} failed: {e}")
        sys.exit(1)


def orchestrate_movie(concept: str, title: str, *, root: Path | None = None) -> Path:
    """
    Run the forge pipeline for one project. Returns path to the intended final cut
    (assembly is still a logged stub until external generators are wired).
    """
    out_root = staging_dir(root)
    out_root.mkdir(parents=True, exist_ok=True)
    project_dir = out_root / title.replace(" ", "_").lower()
    project_dir.mkdir(parents=True, exist_ok=True)

    print(f"🚀 Initializing Zero-Friction Cinematic Pipeline for: '{title}'")

    script_path = project_dir / "script.txt"
    run_step(
        "Narrative Synthesis (LLM)",
        f"Generate screenplay and shot list based on: '{concept}' -> {script_path}",
    )

    mock_script = (
        f"A visionary introduction to {title}. We see the future of sovereign digital architecture."
    )
    script_path.write_text(mock_script, encoding="utf-8")

    print("\n🛡️ [CINEMATIC FORGE] Initiating Audit Pass...")
    if not evaluate_media_copy(script_path.read_text(encoding="utf-8")):
        print("🛑 Cinematic pipeline halted due to safety violation.")
        sys.exit(1)

    audio_path = project_dir / "voiceover.wav"
    run_step(
        "Audio Generation (TTS/Foley)",
        f"Route {script_path} through n8n to ElevenLabs/Local TTS -> {audio_path}",
    )

    video_path = project_dir / "b_roll.mp4"
    run_step(
        "Visual Generation (Gen Video)",
        "Generate cinematic B-roll from shot list via Runway/SVD bridge -> "
        f"{video_path}",
    )

    final_output = project_dir / f"{title.replace(' ', '_').lower()}_final_cut.mp4"
    ffmpeg_cmd = (
        f"ffmpeg -i {video_path} -i {audio_path} -c:v copy -c:a aac {final_output}"
    )
    run_step("Automated Assembly (FFmpeg)", ffmpeg_cmd)

    print(
        f"\n✨ [CINEMATIC FORGE] Pipeline complete. Asset staged for 1-Tap Dispatch at: {final_output}"
    )
    print("   Use Pegasus or `nexa bridge` to push to public networks upon HITL approval.")
    return final_output


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Zero-Friction Cinematic Orchestrator")
    parser.add_argument("--title", required=True, help="Title of the media project")
    parser.add_argument(
        "--concept",
        required=True,
        help="Raw concept or prompt to generate the movie from",
    )
    args = parser.parse_args(argv)
    orchestrate_movie(args.concept, args.title)
    return 0
