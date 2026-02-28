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

---

## Test route

With `COMMS_TEST_TOKEN` set in env, you can POST to `/api/comms/test` with header `comms-test-token: <value>` and a JSON body to trigger a test email/SMS (see `lib/comms/types.ts` for `CommsDispatchRequest`).
