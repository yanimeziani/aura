#!/usr/bin/env python3
"""Aura MCP server — exposes mesh, status, and internal MCP registry to MCP clients (e.g. Cursor)."""

import asyncio
import json
import os
import subprocess
import sys

# Resolve Aura root (repo root)
_AURA_ROOT = os.environ.get(
    "AURA_ROOT",
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
)
_MCP_REGISTRY_PATH = os.path.join(_AURA_ROOT, "vault", "mcp_registry.json")

try:
    from mcp.server.fastmcp import FastMCP
except ImportError:
    print("Install MCP SDK: pip install mcp", file=sys.stderr)
    sys.exit(1)

mcp = FastMCP("aura", description="Aura sovereign stack: mesh VPN, status, edge.")


def _run_aura(*args: str) -> str:
    """Run bin/aura with given args; return stdout+stderr."""
    cmd = [os.path.join(_AURA_ROOT, "bin", "aura")] + list(args)
    try:
        r = subprocess.run(
            cmd,
            cwd=_AURA_ROOT,
            capture_output=True,
            text=True,
            timeout=30,
        )
        out = (r.stdout or "").strip()
        err = (r.stderr or "").strip()
        if r.returncode != 0 and err:
            return f"[exit {r.returncode}]\n{out}\n{err}".strip()
        return out or "(no output)"
    except subprocess.TimeoutExpired:
        return "Command timed out."
    except Exception as e:
        return f"Error: {e}"


@mcp.tool()
async def mesh_status() -> str:
    """Get Aura sovereign mesh VPN status (aura mesh status)."""
    return await asyncio.to_thread(_run_aura, "mesh", "status")


@mcp.tool()
async def mesh_up() -> str:
    """Bring Aura mesh VPN up (aura mesh up)."""
    return await asyncio.to_thread(_run_aura, "mesh", "up")


@mcp.tool()
async def mesh_down() -> str:
    """Bring Aura mesh VPN down (aura mesh down)."""
    return await asyncio.to_thread(_run_aura, "mesh", "down")


@mcp.tool()
async def aura_status() -> str:
    """Get Aura system status: services and health (aura status)."""
    return await asyncio.to_thread(_run_aura, "status")


@mcp.tool()
async def aura_help() -> str:
    """List Aura CLI commands and usage (aura help)."""
    return await asyncio.to_thread(_run_aura, "help")


@mcp.tool()
async def get_internal_mcp_registry() -> str:
    """Return the internal Aura MCP registry: the 10 recommended MCPs for our stack (dev, ops, auth). Use to configure Cursor or other clients; all plug into internal auth."""
    def _read() -> str:
        try:
            with open(_MCP_REGISTRY_PATH, "r", encoding="utf-8") as f:
                data = json.load(f)
            return json.dumps(data, indent=2)
        except FileNotFoundError:
            return json.dumps({"error": "vault/mcp_registry.json not found"})
        except json.JSONDecodeError as e:
            return json.dumps({"error": f"Invalid JSON: {e}"})

    return await asyncio.to_thread(_read)


def main() -> None:
    mcp.run(transport="stdio")


if __name__ == "__main__":
    main()
