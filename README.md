# Pegasus

Android control plane for **OpenClaw / dragun.app** — manage your Debian VPS, agents, HITL queue, costs, and SSH terminal from your Samsung Z Fold 5.

## Features (Alpha)

- **Login** — Token-based auth against OpenClaw API (`ops.meziani.org`)
- **Dashboard** — Agent status, health, cost bars, HITL badge count
- **HITL Queue** — Approve/reject agent actions with diff preview and risk labels
- **Cost Tracking** — Per-agent spend vs caps, panic mode indicator
- **SSH Terminal** — Direct shell access to VPS via SSHJ
- **Settings** — Configure API URL, SSH host/port/user

## Architecture

- **Kotlin** + **Jetpack Compose** (Material 3)
- **Hilt** for dependency injection
- **Retrofit + OkHttp** for OpenClaw API
- **SSHJ** for SSH terminal
- **DataStore** for session/token persistence

## Build

```bash
# From Android Studio or command line with Android SDK
./gradlew assembleDebug

# Install on device
adb install app/build/outputs/apk/debug/app-debug.apk
```

## Auth Flow

1. Pegasus hits `POST /auth/login` with username + password
2. OpenClaw returns a Bearer token (`oc_...`)
3. All subsequent API calls include `Authorization: Bearer <token>`
4. Internal agent traffic (Docker network) bypasses auth
5. Caddy routes Bearer-auth requests directly to FastAPI (no basic_auth)

## Default Credentials

| Field | Value |
|-------|-------|
| Username | `yani` |
| Password | `openclaw2026` |
| API URL | `https://pegasus.meziani.org` |

**Change the password after first login** via the API or orchestrator env var.

## License

Private — dragun.app
