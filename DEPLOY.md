# Deploy: Pegasus APK (GitHub) + Cerberus backend (VPS)

## 1. Pegasus APK → GitHub Releases

The workflow **Pegasus APK — GitHub Release** (`.github/workflows/pegasus-release.yml`) builds the Android app and attaches the APK to a GitHub Release.

### How to run

- **From a tag:** Push a tag `v*` or `pegasus-v*` (e.g. `v0.3.0` or `pegasus-v0.3.0`).
  ```bash
  git tag v0.3.0
  git push origin v0.3.0
  ```
- **Manual:** Actions → “Pegasus APK — GitHub Release” → “Run workflow”.

### Repo layout

The workflow expects the **Pegasus** app in a `pegasus/` directory at the repo root (monorepo). If your repo root is the Pegasus app itself, move the workflow into `pegasus/.github/workflows/` and remove the `working-directory: pegasus` and the `pegasus/` prefix in `files`.

### Result

A new GitHub Release is created for that tag with the APK attached (e.g. `pegasus-v0.3.0-arm64.apk`). Users can download it from the Releases page.

---

## 2. Cerberus backend → VPS

The workflow **Cerberus — Deploy to VPS** (`.github/workflows/cerberus-deploy-vps.yml`) compiles Cerberus (Zig), builds the roster config, and deploys the binary + pegasus-compat API to your Debian VPS.

### Required GitHub secrets

| Secret | Description |
|--------|-------------|
| `CERBERUS_SSH_HOST` | VPS hostname or IP (e.g. `89.116.170.202`) |
| `CERBERUS_SSH_KEY` | Private SSH key (full content, e.g. `-----BEGIN OPENSSH PRIVATE KEY-----` …) |

### Optional secrets

| Secret | Default | Description |
|--------|---------|-------------|
| `CERBERUS_SSH_USER` | `root` | SSH user |
| `CERBERUS_SSH_PORT` | `22` | SSH port |
| `PEGASUS_ADMIN_PASSWORD` | (script default) | Pegasus API admin password; set a strong value in production |
| `CERBERUS_ENABLE_CADDY` | `0` | Set to `1` to install Caddy reverse proxy for HTTPS |
| `CERBERUS_DOMAIN` | — | Domain for Caddy (e.g. `pegasus.meziani.org`) when `CERBERUS_ENABLE_CADDY=1` |
| `CERBERUS_ZIG_TARGET` | — | Zig target for cross-compile (e.g. `x86_64-linux-gnu` or `aarch64-linux-gnu`) when runner arch ≠ VPS arch |

To use password auth instead of a key, set `CERBERUS_SSH_PASSWORD` and ensure the runner has `sshpass` (you can add an “Install sshpass” step).

### How to run

- **Automatic:** Push to `main` that changes files under `cerberus/**`.
- **Manual:** Actions → “Cerberus — Deploy to VPS” → “Run workflow”.

### Cross-compilation (runner arch ≠ VPS arch)

If the GitHub runner is not the same architecture as the VPS (e.g. runner `aarch64`, VPS `x86_64`), set the secret **`CERBERUS_ZIG_TARGET`** to the VPS target, e.g. `x86_64-linux-gnu` or `aarch64-linux-gnu`. The workflow passes it to the deploy script so the binary is built for the VPS.

### What gets deployed

- Cerberus binary (`/usr/local/bin/cerberus`)
- Config at `/data/cerberus/.cerberus/config.json`
- pegasus-compat API (FastAPI) in a venv at `/data/cerberus/compat-venv`, served by systemd (`cerberus-pegasus-api`) on port **8080**
- Cerberus gateway systemd service (`cerberus-gateway`) on port **3000**

After deploy, open `http://YOUR_VPS_IP:8080/health` to confirm the Pegasus API. Use Caddy + domain if you want HTTPS.

---

## Quick reference

| Goal | Action |
|------|--------|
| Publish new Pegasus APK | Tag and push (e.g. `git tag v0.3.0 && git push origin v0.3.0`) or run “Pegasus APK — GitHub Release” manually |
| Deploy Cerberus to VPS | Push to `main` (with `cerberus/**` changes) or run “Cerberus — Deploy to VPS” manually after setting `CERBERUS_SSH_HOST` and `CERBERUS_SSH_KEY` |
