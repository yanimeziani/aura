# Aura Mesh (aura-tailscale) — Agent Guidelines

Tailscale-like mesh VPN reimplemented in Zig for the Aura sovereign stack. Same zero-config mesh experience; no Tailscale Inc dependency. Built on Zig `std.crypto` (WireGuard protocol: Noise_IK, ChaCha20-Poly1305, X25519, BLAKE2s).

## Integration with Aura

- **CLI:** `aura mesh` from repo root (see `bin/aura`).
- **Stack doc:** `docs/aura-zig-network-stack.md` — sovereign mesh is Layer 2.5.
- **Sibling Zig projects:** `aura-edge` (DDoS/edge), `tui` (terminal UI). **Zig locked to 0.15.2** (repo `.zig-version`, `docs/ZIG_VERSION.md`); same conventions.

## Commands

```bash
cd aura-tailscale && zig build        # build aura-mesh
zig build run -- up | down | status    # run daemon / commands
zig build test                        # tests
```

## Current state

- CLI: `aura-mesh up | down | status | help`.
- Library: `Config`, `Peer`, `MeshState`. **`src/wireguard.zig`** — WireGuard protocol constants (CONSTRUCTION, IDENTIFIER, KEY_SIZE, MAC_SIZE, LABEL_*), BLAKE2s-256 `hash`/`hashInto`/`hashConcat`, HMAC-BLAKE2s, HKDF2, `KeyPair.generate()` (X25519 + RFC 7748 clamping), `HandshakeState` (Noise_IK ck/h tracking, mixHash, mixKey), `initiationCreate()` (full Noise_IK initiation message per WireGuard spec §5.4.2, ChaCha20-Poly1305 AEAD, MAC1). `root.zig` re-exports.
- **TODO:** Responder-side handshake (response message + session key derivation), TUN device (Linux), control-plane client (Headscale-compatible or Aura coordination), DERP relay client.

## Control plane (env)

When the control client is implemented, set **`AURA_MESH_CONTROL_URL`** (e.g. your Headscale or Aura coordinator URL) and optionally **`AURA_MESH_AUTH_KEY`**. The CLI reads these in `up`; `Config` in `root.zig` holds defaults.

## Port and clients (this machine, KVM VPS, Z Fold 5)

See **docs/MESH_PORT_AND_CLIENTS.md** for porting your Tailscale network to Aura mesh and client availability on this machine, KVM VPS, and Z Fold 5 (Tailscale/Headscale or WireGuard app until our Android client exists).

## References

- WireGuard protocol: https://www.wireguard.com/protocol/
- Aura sovereign stack: `docs/aura-zig-network-stack.md`
