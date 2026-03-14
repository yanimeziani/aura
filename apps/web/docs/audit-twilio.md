# Twilio implementation audit

**Scope:** SMS sending via Twilio in the dragun-app (comms layer, send-sms action, UI, config).  
**Last audit:** 2026-02-28.

---

## 1. Overview

| Area | Status | Notes |
|------|--------|--------|
| **Config & env** | ✅ Documented | `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_FROM`, `SMS_PROVIDER` |
| **Provider (send)** | ✅ Implemented | `lib/comms/providers/twilio.ts` — create message, error handling |
| **Comms dispatch** | ✅ Wired | `lib/comms/index.ts` uses `SMS_PROVIDER`; noop when Twilio not configured |
| **Send-SMS action** | ✅ Implemented | `app/actions/send-sms.ts` — debtor lookup, templates, recovery_actions + debtor update |
| **UI trigger** | ✅ Implemented | `DebtorActionForm` — initial / follow_up / reminder; no-phone warning |
| **Templates** | ✅ Implemented | `lib/comms/templates.ts` — initial, followUp, paymentReminder SMS |
| **Test API** | ✅ Implemented | `POST /api/comms/test` — Bearer/token auth, `{ channel: "sms", payload }` |
| **Status callback webhook** | ⚠️ Not implemented | Twilio delivery/status callbacks not consumed |
| **Phone normalization** | ⚠️ Missing | No E.164 normalization; raw `debtor.phone` sent to Twilio |
| **Rate limiting / idempotency** | ⚠️ Missing | No per-debtor or global SMS rate limit; no idempotency key |
| **Opt-out / compliance** | ⚠️ Not implemented | No STOP handling, no opt-out storage or Twilio webhook for replies |

---

## 2. Config & environment

- **Source:** `lib/comms/config.ts` → `getTwilioConfig()`.
- **Env vars:** `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_FROM`. All three required for `enabled: true`.
- **Provider selection:** `SMS_PROVIDER` (resend | twilio | noop). Default when unset is `noop`.
- **.env.example:** Documents Twilio block and `SMS_PROVIDER=noop`; no `TWILIO_STATUS_CALLBACK_URL` or similar.

**Recommendation:** Add optional `TWILIO_STATUS_CALLBACK_URL` (or derive from `NEXT_PUBLIC_URL`) when implementing the status webhook.

---

## 3. Provider implementation (`lib/comms/providers/twilio.ts`)

- **SDK:** `twilio` (^5.12.2).
- **Flow:** Validate body → load config → if !enabled return noop success → `twilio().messages.create({ to, body, from, statusCallback })`.
- **Success:** Returns `{ ok: true, channel: 'sms', provider: 'twilio', id: created.sid, raw }`.
- **Errors:** Caught; `code` / `message` / `status` read from error object when present; otherwise `TWILIO_REQUEST_FAILED`.
- **Body:** Rejects empty/whitespace body with `SMS_BODY_REQUIRED`.
- **Optional params:** `message.from` overrides config; `message.statusCallbackUrl` passed through (never set by send-sms today).

**Gaps:**
- `to` is not normalized to E.164 (Twilio expects E.164).
- No validation that `to` looks like a phone number before calling the API.

---

## 4. Send-SMS action (`app/actions/send-sms.ts`)

- **Auth:** `getMerchantId()`; 404 if no merchant.
- **Input:** `debtor_id`, `sms_type` (initial | follow_up | reminder).
- **Lookup:** Debtor by id + merchant_id; requires `debtor.phone`.
- **Templates:** `initialOutreachSms`, `followUpSms`, `paymentReminderSms` from `lib/comms/templates`.
- **Portal URL:** `buildDebtorPortalUrl(baseUrl, debtorId, 'chat')` for links in SMS.
- **Delivery:** `sendSms({ to: debtor.phone, body, metadata })` — no `statusCallbackUrl`.
- **Side effects:** Insert `recovery_actions` (action_type `sms_*`, note with phone); update debtor `last_contacted` and optionally `status` to `contacted` if pending.
- **Errors:** Sentry; returns `{ success: false, error: message }` to UI.

**Gaps:**
- Phone number used as stored; no E.164 normalization.
- No rate limit (e.g. max N SMS per debtor per day).
- No idempotency (double submit can send duplicate SMS).
- No opt-out check before sending.

---

## 5. UI (`components/dashboard/DebtorActionForm.tsx`)

