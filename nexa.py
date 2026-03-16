#!/usr/bin/env python3
"""
Nexa CLI — cross-platform, plug-and-play. Works on Linux, macOS, Windows.
Usage: python nexa.py <command> [options]
"""
from __future__ import annotations

import os
import platform
import subprocess
import sys
from pathlib import Path

from nexa_runtime import nexa_root


def _root() -> Path:
    return nexa_root(Path(__file__).resolve().parent)


def _python() -> str:
    return sys.executable


def _run(cmd: list, env: dict | None = None, cwd: Path | None = None) -> int:
    env = {**os.environ, **(env or {})}
    return subprocess.run(cmd, env=env, cwd=cwd or _root(), shell=False).returncode


def _run_bash(script: Path, *args, env_extra: dict | None = None) -> int:
    env = {
        **os.environ,
        "NEXA_ROOT": str(_root()),
        "REPO_ROOT": str(_root()),
        **(env_extra or {}),
    }
    bash = "bash" if platform.system() != "Windows" else _find_bash_windows()
    if not bash:
        print("On Windows, install Git Bash and ensure 'bash' is on PATH, or run from WSL.", file=sys.stderr)
        return 1
    cmd = [bash, str(script)] + list(args)
    return subprocess.run(cmd, env=env, cwd=str(_root())).returncode


def _find_bash_windows() -> str | None:
    for name in ("bash", "bash.exe"):
        try:
            r = subprocess.run([name, "-c", "echo ok"], capture_output=True, timeout=2)
            if r.returncode == 0:
                return name
        except (FileNotFoundError, subprocess.TimeoutExpired):
            continue
    return None


def cmd_help() -> None:
    print("Nexa CLI — cross-platform (Linux, macOS, Windows)")
    print("Usage: python nexa.py <command> [options]")
    print("")
    print("Automation (plug-and-play):")
    print("  deploy-mesh   Deploy in-house Zig gateway surface to VPS")
    print("  backup        Backup dynamic logs/json/md")
    print("  docs-bundle   Build NotebookLM-safe doc bundle")
    print("  publish-notebooklm  Build + manifest + publish NotebookLM source bundle")
    print("  notebooklm-upload   Optional Playwright upload into NotebookLM UI")
    print("  smoke-test    Smoke-test deployed mesh")
    print("  demo          Instant demo: in-house Zig gateway locally")
    print("  autopilot     Run the unified automation control loop")
    print("")
    print("Commands:")
    print("  gateway     Start syncing gateway (port 8765)")
    print("  vault       Manage API keys and secrets")
    print("  status      System health")
    print("  help        This message")
    print("")
    print("Requires: Python 3.8+ for CLI helpers. Runtime surface is Zig + embedded assets.")
    print("NEXA_ROOT defaults to repo root (this directory).")


def cmd_gateway(root: Path) -> int:
    port = os.environ.get("NEXA_GATEWAY_PORT", "9080")
    gateway_dir = root / "core" / "nexa-gateway"
    build_rc = _run(["zig", "build"], cwd=gateway_dir)
    if build_rc != 0:
        return build_rc
    env = {**os.environ, "NEXA_GATEWAY_PORT": port}
    return subprocess.run([str(gateway_dir / "zig-out" / "bin" / "nexa-gateway")], env=env, cwd=str(gateway_dir)).returncode


def cmd_demo(root: Path) -> int:
    port = os.environ.get("NEXA_GATEWAY_PORT", "9080")
    url = f"http://127.0.0.1:{port}"
    gateway_dir = root / "core" / "nexa-gateway"
    build_rc = _run(["zig", "build"], cwd=gateway_dir)
    if build_rc != 0:
        return build_rc

    gateway_proc = subprocess.Popen(
        [str(gateway_dir / "zig-out" / "bin" / "nexa-gateway")],
        env={**os.environ, "NEXA_GATEWAY_PORT": port},
        cwd=str(gateway_dir),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=(platform.system() != "Windows"),
    )
    print("In-house Zig gateway starting in background...")
    import time
    for _ in range(20):
        time.sleep(0.5)
        try:
            import urllib.request

            with urllib.request.urlopen(f"{url}/api/health", timeout=1) as r:
                if r.status == 200:
                    break
        except Exception:
            continue
    else:
        print("Gateway may still be starting. Check manually:", url + "/api/health")
    print("Nexa Gateway:", url)
    print("Mission Control:", url + "/")
    print("Demo ready. Press Ctrl+C to stop.")
    try:
        gateway_proc.wait()
    except KeyboardInterrupt:
        gateway_proc.terminate()
    return 0


def cmd_vault(root: Path) -> int:
    return _run(
        [_python(), str(root / "core" / "vault" / "vault_manager.py")] + sys.argv[2:],
        env={**os.environ, "NEXA_ROOT": str(root)},
    )


