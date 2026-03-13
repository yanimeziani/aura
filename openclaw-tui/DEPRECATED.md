# openclaw-tui [DEPRECATED]

> **This project has been superseded by Pegasus.**
>
> Pegasus is the native Android mission control app for Cerberus, replacing the
> need for a Termux-based TUI. It provides all the same functionality with a
> Material 3 touch-optimized UI:
>
> - Dashboard with real-time agent status
> - HITL approval queue with diff preview and risk labels
> - Cost tracking with per-agent gauges
> - Panic mode control
> - SSH terminal access
> - Agent chat and streaming
>
> **Install Pegasus:** Download the latest APK from GitHub Releases or build from `/pegasus/`.

## Feature Mapping

| openclaw-tui Feature | Pegasus Equivalent |
|---------------------|-------------------|
| Dashboard tab | Dashboard screen (auto-refresh) |
| HITL tab (j/k/y/n) | HITL screen (tap to expand, approve/reject buttons) |
| Logs tab | Agent Stream screen (SSE real-time) |
| Costs tab | Costs screen (per-agent progress bars) |
| Help tab | In-app navigation |
| SSH via config | SSH Terminal screen + Settings |
| `openclaw panic on/off` | Panic toggle button on Dashboard |

## If You Still Need a TUI

The Cerberus CLI (`cerberus`) provides terminal-based agent management:

```bash
cerberus status      # Agent status
cerberus doctor      # Health diagnostics
cerberus --cli       # Interactive CLI mode
```
