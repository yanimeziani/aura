# Security

## Reporting a vulnerability

If you believe you have found a security vulnerability, please report it responsibly:

- **Do not** open a public GitHub issue.
- Email a description of the issue and steps to reproduce to **meziyani@gmail.com**.
- Allow a reasonable time for a fix before any public disclosure.

We will acknowledge receipt and work with you to understand and address the issue.

## Security practices in this repository

- **No secrets in the repo.** API keys, tokens, and credentials live in environment variables or the local vault (`vault/aura-vault.json`, which is gitignored). Use `.env.example` and `vault_manager.py` to see required keys.
- **Vault:** Never commit `vault/aura-vault.json` or any file containing real keys.
- **Subprojects** (e.g. `dragun-app`, `aura-landing-next`) may have their own `.env.example` and SECURITY notes; follow those when contributing or deploying.
