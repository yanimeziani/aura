# Security Policy

## Scope

Nexa is security-sensitive infrastructure. Treat vulnerability reporting seriously and avoid public disclosure of exploitable issues before maintainers have time to assess them.

## Report Security Issues

For sensitive issues, do not open a public issue first.

Use:

- GitHub security advisories, if enabled
- private maintainer contact through the project support channels

Include:

- affected component
- impact
- reproduction steps
- proposed mitigation, if known

## Public tree hygiene (hermetic baseline)

- Do not commit **third-party logos**, **unlicensed marks**, or **scraped domain lists**. Register domains only through normal registrar flows; keep availability research outside git if it touches third-party sites’ terms of service.
- Optional vendor integrations (e.g. under `core/google-mcp/`) may retain upstream-required names in **vendor-shipped manifests**; canonical **Nexa docs and marketing** should stay neutral unless a filing legally requires a proper noun.

## Priority Areas

- auth and vault handling
- HITL bypasses
- trust-tier escalation and revocation bugs
- transport security issues
- state recovery or session leakage
- path traversal, arbitrary file access, or remote execution bugs
