# Aura Sovereign Network Stack (Zig)

**Zig version:** We lock on **Zig 0.15.2**. All Zig docs in this repo are for 0.15.2. See [docs/ZIG_VERSION.md](ZIG_VERSION.md). From this baseline we branch out to the Ziggy language.

## Core Directive
We are abandoning high-level, bloated frameworks (like standard Next.js) and third-party protection layers (like Cloudflare). Aura must own the entire request lifecycle, from the lowest network byte up to the frontend render. 

This requires building a custom, high-performance web and network stack in **Zig (0.15.2)**.

## Architecture Layers

### 1. Layer 3/4: Sovereign DDoS Protection & Packet Filtering
*   **Goal:** Replace Cloudflare.
*   **Implementation:** eBPF/XDP (eXpress Data Path) programs managed by a Zig control plane.
*   **Function:** Drop malicious packets at the network card level before they ever hit the application stack. Implement custom rate-limiting, SYN flood protection, and geo-blocking tailored to our exact threat model.

### 2. Layer 4/6: Lower-Level Cryptography
*   **Goal:** Replace generic OpenSSL/BoringSSL dependencies with heavily audited, modern cryptography implementations in Zig.
*   **Implementation:** Utilize Zig's native `std.crypto` (which includes highly optimized Ed25519, ChaCha20-Poly1305, etc.) to handle TLS termination directly, entirely bypassing C-based legacy stacks. 
*   **Function:** True end-to-end memory-safe encryption. "Forget-Safe" implementation for passkeys and symmetric machine keys natively in the network layer.

### 2.5. Sovereign Mesh VPN (Aura Mesh / aura-tailscale)
*   **Goal:** Tailscale-like zero-config mesh VPN without Tailscale Inc dependency; device-to-device and edge-to-edge on our own stack.
*   **Implementation:** **aura-tailscale** — Zig reimplementation of the mesh experience: WireGuard protocol (Noise_IK, ChaCha20-Poly1305, X25519, BLAKE2s via `std.crypto`), TUN device, control-plane client (Headscale-compatible or Aura coordination), optional DERP-style relay.
*   **Function:** Secure private network between Aura nodes, edge, and devices; integrates with `aura-edge` and sovereign-stack. CLI: `aura mesh up | down | status`.

### 3. Layer 7: The "Zig Next.js" (Aura-Web)
*   **Goal:** A bespoke, ultra-fast SSR/SSG web framework.
*   **Implementation:** A Zig HTTP server utilizing `io_uring` or `epoll` for massive concurrency, coupled with a custom templating or JSX-like compilation engine.
*   **Function:** Serve `meziani.ai` and the `Aura TUI` backend with microsecond latency. Zero Node.js overhead. True bare-metal performance for commercial landing pages and complex dashboards.

## Implementation Roadmap
1.  **Phase 1 (Current):** Prototype the Zig TCP/HTTP listener (aura-edge).
2.  **Phase 2:** Implement TLS termination using `std.crypto`.
3.  **Phase 2.5:** Sovereign mesh (aura-tailscale): WireGuard handshake + transport, TUN, control client; `aura mesh` integrated in Aura CLI.
4.  **Phase 3:** Integrate XDP for dropping packets at line rate.
5.  **Phase 4:** Build the routing and templating logic (The "Zig Next.js").
6.  **Phase 5:** Swap Caddy out for the custom Aura Edge Router.
