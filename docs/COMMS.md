# Comms (Email & SMS)

Dragun uses **Resend** for email (outreach, follow-ups) and **Twilio** for SMS (optional). At least one channel should be configured for outreach to work.

## Quick: Enable email with Resend (recommended first)

1. **Sign up**: [resend.com](https://resend.com) → create account.
2. **Domain**: Add and verify your sending domain (e.g. `dragun.app` or a subdomain like `notify.dragun.app`) in the Resend dashboard. Resend will give you DNS records to add.
3. **API key**: Resend Dashboard → API Keys → Create. Copy the key (starts with `re_`).
4. **Env vars** (in `.env.local` or Vercel):
   ```bash
   EMAIL_PROVIDER=resend
   RESEND_API_KEY=re_xxxxxxxxxxxx
   RESEND_FROM=Account Resolution <resolution@yourdomain.com>
   ```
   Use the **exact** from address you verified (e.g. `noreply@yourdomain.com` or `resolution@notify.dragun.app`).
5. **Restart** the app. Outreach emails will send through Resend. If keys are missing, email runs in noop mode (logs only, no delivery).

### Optional: Webhooks (bounces/complaints)

In Resend Dashboard → Webhooks, add a URL:  
`https://your-domain.com/api/webhooks/resend`  
Set `RESEND_WEBHOOK_SECRET` to the signing secret Resend shows. The route will log bounces/complaints.

---

## SMS (Twilio) — when you’re ready

Set when you have a Twilio account and number:

```bash
SMS_PROVIDER=twilio
TWILIO_ACCOUNT_SID=AC...
TWILIO_AUTH_TOKEN=...
TWILIO_FROM=+1234567890
```

If these are not set, SMS defaults to **noop** (no delivery). No Twilio account is required to run the app.

### SMS status callbacks (delivery/failure)

The app accepts Twilio status callbacks at `POST /api/webhooks/twilio/status`. When `NEXT_PUBLIC_URL` is set (or `TWILIO_STATUS_CALLBACK_URL`), outbound SMS include this URL so delivery/failure status is recorded in recovery actions. No extra config needed if `NEXT_PUBLIC_URL` is set.

---

## Outreach etiquette (control variable)

To respect debtors’ complex lives and enforce a minimum of etiquette from businesses, outreach is governed by **`OUTREACH_ETIQUETTE_LEVEL`** (env). Rules apply **algorithmically** to all merchants.

| Level | Value | Min spacing | Max/week | Send window (UTC) | SMS weekend |
|-------|--------|-------------|----------|-------------------|-------------|
| **0** | `0` or `minimal` | — | — | — | — |
| **1** | `1` or `moderate` | 24 h | 5 | 07:00–21:00 | allowed |
| **2** | `2` or `strict` | 48 h | 3 | 08:00–20:00 | no (Sat/Sun) |
| **3** | `3` or `maximum` | 72 h | 2 | 09:00–19:00 | no (Sat/Sun) |

- **Spacing:** Minimum hours between *any* outreach (SMS or email) to the same debtor.
- **Max/week:** Rolling 7 days; counts all outreach action types (initial/follow-up/reminder, email and SMS).
- **Send window:** Outbound email/SMS only allowed within these UTC hours.
- **SMS weekend:** At strict/maximum, SMS is blocked on Saturday and Sunday UTC.

When a send is blocked, the UI receives the reason (e.g. “Please wait until …” or “Outreach limit reached”). Default is `0` (minimal) if unset. See `lib/outreach-etiquette.ts`.

---

## Test route

With `COMMS_TEST_TOKEN` set in env, you can POST to `/api/comms/test` with header `comms-test-token: <value>` and a JSON body to trigger a test email/SMS (see `lib/comms/types.ts` for `CommsDispatchRequest`).
