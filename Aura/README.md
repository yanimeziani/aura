# Aura

Autonomous multi-agent command center and sovereign stack (Zig edge/mesh/MCP, Python gateway & agents, React frontend, Docker infra).

**Onboard in one place:** **[docs/ONBOARDING.md](docs/ONBOARDING.md)** — setup, modes (build mode, dirty hands), daily commands (`aura` CLI), logs, gateway, and chat.

## License and distribution

This project is open source under the [MIT License](LICENSE). When distributing or deploying:

- **No secrets in the repo.** API keys and credentials go in environment variables or the local vault (`vault/aura-vault.json`, gitignored). Use `vault/vault_manager.py` and each subproject’s `.env.example` to see required configuration.
- **Optional:** Set `AURA_HOME` to the repo root (or install path) if scripts are run from a different working directory; vault scripts default to the directory containing the script.
- See [SECURITY.md](SECURITY.md) for vulnerability reporting and [CONTRIBUTING.md](CONTRIBUTING.md) for how to contribute.