- **Entry:** “Send SMS” in action menu; type selector: initial / follow_up / reminder.
- **Guard:** `hasPhone`; if no phone, SMS option shows `noPhoneWarning` (no phone on file).
- **Submit:** `sendSmsOutreach(formData)`; on failure, `alert(result.error)`.
- **Loading:** `isPending` with spinner on SMS button.

**OK:** Clear flow and warning when phone missing.

---

## 6. Templates (`lib/comms/templates.ts`)

- **initialOutreachSms:** First name, merchant, balance, “flexible options”, chat URL.
- **followUpSms:** First name, merchant, balance, “X days ago”, payment plans, chat URL.
- **paymentReminderSms:** First name, merchant, balance, Stripe checkout (chat URL).

All include a “legitimate” resolution portal link. No explicit STOP/HELP wording (TCPA/compliance often expects STOP instructions for marketing; debt collection may have different rules — legal review recommended).

---

## 7. Test API (`app/api/comms/test/route.ts`)

- **Auth:** `COMMS_TEST_TOKEN` via header `comms-test-token`, `x-comms-test-token`, or `Authorization: Bearer <token>`.
- **Body:** `{ channel: "email" | "sms", payload: {...} }`. For SMS, payload should match `SmsMessage` (to, body, from optional).
- **Response:** Full `CommsResult` (ok, provider, id or error); 200 on success, 502 on failure.
- **Security:** No token = 401; invalid JSON = 400.

**OK for manual/integration testing.** Ensure `COMMS_TEST_TOKEN` is set in env and not exposed to the client.

---

## 8. Gaps and recommendations

| Gap | Risk | Recommendation |
|-----|------|----------------|
| **No Twilio status callback webhook** | No delivery/failure or “undelivered” visibility in-app. | Add `POST /api/webhooks/twilio/status` (or similar). Validate Twilio request (signature/auth if available). Parse MessageStatus callback; store or log status per `MessageSid`. Optionally set `statusCallback` in provider when `TWILIO_STATUS_CALLBACK_URL` or base URL is set. |
| **No E.164 normalization** | Twilio may reject or misroute numbers; inconsistent behavior by region. | Normalize `to` (and stored `debtor.phone`) to E.164 before send (e.g. libphonenumber or similar). Validate format before calling Twilio. |
| **No rate limiting** | Risk of spam and Twilio/operator flags; cost. | Add per-debtor (and optionally per-merchant) rate limit (e.g. max SMS per debtor per 24h). Return clear error to UI. |
| **No idempotency** | Double-clicks or retries can send duplicate SMS. | Accept idempotency key (e.g. from UI); cache “already sent” for that key and return success without sending again. |
| **No opt-out handling** | Compliance (TCPA, etc.) and carrier expectations for STOP. | Store opt-outs (e.g. debtor or phone-level). Before send, check opt-out. Add Twilio webhook for incoming replies; on STOP/STOPALL etc., record opt-out and optionally respond with confirmation. |
| **No webhook signature verification (when added)** | Forged status callbacks. | When implementing status (or reply) webhook, use Twilio’s request validation (e.g. X-Twilio-Signature + auth token) and reject invalid requests. |

---

## 9. File reference

| File | Purpose |
|------|---------|
| `lib/comms/config.ts` | `getTwilioConfig()`, `getConfiguredSmsProvider()` |
| `lib/comms/providers/twilio.ts` | Twilio SMS provider implementation |
| `lib/comms/index.ts` | `sendSms()`, `resolveSmsProvider()` |
| `lib/comms/types.ts` | `SmsMessage`, `SmsProvider`, `CommsResult` |
| `lib/comms/templates.ts` | `initialOutreachSms`, `followUpSms`, `paymentReminderSms` |
| `app/actions/send-sms.ts` | Server action: send SMS + recovery_actions + debtor update |
| `app/api/comms/test/route.ts` | POST test endpoint for email/SMS |
| `components/dashboard/DebtorActionForm.tsx` | UI: SMS type + send, no-phone warning |
| `.env.example` | Twilio and SMS_PROVIDER comments |

---

## 10. Summary

- **Working:** Config, provider, comms dispatch, send-sms action, UI, templates, and test API are in place and consistent. When Twilio is configured, SMS sending and audit trail (recovery_actions + last_contacted) work.
- **To harden:** Add E.164 normalization, optional status callback webhook with validation, rate limiting, idempotency, and opt-out handling (storage + reply webhook) with legal review for compliance.