def cmd_docs_bundle(root: Path) -> int:
    env = {**os.environ, "NEXA_ROOT": str(root), "REPO_ROOT": str(root)}
    return _run([_python(), str(root / "ops" / "scripts" / "build-nexa-docs-bundle.py")], env=env)


def cmd_backup(root: Path) -> int:
    script = root / "ops" / "scripts" / "backup-dynamic-then-delete.sh"
    if not script.exists():
        print("Backup script not found. Run from repo root.", file=sys.stderr)
        return 1
    return _run_bash(script, *sys.argv[2:], env_extra={"NEXA_ROOT": str(root)})


def cmd_publish_notebooklm(root: Path) -> int:
    script = root / "ops" / "scripts" / "publish-notebooklm-bundle.sh"
    if not script.exists():
        print("publish-notebooklm-bundle.sh not found.", file=sys.stderr)
        return 1
    return _run_bash(script, env_extra={"NEXA_ROOT": str(root), "REPO_ROOT": str(root)})


def cmd_notebooklm_upload(root: Path) -> int:
    script = root / "ops" / "scripts" / "notebooklm-upload.mjs"
    if not script.exists():
        print("notebooklm-upload.mjs not found.", file=sys.stderr)
        return 1
    return _run(["node", str(script)], cwd=root)


def cmd_deploy_mesh(root: Path) -> int:
    script = root / "ops" / "scripts" / "deploy-mesh.sh"
    if not script.exists():
        print("deploy-mesh.sh not found.", file=sys.stderr)
        return 1
    return _run_bash(script, env_extra={"REPO_ROOT": str(root)})


def cmd_smoke_test(root: Path) -> int:
    script = root / "ops" / "scripts" / "smoke-test-mesh.sh"
    if not script.exists():
        print("smoke-test-mesh.sh not found.", file=sys.stderr)
        return 1
    mesh_vps_ip = os.environ.get("VPS_IP", "").strip()
    if not mesh_vps_ip:
        print("Set VPS_IP before running smoke-test.", file=sys.stderr)
        return 1
    env_extra = {
        "REPO_ROOT": str(root),
        "MESH_VPS_IP": mesh_vps_ip,
    }
    if os.environ.get("MESH_LANDING_URL"):
        env_extra["MESH_LANDING_URL"] = os.environ["MESH_LANDING_URL"]
    return _run_bash(script, env_extra=env_extra)


def cmd_status(root: Path) -> int:
    print("Nexa root:", root)
    print("Platform:", platform.system(), platform.release())
    port = os.environ.get("NEXA_GATEWAY_PORT", "9080")
    url = f"http://127.0.0.1:{port}/api/health"
    try:
        import urllib.request

        with urllib.request.urlopen(url, timeout=2) as r:
            print("Gateway:", r.read().decode().strip())
    except Exception as e:
        print("Gateway: not reachable at", url, "-", e)
    return 0


def cmd_autopilot(root: Path) -> int:
    subcmd = sys.argv[2] if len(sys.argv) > 2 else "status"
    extra = sys.argv[3:] if len(sys.argv) > 3 else []
    return _run([_python(), str(root / "ops" / "autopilot" / "nexa_autopilot.py"), subcmd] + extra, cwd=root)


def main() -> int:
    root = _root()
    os.environ["NEXA_ROOT"] = str(root)

    cmd = (sys.argv[1:] or ["help"])[0].lower()

    if cmd in ("help", "-h", "--help"):
        cmd_help()
        return 0
    if cmd == "deploy-mesh":
        return cmd_deploy_mesh(root)
    if cmd == "backup":
        return cmd_backup(root)
    if cmd == "publish-notebooklm":
        return cmd_publish_notebooklm(root)
    if cmd == "notebooklm-upload":
        return cmd_notebooklm_upload(root)
    if cmd == "docs-bundle":
        return cmd_docs_bundle(root)
    if cmd == "smoke-test":
        return cmd_smoke_test(root)
    if cmd == "demo":
        return cmd_demo(root)
    if cmd == "gateway":
        return cmd_gateway(root)
    if cmd == "vault":
        return cmd_vault(root)
    if cmd == "status":
        cmd_status(root)
        return 0
    if cmd == "autopilot":
        return cmd_autopilot(root)

    bash_nexa = root / "ops" / "bin" / "nexa"
    bash = "bash" if platform.system() != "Windows" else _find_bash_windows()
    if bash_nexa.exists() and bash:
        return subprocess.run(
            [bash, str(bash_nexa)] + sys.argv[1:],
            env={**os.environ, "NEXA_ROOT": str(root)},
            cwd=str(root),
        ).returncode
    print("Unknown command:", cmd)
    cmd_help()
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
