# Pegasus

Open-source mission control stack for **Cerberus** -- now managed as a single Pegasus repository.

Pegasus includes Android client, Kotlin web frontend, and API backend in one repo for simpler deployment and operations.

## Features

- **Dashboard** -- Real-time agent status, health indicators, cost burn rate, HITL badge counts
- **Agent Chat** -- Conversational interface with skill-based routing (General/Task/Code/Research)
- **Agent Stream** -- Live SSE log viewer with start/stop/clear controls
- **HITL Queue** -- Approve/reject agent actions with diff preview, risk labels, and blast radius
- **Cost Tracking** -- Per-agent spend vs caps, panic mode indicator, daily spend gauges
- **Panic Mode** -- One-tap emergency halt for all agents (cost threshold or manual trigger)
- **SSH Terminal** -- Direct shell access to VPS via SSHJ
- **Kotlin Web Console** -- JVM/Ktor web entrypoint for browser-based access
- **Bundled Backend** -- FastAPI control plane included under `backend/pegasus-api`
- **Settings** -- Configure Cerberus API URL, SSH host/port/user

## Architecture

- **Kotlin** + **Jetpack Compose** (adaptive Material 3 + motion)
- **Hilt** for dependency injection
- **Retrofit + OkHttp** for Cerberus API (`CerberusApi`)
- **SSHJ** for SSH terminal
- **DataStore** for session/token persistence
- **SSE streaming** for real-time agent output

## Stack

```
Pegasus Android + Pegasus Web --> Pegasus API (FastAPI) --> Cerberus Runtime (Zig)
```

| Component | Role |
|-----------|------|
| **Pegasus** | Unified control plane (Android + Kotlin Web + deployment assets) |
| **Cerberus Runtime** | Zig-based autonomous AI agent runtime (<1MB binary) |
| **Cerberus API** | REST/WebSocket bridge between Pegasus and the runtime |

## Build

```bash
# Debug build
./gradlew assembleDebug

# Release build (R8 optimized)
./gradlew assembleRelease

# Install on device
adb install app/build/outputs/apk/debug/app-debug.apk

# Kotlin web service
./gradlew :web:run
```

**Requirements:** JDK 17, Android SDK 36, Gradle 8.x

## Auth Flow

1. Pegasus hits `POST /auth/login` with username + password
2. Cerberus API returns a Bearer token
3. All subsequent API calls include `Authorization: Bearer <token>`
4. Tokens are persisted locally via DataStore

## API Endpoints

| Domain | Endpoints |
|--------|-----------|
| **Auth** | `POST /auth/login`, `/auth/logout`, `/auth/change-password` |
| **Health** | `GET /health` |
| **Agents** | `GET /agents`, `/agents/primary`, `POST /agents/{id}/start\|stop`, `GET /agents/{id}/stream` |
| **HITL** | `GET /hitl/queue`, `/hitl/{id}`, `POST /hitl/approve\|reject/{id}` |
| **Costs** | `GET /costs/status`, `/costs/today` |
| **Panic** | `GET /panic`, `POST /panic`, `DELETE /panic` |
| **Tasks** | `POST /tasks/submit`, `GET /tasks/queue/{agent_id}` |
| **Events** | `GET /events/replay`, `POST /events/ingest`, `WS /events/ws` |

## Configuration

Default API URL is set at build time via `BuildConfig.DEFAULT_API_URL`. Override in Settings screen or via the login screen's server URL field.

## Project Structure

```
pegasus/
  app/src/main/java/org/dragun/pegasus/
    data/
      api/          CerberusApi (Retrofit), AuthInterceptor, BaseUrlInterceptor
      repository/   AgentStreamRepository (SSE client)
      store/        SessionStore (DataStore persistence)
      shell/        PegasusShell (JNI native bridge + fallback)
      ssh/          SshClientWrapper (SSHJ)
    di/             AppModule (Hilt DI)
    domain/model/   Data classes (agents, HITL, costs, chat, panic)
    ui/
      screens/      Login, Dashboard, AgentChat, AgentStream, HITL, Costs, Settings, Terminal
      theme/        Adaptive Material 3 theme + motion tokens
      components/   Animated Material surface components
      NavHost.kt    Navigation graph
  web/              Kotlin JVM web service (Ktor)
  backend/
    pegasus-api/    FastAPI backend for Pegasus clients
  ops/
    deploy/         Docker Compose + VPS deploy scripts
    caddy/          Reverse proxy and TLS routing
```

## Deploy

1. Copy `.env.example` to `.env` in `ops/deploy/`
2. Set `PEGASUS_ADMIN_PASSWORD`
3. Run `ops/deploy/deploy_vps.sh` with `VPS_HOST` set
4. Point DNS:
   - `pegasus.meziani.org` -> VPS IP
   - `api.pegasus.meziani.org` -> VPS IP

## Production Checklist

- Rotate `PEGASUS_ADMIN_PASSWORD` in `ops/deploy/.env` (never keep defaults)
- Configure Android signing secrets in GitHub (see `RELEASE_APK.md`)
- Ensure `Android CI` passes (`lint` + `testDebugUnitTest`) before tagging
- Create signed release via tag (`v*`) using the `Android Release` workflow

## License

Apache-2.0
