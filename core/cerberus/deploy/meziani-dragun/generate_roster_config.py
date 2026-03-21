#!/usr/bin/env python3
"""Generate Cerberus roster config for Meziani + Dragun setup."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def read_prompt(path: Path) -> str:
    text = path.read_text(encoding="utf-8").strip()
    if not text:
        raise ValueError(f"Prompt file is empty: {path}")
    return text


def build_config(prompt_dir: Path, gateway_host: str, gateway_port: int, dragun_path: str, cerberus_path: str) -> dict:
    meziani_prompt = read_prompt(prompt_dir / "meziani-main.md")
    devsecops_prompt = read_prompt(prompt_dir / "dragun-devsecops.md")
    growth_prompt = read_prompt(prompt_dir / "dragun-growth.md")

    artifacts_path = f"{cerberus_path}/artifacts"
    config_path = f"{cerberus_path}/config"

    return {
        "default_temperature": 0.3,
        "models": {
            "providers": {
                # Claude Pro OAuth path via local `claude` CLI.
                "claude-cli": {}
            }
        },
        "agents": {
            "defaults": {
                "model": {
                    "primary": "claude-cli/claude-opus-4-6"
                }
            },
            "list": [
                {
                    "id": "meziani-main",
                    "provider": "claude-cli",
                    "model": "claude-opus-4-6",
                    "system_prompt": meziani_prompt,
                    "max_depth": 4
                },
                {
                    "id": "dragun-devsecops",
                    "provider": "claude-cli",
                    "model": "claude-sonnet-4-6",
                    "system_prompt": devsecops_prompt,
                    "max_depth": 5
                },
                {
                    "id": "dragun-growth",
                    "provider": "claude-cli",
                    "model": "claude-sonnet-4-6",
                    "system_prompt": growth_prompt,
                    "max_depth": 5
                }
            ]
        },
        "mcp_servers": {
            "github": {
                "command": "npx",
                "args": ["-y", "@modelcontextprotocol/server-github"],
                "env": {
                    "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"
                }
            },
            "filesystem": {
                "command": "npx",
                "args": [
                    "-y",
                    "@modelcontextprotocol/server-filesystem",
                    dragun_path,
                    artifacts_path,
                    config_path
                ]
            },
            "fetch": {
                "command": "npx",
                "args": ["-y", "@modelcontextprotocol/server-fetch"]
            },
            "memory": {
                "command": "npx",
                "args": ["-y", "@modelcontextprotocol/server-memory"],
                "env": {
                    "MEMORY_FILE_PATH": f"{artifacts_path}/agent-memory.json"
                }
            },
            "sequential-thinking": {
                "command": "npx",
                "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
            }
        },
        "autonomy": {
            "level": "supervised",
            "workspace_only": True,
            "max_actions_per_hour": 40,
            "require_approval_for_medium_risk": True,
            "block_high_risk_commands": True
        },
        "agent": {
            "compact_context": True,
            "max_tool_iterations": 300,
            "max_history_messages": 120,
            "parallel_tools": False,
            "tool_dispatcher": "auto",
            "session_idle_timeout_secs": 1800
        },
        "scheduler": {
            "enabled": True,
            "max_tasks": 128,
            "max_concurrent": 6
        },
        "cost": {
            "enabled": True,
            "daily_limit_usd": 8.0,
            "monthly_limit_usd": 240.0,
            "warn_at_percent": 80,
            "allow_override": False
        },
        "memory": {
            "backend": "sqlite",
            "auto_save": True
        },
        "gateway": {
            "port": gateway_port,
            "host": gateway_host,
            "require_pairing": True,
            "allow_public_bind": gateway_host in ("0.0.0.0", "::")
        },
        "runtime": {
            "kind": "native"
        },
        "security": {
            "sandbox": {"backend": "auto"},
            "audit": {"enabled": True, "retention_days": 90}
        },
        "channels": {
            "cli": True
        }
    }


def main() -> int:
    base_dir = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description="Generate Meziani + Dragun Cerberus roster config.")
    parser.add_argument("--output", default=str(base_dir / "config.roster.json"), help="Output config file path")
    parser.add_argument("--gateway-host", default="0.0.0.0", help="Gateway host bind address")
    parser.add_argument("--gateway-port", default=3000, type=int, help="Gateway port")
    parser.add_argument("--dragun-path", default="/data/dragun", help="Dragun workspace path")
    parser.add_argument("--cerberus-path", default="/data/cerberus", help="Cerberus data root")
    parser.add_argument("--prompt-dir", default=str(base_dir / "prompts"), help="Prompt directory")
    args = parser.parse_args()

    prompt_dir = Path(args.prompt_dir).resolve()
    output_path = Path(args.output).resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)

    cfg = build_config(
        prompt_dir=prompt_dir,
        gateway_host=args.gateway_host,
        gateway_port=args.gateway_port,
        dragun_path=args.dragun_path,
        cerberus_path=args.cerberus_path,
    )

    output_path.write_text(json.dumps(cfg, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
