# End-to-end encrypted, ultra-secure comms only — OSS where possible

*Policy: no plaintext over the wire for sensitive content. Prefer open-source.*

---

## 1. Policy

- **Outbound (proposals, pitches):** Only send over E2E-secured or strongly encrypted channels. No cleartext proposal body on untrusted transport.
- **Internal (dashboard, API, nodes):** TLS only when not localhost; localhost treated as trusted transport.
- **Stack:** Prefer OSS (OpenPGP, Signal Protocol, Matrix, etc.). No closed crypto.

---

## 2. Current gaps

| Channel | Now | Issue |
|--------|-----|--------|
| **Eye / Sniper email** | SMTP (Gmail) + plaintext body | Provider and any middleman can read. Not E2E. |
| **Dashboard** | HTTP + WSS on localhost | Fine on loopback; if ever exposed, needs HTTPS/WSS. |
| **Stripe webhook** | HTTPS (Stripe → you) | Already TLS. Verify signature; no change. |

So the main change is **outbound email**: move to E2E (e.g. PGP) or to an E2E-first channel.

---

## 3. OSS options for E2E comms

### A. PGP for email (OSS, fits current pipeline)

- **What:** Encrypt proposal (and optional attachments) with recipient’s **public key** before sending. They decrypt with their private key. SMTP still carries the message, but body is ciphertext.
- **OSS:** **OpenPGP.js** (browser/Node) or **GPG** (cli) — both OpenPGP standard.
- **Flow:**  
  - Store recipient PGP public keys (paste, or fetch from keyserver).  
  - Eye/Sniper: before `sendMail()`, encrypt body with `openpgp.encrypt()` (or `gpg --encrypt`).  
  - Send email with encrypted body (and subject like “Encrypted proposal” to avoid leaking context).  
- **Limitation:** Recipient must have a public key. If they don’t, you either skip send (intervention) or use a fallback policy (e.g. “only PGP recipients”).

### B. Matrix / Element (OSS, E2E by default)

- **What:** Use Matrix (e.g. Element) for comms. E2E with Olm/Megolm; OSS.
- **Flow:** Post encrypted message to a room; invite client. No email body plaintext.
- **Fits:** If you’re okay moving some “proposal” delivery to Matrix instead of email. Bigger change than “add PGP to email.”

### C. Signal (E2E, protocol OSS)

- **What:** Send via Signal. E2E by design; Signal Protocol is OSS.
- **Flow:** Use Signal API / bot or manual send. Not SMTP; different pipeline.
- **Fits:** When you want Signal as the only channel for ultra-secure comms.

---

## 4. Recommended path (OSS, minimal change)

**Use PGP for all outbound proposal/pitch content (Eye + Sniper).**

1. **Dependencies (OSS):**
   - Node: `openpgp` (https://github.com/openpgpjs/openpgpjs) — OpenPGP.js.
2. **Config:**
   - Per-recipient or global: path or DB of PGP public keys (e.g. by email or job id).
   - Env: `E2E_REQUIRE_PGP=true` → only send if we have a public key for recipient; otherwise save to vault and flag “intervention: no PGP key.”
3. **Flow:**
   - Eye/Sniper: resolve recipient email → lookup public key → encrypt body with OpenPGP → send one MIME part (or inline PGP message). Subject: e.g. “Encrypted message from Meziani AI Labs” (no job title in subject).
   - If no key and `E2E_REQUIRE_PGP=true`: do **not** send plaintext; write to vault + `pending_manual_send` / “needs intervention”.
4. **Key handling:**
   - Keys: paste into a `keys/` dir (e.g. `keys/email@example.com.asc`) or keyserver lookup (OSS keyserver). No keys in .env; only paths or key IDs.

Result: **E2E encrypted, ultra-secure comms only** for the content that matters; **OSS** (OpenPGP); SMTP only carries ciphertext.

---

## 5. Dashboard / API

- **Localhost:** Keep HTTP/WSS for local use; treat as trusted.
- **If you ever expose dashboard:** Put it behind **HTTPS + WSS** (e.g. Caddy, nginx, or cloudflare tunnel). No plaintext dashboard traffic on the internet.
- **Secrets:** Never log or send .env, tokens, or keys. Already in .gitignore; keep it that way.

---

## 6. Summary

| Goal | Approach |
|------|----------|
| E2E encrypted comms only | PGP-encrypt all outbound proposal/pitch bodies; no plaintext. Require PGP when `E2E_REQUIRE_PGP=true`. |
| Ultra-secure | No cleartext on wire; optional “no send without key” policy. |
| OSS | OpenPGP (openpgp.js or GPG), Matrix, Signal Protocol — all OSS. Use OpenPGP for email path first. |

**Done in scratch:** Eye uses `encrypt-pgp.js` and `openpgp` (OSS). Set `E2E_REQUIRE_PGP=true` and `PGP_KEYS_DIR=./pgp-keys` in `.env`. Put recipient public keys in `pgp-keys/<email>.asc`. If no key, Eye does not send (vault + intervention). Run `npm install` in `upwork-scraper`. Sniper can reuse the same helper.