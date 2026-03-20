# PRD: Pegasus Aura Mobile Node
Version 1.0, March 2026

## 1. VISION
Pegasus is the sovereign mobile node for the Meziani AI Global Defense System. It replaces Termux with a hardened, Kotlin-native environment designed for secure coordination, high-fidelity monitoring, and seamless mesh integration on Android 16.

## 2. CORE COMPONENTS
### 2.1 Native Terminal (Sovereign Shell)
- **Engine:** Integrated PTY host for the Debian proot container.
- **Theming:** Full **Nord Theme** support (Polar Night, Snow Storm, Frost, Aurora).
- **Hardening:** Encrypted local session storage, biometric-locked access, and automated session sanitization on exit.

### 2.2 Dashboard & Widgets
- **Platform:** Jetpack Compose (Material 3).
- **Widgets:** Real-time mesh status (Tailscale), system health, Cerberus HITL (Human-in-the-Loop) approval queue.
- **Home Screen Widgets:** Quick-action panic button (vault lockdown), connection status, and active agent activity.

### 2.3 Local API & Mesh Integration
- **Server:** Embedded Ktor server for local device control and Cerberus communication.
- **Integration:** Native Tailscale SDK integration for secure mesh routing.
- **Hardware Support:** Direct access to connected backup devices (SanDisk Key, ID Badge) via Android USB Host API.

## 3. UI/UX: NORD DESIGN SPECIFICATION
- **Background:** `#2E3440` (Nord0)
- **Text:** `#D8DEE9` (Nord4)
- **Primary Accents:** `#88C0D0` (Nord8)
- **Success/Safety:** `#A3BE8C` (Nord14)
- **Critical/Warning:** `#BF616A` (Nord11)

## 4. SECURITY REQUIREMENTS
- **No Third-Party Dependencies:** Strictly vetted open-source libraries only.
- **Biometric Enforcement:** Mandatory fingerprint/face unlock for all vault-related actions.
- **Automated Sanitization:** Built-in execution of `defense-sanitize-android.sh` triggers on background/exit events.

## 5. MILESTONES
1. [ ] Project Scaffolding (Kotlin 2.0.2 / Compose).
2. [ ] PTY Shell Implementation & Proot Binding.
3. [ ] Nord Theme UI Framework.
4. [ ] Cerberus API & Mesh Status Widgets.
5. [ ] Biometric & Sanitization Lockdown.