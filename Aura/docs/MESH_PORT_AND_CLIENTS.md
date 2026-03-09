# Porting Tailscale network to Aura mesh and client availability

This doc describes how to **port your Tailscale network** to the Zig-based **Aura mesh** (aura-tailscale) and how a **client** is available for **this machine**, the **KVM VPS**, and your **Z Fold 5** phone.

## Current state

- **Aura mesh (aura-tailscale):** Zig reimplementation of a Tailscale-like mesh. WireGuard constants and BLAKE2s hash are in place; **WireGuard handshake, TUN device, and control-plane client are not yet implemented.** So today `aura mesh up` is a stub.
- **Tailscale today:** You have a Tailscale network (e.g. `fedora.tailafcdba.ts.net` in sovereign-stack). To move to our stack we either (1) run **Headscale** (self-hosted, Tailscale-compatible control plane) and keep using Tailscale/WireGuard clients until Aura mesh is ready, or (2) complete Aura mesh and then migrate.

## Port path: Tailscale → our stack

1. **Phase 1 (recommended now):** Run **Headscale** on your **KVM VPS**. Headscale speaks the Tailscale control protocol. Your existing **Tailscale clients** (this machine, VPS, Z Fold 5 with Tailscale app) can join the same Headscale network so you own the control plane and can later swap clients to Aura mesh.
2. **Phase 2:** When **aura-tailscale** has handshake + TUN + control client, build **aura-mesh** for Linux and run it on this machine and the KVM VPS, pointing `AURA_MESH_CONTROL_URL` (or config) at your Headscale or at an Aura coordination server. Then you have Zig clients on both Linux nodes.
3. **Phase 3:** For **Z Fold 5**, either (a) keep using the **Tailscale Android app** (it works with Headscale), or (b) use the **WireGuard Android app** with a config exported from Headscale (or from Aura coordinator when we support export). A native Aura mesh Android client (Zig/NDK or Kotlin) is a later option.

So: **port = run Headscale on VPS, point clients at it; then add aura-mesh Linux clients when ready; phone stays on Tailscale or WireGuard app.**

## Client availability matrix

| Device        | Role        | Client today                    | Client when Aura mesh is ready        |
|---------------|-------------|----------------------------------|---------------------------------------|
| **This machine** | Dev/Linux   | Tailscale CLI or Headscale client | **aura-mesh** (Zig binary): `aura mesh up` |
| **KVM VPS**      | Server      | Tailscale CLI or Headscale client | **aura-mesh** (Zig binary), same build |
| **Z Fold 5**     | Phone       | **Tailscale Android app** (works with Headscale) | **Tailscale app** (Headscale) or **WireGuard app** (exported config); native Aura app later |

All three can be on the **same network** once Headscale (or our coordinator) is the control plane.

## This machine: Aura mesh client

- **Build:** `cd aura-tailscale && zig build` (or from repo root: `aura mesh status` to trigger build).
- **Run:** `aura mesh up` / `aura mesh down` / `aura mesh status`.
- **Config:** Set `AURA_MESH_CONTROL_URL` (and optionally `AURA_MESH_AUTH_KEY`) to your Headscale or Aura coordinator URL when the client is implemented. Today these are prepared in `Config` in `root.zig`; the binary does not yet connect.

## KVM VPS: Aura mesh client

- **Build:** On this machine (or CI), build for Linux: `cd aura-tailscale && zig build -Dtarget=x86_64-linux-gnu` (or `aarch64-linux-gnu` for ARM VPS; omit `-Dtarget` if building on the VPS itself). Binary: `aura-tailscale/zig-out/bin/aura-mesh`.
- **Deploy:** Copy the binary to the VPS (e.g. via `bin/distribute-state.sh` and then copy `aura-tailscale/zig-out/bin/aura-mesh` to the VPS, or rsync/scp). Or build on the VPS after syncing the repo.
- **Run on VPS:** Same as this machine: run the binary with `up` / `down` / `status`; set `AURA_MESH_CONTROL_URL` (and auth if needed) when the client is implemented.
- **Headscale on VPS:** To port your Tailscale network, install and run Headscale on the KVM VPS so all clients (this machine, VPS, Z Fold 5) register there. Then Tailscale app on the phone and Tailscale/aura-mesh on the two Linux boxes can all use that control plane.

## Z Fold 5 (Android): client

- **Today:** Use the **Tailscale Android app**. In the app, sign in or use a pre-auth key from your **Headscale** (or Tailscale) network. Your Z Fold 5 will be on the same mesh as this machine and the VPS once Headscale is the coordinator.
- **Alternative:** When Headscale (or Aura) can export a **WireGuard config**, use the **WireGuard for Android** app and import that config. Then the phone uses plain WireGuard to the same mesh.
- **Later:** A dedicated Aura mesh Android client (e.g. Zig for Android or Kotlin using our protocol) can be added when the Zig stack is complete and we decide to ship an app.

## Checklist: port and clients

- [ ] **Headscale** (or Aura coordinator) running on KVM VPS and reachable.
- [ ] **This machine:** Tailscale or Headscale client joined; when ready, switch to `aura mesh up` with same control URL.
- [ ] **KVM VPS:** Tailscale or Headscale client joined; when ready, deploy and run **aura-mesh** binary with same control URL.
- [ ] **Z Fold 5:** Tailscale Android app joined to the same Headscale (or Tailscale) network; or WireGuard app with exported config.
- [ ] All three devices can reach each other on the mesh (e.g. ping or service access).

## Summary

Port your Tailscale network to the Zig-based solution by (1) running Headscale on the KVM VPS as the control plane, (2) ensuring a client on this machine (Tailscale now, aura-mesh when ready), (3) ensuring a client on the KVM VPS (same), and (4) ensuring a client on your Z Fold 5 (Tailscale Android app or WireGuard app). Aura mesh (aura-tailscale) becomes the Linux client on this machine and the VPS once handshake, TUN, and control client are implemented; the phone stays on Tailscale or WireGuard until we ship an Android client.
