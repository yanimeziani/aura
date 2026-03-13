# Artifacts and clients for three sys configs

Final artifacts are built to `out/` for:

| Config | Target | Artifacts | Run |
|--------|--------|-----------|-----|
| **KDE** | This machine (Fedora KDE) | aura-tui, aura-mesh, aura-lynx | `aura tui`, `aura mesh up`, `aura lynx <url>` |
| **VPS** | KVM VPS | aura-api | `aura api` or `AURA_API_PORT=9000 ./aura-api` |
| **Mobile** | Z Fold 5 (Android) | aura-lynx (when built for aarch64-android) | Termux or native APK |

## Build all artifacts

```bash
bin/build-artifacts.sh
```

Outputs:

- `out/kde/` — aura-tui, aura-mesh, aura-lynx, aura-command-center.desktop
- `out/vps/` — aura-api
- `out/mobile/` — aura-lynx (Android binary when built with NDK)

## KDE (this machine)

- **aura-tui** — Zig terminal UI for daemon status, start/stop, vault, logs
- **aura-mesh** — Mesh VPN client (stub; handshake + TUN pending)
- **aura-lynx** — Zig text browser (Lynx-like); HTTP only; `aura lynx http://example.com`

Desktop integration: copy `out/kde/aura-command-center.desktop` to `~/.local/share/applications/`.

## VPS (aura-api)

Zig HTTP API server. Endpoints:

- `GET /health` — `{"status":"ok","service":"aura-api"}`
- `GET /status` — `{"mesh":"stub","gateway":"aura-gateway","vps":true}`

Deploy: copy `out/vps/aura-api` to VPS. Run with `AURA_API_PORT=9000 ./aura-api`.

## Mobile (Android)

- **aura-lynx** — Text browser for Z Fold 5. Build for Android: `cd aura-lynx && zig build mobile` (requires NDK). Or run `out/kde/aura-lynx` in Termux on the phone.
- **Tailscale/WireGuard app** — Until aura-mesh has Android client, use Tailscale or WireGuard app with Headscale.

## Summary

| Command | What |
|---------|------|
| `aura tui` | KDE terminal UI |
| `aura mesh up` | Mesh VPN client |
| `aura lynx <url>` | Zig text browser |
| `aura api` | VPS API server (run on VPS) |

All Zig components: no external deps except Zig + std.
