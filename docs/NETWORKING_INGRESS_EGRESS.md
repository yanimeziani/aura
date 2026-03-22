# NETWORKING: INGRESS AND EGRESS MAP
**Domain:** Meziani AI Digital Studio (Digital Real Estate)
**Protocol:** Aura Mesh Protocol

This document maps the flow of data into (Ingress) and out of (Egress) the Aura Mesh environment.

## 1. PUBLIC INGRESS (Global Edge)
Public traffic enters via the Hostinger VPS which acts as the sovereign gateway.

| Endpoint | Protocol | Handling | Target |
| :--- | :--- | :--- | :--- |
| `meziani.ai` | HTTPS (443) | Caddy (SSL Term) | Tailscale Tunnel (Local Nginx) |
| `meziani.org` | HTTPS (443) | Caddy (SSL Term) | Tailscale Tunnel (Local Nginx) |
| `nexa.meziani.ai`| HTTPS (443) | Caddy (SSL Term) | Tailscale Tunnel (Local Nginx) |

**Transport:** All public ingress is proxied through a **Tailscale encrypted tunnel** to the local Aura node (`100.108.118.34`).

## 2. LOCAL INGRESS (Internal Routing)
The local machine runs Nginx to route traffic to specific agentic and platform services.

| Location | Port | Target Service | Purpose |
| :--- | :--- | :--- | :--- |
| `/gw/` | 8765 | `aura_gateway` | Core Mesh API & WebSockets |
| `/dashboard` | 3003 | `nexa_web_interface` | Operator Management UI |
| `/api/` | 8080 | `pegasus_api` | Mobile Mission Control API |
| `/gateway/` | 3000 | `cerberus_gateway` | Zig Agent Runtime Controller |
| `/launch/` | Static | Nginx Alias | Digital Studio Launch Assets |

## 3. SOVEREIGN TRANSPORT INGRESS
For high-resilience and privacy-first operations, the mesh supports decentralized ingress points.

*   **Tor Onion Services:** (Optional) Ingress via `.onion` addresses routed to local services.
*   **IPFS Gateway:** `http://127.0.0.1:8080` for content-addressed data retrieval.

## 4. OUTBOUND EGRESS (Agent Activity)
Egress is strictly monitored and gated to prevent data exfiltration and unauthorized activity.

### 4.1 Aura Edge Monitor
The `EgressMonitor` (`core/aura-edge/src/egress.zig`) tracks:
*   Bytes sent per host.
*   Requests per second per host.
*   Threshold-based alerts for anomalous behavior.

### 4.2 Security Policy Gates
Agents are restricted by `SecurityPolicy` (`core/cerberus/runtime/cerberus-core/src/security/policy.zig`):
*   **Command Blocklist:** `curl`, `wget`, `nc`, `ssh`, `ftp` are blocked by default for autonomous agents.
*   **Approval Required:** Any tool call involving external HTTP requests requires HITL approval in `supervised` mode.
*   **Domain Allowlist:** (Coming Soon) Restricting agents to specific trusted domains (e.g., `api.resend.com`, `api.stripe.com`).

### 4.3 Privacy Transport (Egress Routing)
High-risk egress can be routed through privacy-preserving layers:
*   `AURA_ROUTE_CLOUD_THROUGH_TOR=1`: Proxies all external cloud provider calls through the Tor SOCKS5 proxy (`127.0.0.1:9050`).

---
**Audit Note:** Every ingress request and egress attempt is logged to the `vault/audit.jsonl` for compliance and forensic analysis.
