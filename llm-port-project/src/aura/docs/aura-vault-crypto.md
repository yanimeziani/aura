# Aura Vault & Crypto: Layer 0 Redundant Storage & Cold Wallet

This document specifies the architecture for Aura's highly rigorous, Zig-native encrypted local cloud, integrated cold multi-crypto wallet, and autonomous budget management via Lightning Network.

## 1. Core Principles
- **Zig Layer 0 Rigor**: Implemented entirely in Zig `0.15.2` with zero external C dependencies. Relies exclusively on `std.crypto` for encryption, hashing, and key derivation.
- **Zero Trust Local Cloud**: Data is chunked, encrypted via ChaCha20-Poly1305, and replicated redundantly across the Aura mesh (`aura-tailscale`). No unencrypted bytes ever leave the host.
- **Air-Gapped Cold Wallet**: Cryptographic signing happens in an isolated, memory-safe execution environment. Private keys never touch the network layer.
- **Agentic Financial Control**: Budgeting and Lighting Network transfers are orchestrated by the `ai_agency_wealth` python system, acting as an automated CFO.

## 2. Component Architecture

### A. Aura Vault (Local Cloud Redundant Storage)
Implemented in `aura-vault/`.
- **Chunking & Indexing**: Files are broken into content-addressed chunks (BLAKE2s-256).
- **Encryption**: Each chunk is symmetrically encrypted using `ChaCha20-Poly1305`. The keys are managed by a local master key derived via Argon2.
- **Redundancy**: Chunks are gossiped across trusted nodes over the `aura-tailscale` mesh. Parity shards (Reed-Solomon) can be added for fault tolerance.

### B. Aura Cold Wallet (Multi-Crypto)
Integrated securely inside the `aura-vault` binary.
- **Key Generation**: BIP39 mnemonic generation using Zig `std.crypto.random` and PBKDF2/Argon2.
- **Signing Engines**: 
  - *Ed25519* (Solana, Stellar, Polkadot) natively supported via `std.crypto.sign.Ed25519`.
  - *Secp256k1* (Bitcoin, Ethereum) via strict, isolated Zig cryptographic routines.
- **Operation**: The wallet operates in an offline-first mode. Transactions are constructed externally (via `aura-flow` or `ai_agency_wealth`), passed to the cold wallet via a secure IPC or QR/TUI bridging, signed, and passed back. The wallet daemon itself lacks `std.net` imports.

### C. Budget Management & Lightning Network
Implemented in `ai_agency_wealth/` (Python/Agents).
- **LND / Core Lightning IPC**: The `ai_agency_wealth` subsystem runs a local Lightning node. Agents have access to macaroon-secured gRPC/REST APIs to generate invoices and execute instantaneous transfers.
- **Automated Budgeting**: SQLite-backed ledger syncing over the Aura mesh. Agents enforce strict spend limits (e.g., daily Lightning allowance for server costs, API usage).
- **Seamless Bridging**: If Lightning liquidity is low, agents can construct a Layer 1 transaction, send it to the Aura Cold Wallet for physical approval, and subsequently open new channels.

## 3. Implementation Phasing

1. **Phase 1: Cryptographic Primitives (Zig)**
   - Create `aura-vault` package.
   - Implement `ChaCha20-Poly1305` storage chunking.
   - Implement `Ed25519` seed derivation and basic wallet structures.
2. **Phase 2: Mesh Integration**
   - Bind `aura-vault` storage APIs to `aura-tailscale` UDP transport for replication.
3. **Phase 3: Lighting & Budgeting (Python)**
   - Add `lightning_manager.py` to `ai_agency_wealth/`.
   - Create LLM agent tools for querying balances, paying LN-URL invoices, and enforcing budget constraints.
