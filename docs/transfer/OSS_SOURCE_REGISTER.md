# OSS Source Register

Status: Required for ULaval transfer  
Owner: Documentation Custodian  
Coverage target: 100% of external OSS components and borrowed source/material

## How to Use

- Create one row per external source (library, framework, code snippet, spec, or documentation source).
- If a source appears in multiple locations, keep one row and list all usage paths.
- For vendored code, include both upstream URL and local vendored path.
- Include transitive critical dependencies if they are redistributed or security-sensitive.

## Register Table

| ID | Source Name | Canonical URL | Version/Commit | License | Local Usage Paths | Modified Locally (Y/N) | Attribution Required | NOTICE Required (Y/N) | Security Notes | Last Verified |
|----|-------------|---------------|----------------|---------|-------------------|-------------------------|----------------------|-----------------------|----------------|---------------|
| OSS-001 | Next.js | https://github.com/vercel/next.js | TODO | MIT | `apps/aura-dashboard`, `apps/aura-landing-next`, `apps/web` | TODO | Yes | No | TODO | TODO |
| OSS-002 | React | https://github.com/facebook/react | TODO | MIT | `apps/aura-dashboard`, `apps/aura-landing-next`, `apps/web` | TODO | Yes | No | TODO | TODO |
| OSS-003 | FastAPI | https://github.com/fastapi/fastapi | TODO | MIT | `ops/gateway` | TODO | Yes | No | TODO | TODO |
| OSS-004 | Zig | https://github.com/ziglang/zig | TODO | MIT | `core/`, `tools/` | TODO | Yes | No | TODO | TODO |
| OSS-005 | SQLite | https://www.sqlite.org/ | TODO | Public Domain | `core/cerberus/runtime/cerberus-core/vendor/sqlite3`, `core/cerberus/vendor/nullclaw-upstream/vendor/sqlite3` | TODO | Yes | No | Check vendored updates | TODO |
| OSS-006 | nullclaw-upstream | TODO | TODO | TODO | `core/cerberus/vendor/nullclaw-upstream` | TODO | Yes | TODO | Verify upstream license files | TODO |
| OSS-007 | Nginx | https://nginx.org/ | TODO | BSD-2-Clause | `ops/` deployment and gateway stack docs/scripts | TODO | Yes | TODO | Confirm packaged distribution terms | TODO |
| OSS-008 | systemd | https://github.com/systemd/systemd | TODO | LGPL-2.1-or-later | `ops/` service definitions and deployment scripts | TODO | Yes | TODO | Confirm unit file derivations | TODO |

## Borrowed Documentation and Concept Sources

Use this section for non-code OSS or public references (protocols, standards, whitepapers, public docs).

| ID | Reference Title | URL | Usage Context | Citation Format | Last Verified |
|----|------------------|-----|---------------|-----------------|---------------|
| REF-001 | TODO | TODO | TODO | TODO | TODO |

## Validation Rules

- No `TODO` entries are allowed at transfer completion.
- Every entry must have a reachable canonical URL and explicit license.
- Every local usage path should map to at least one repository location.
- Security-sensitive components must include security notes and review date.

## Review Sign-off

- Prepared by: TODO
- Reviewed by (Engineering): TODO
- Reviewed by (Legal/Compliance): TODO
- Approved for transfer package: TODO
