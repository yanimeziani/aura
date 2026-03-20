# THE VERSAILLES PROTOCOL
**Version 1.0 - Intellectual Property Transfer & Netsafe Mesh Federation**

## 1. PREAMBLE
The Versailles Protocol defines the exact cryptographic and routing mechanisms for transferring sovereign intellectual property (IP) from the Meziani AI Global Defense System (the Creator) directly to Université Laval (the Root Authority). 

It ensures that art, codebase contributions, and defensive intelligence are cryptographically signed at the hardware level before traversing a dedicated, "netsafe" feed.

## 2. THE HARDWARE ROOT OF TRUST
All IP to be transferred must first be signed by the Sovereign Creator Protocol (`aura-signer`) utilizing the physical SanDisk hardware key. This key holds the ML-KEM private identity.

*   **Step 1:** Asset Fingerprinting (SHA-256 via Zig).
*   **Step 2:** Hardware-gated ML-KEM Signature applied to the fingerprint.
*   **Step 3:** Asset bundled with the `MATCL-ULAVAL-GP` license.

## 3. NETSAFE MESH (FOCUS-FEED)
To prevent IP from crossing the open internet unprotected, the Versailles Protocol dictates a "focus-feed" architecture. 

A dedicated routing layer (the Netsafe Mesh) is established. This is a point-to-point Tailscale tunnel terminating directly at Université Laval's designated ingress node.
*   **Routing:** Traffic designated for IP transfer is isolated from general API traffic.
*   **Ingress:** `netsafe.ulaval.meziani.org`
*   **Encryption:** WireGuard-backed (via Tailscale) + ML-KEM post-quantum overlay.

## 4. TRANSFER EXECUTION
Execution is handled by the Quartermaster/Supervisor running `versailles_transfer.sh`.
Upon execution:
1. The asset is locked and signed.
2. The payload is encrypted for the ULAVAL public key.
3. The payload is transmitted exclusively through the Netsafe Mesh tunnel.
4. A permanent receipt is logged in the Mission Control dashboard.