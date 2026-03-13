# KDE client artifacts (this machine)

- **aura-tui** — Zig terminal UI: `aura tui` or run `tui/zig-out/bin/aura-tui`
- **aura-mesh** — Mesh VPN client: `aura mesh up`
- **aura-lynx** — Text browser: `aura-lynx/zig-out/bin/aura-lynx <url>`

## Shell integration (recommended)

If `aura mesh status` ever behaves like `cd` (e.g. “cd: too many arguments”), you have an `alias aura='cd …'`.
Fix it once by sourcing the Aura zsh integration (it removes the alias and enables `aura cd` in-place):

```bash
source /home/yani/Aura/bin/aura.zsh
```

## Desktop integration

Copy `aura-command-center.desktop` to `~/.local/share/applications/`:

```bash
cp out/kde/aura-command-center.desktop ~/.local/share/applications/
```

Then launch "Aura Command Center" from the application menu.

## Autostart (optional)

To run aura-tui at KDE login:

```bash
mkdir -p ~/.config/autostart
cp out/kde/aura-command-center.desktop ~/.config/autostart/
```
