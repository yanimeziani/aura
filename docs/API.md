# API Overview

Reference for Dragun.app API routes. All routes live under `/api/`. Rate limiting and bot protection are applied via Arcjet where configured.

## Public / Internal

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/health` | None | Health check. Returns `{ status, openrouter_configured }`. Uses DB ping; 503 if degraded. |

## Debtor portal (token or session)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/chat` | Debtor token (cookie or header) | AI chat with the recovery agent. Streams SSE; validates debtor and loads merchant context. |
| POST | `/api/stripe/checkout` | None (body: `debtorId`, `amount`, `currency`) | Creates Stripe Checkout session for debtor payment. Used by pay flow. |

## Merchant dashboard (session)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/conversations/[debtorId]` | Merchant session | Read-only conversation for a debtor (spectator view). Returns `{ messages }`. |
| GET | `/api/recovery/export` | Merchant session | CSV export of debtors. Query: optional `ids` (comma-separated). |
| GET | `/api/recovery/audit-export` | Merchant session | Export recovery audit data for the merchant. |

## Webhooks (provider-signed)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/stripe/webhook` | Stripe signature (`Stripe-Signature`) | Stripe events (checkout, Connect, etc.). Verify with `STRIPE_WEBHOOK_SECRET`. |
| POST | `/api/webhooks/resend` | Resend signature | Bounces/complaints. Optional; set `RESEND_WEBHOOK_SECRET`. |
| POST | `/api/webhooks/twilio/status` | Twilio (request origin) | SMS delivery/failure status callbacks. |

## Cron (server-to-server)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/cron/scheduled-follow-up` | `Authorization: Bearer <CRON_SECRET>` | Triggers scheduled follow-up emails for debtors past due. |
| GET | `/api/cron/data-retention` | `Authorization: Bearer <CRON_SECRET>` | Applies data retention rules (e.g. purge old data per merchant settings). |

## Auth & utilities

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/auth/callback` | OAuth/Supabase | Auth callback after sign-in. |

## Optional / dev

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/comms/test` | `Authorization: Bearer <COMMS_TEST_TOKEN>` | Send test email/SMS. Only enable with a secret token; do not expose to client. |

## Security notes

- **Merchant routes**: Use `getMerchantId()` (session). No merchant access without valid session.
- **Debtor chat**: Validates signed debtor token and ensures debtor belongs to a merchant.
- **Stripe webhook**: Always verify signature; never trust body without verification.
- **Cron**: Vercel Cron sets `CRON_SECRET`; use same secret when calling manually (e.g. from another scheduler).

## Related docs

- [COMMS.md](./COMMS.md) — Email (Resend) and SMS (Twilio) setup.
- [.env.example](../.env.example) — Required and optional environment variables.
