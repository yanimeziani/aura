# OPERATE NOW

## Access
- Private ops URL: `https://fedora.tailafcdba.ts.net/`
- Local fallback URL: `http://127.0.0.1:5678`
- n8n basic user: `admin`
- n8n basic pass: `LLDQMveKbApBg5YORnQ1+ct4`

## 120-minute cash sprint

### Block 1 (0-15 min)
1. Open `https://fedora.tailafcdba.ts.net/` with Tailscale ON.
2. Create one workflow named `cashflow_fastlane`.
3. Add one Webhook trigger path: `ready`.

### Block 2 (15-30 min)
1. Add one `Set` node with fields:
   - `lead_name`
   - `lead_channel`
   - `lead_message`
   - `created_at`
2. Add one `Respond to Webhook` node returning:
   - `status: ok`
   - `message: received`

### Block 3 (30-60 min)
1. Create Google Sheet or Airtable table `leads`.
2. Add columns:
   - `name`
   - `channel`
   - `message`
   - `status`
   - `created_at`
3. Add n8n node to append rows into `leads`.

### Block 4 (60-90 min)
1. Create immediate auto-reply template:
   - `Perfect. Here is the fastest path: [CHECKOUT_LINK]. We start immediately after payment.`
2. Create +2h follow-up template:
   - `Quick bump — if this is priority this week, reply READY and I lock your slot.`
3. Create +24h close template:
   - `Final check-in: closing this cycle now. Reply READY for immediate start.`

### Block 5 (90-120 min)
1. Activate workflow.
2. Send DM wave 1 (40 contacts).
3. Use only one CTA keyword: `READY`.

## DM scripts (copy/paste)

### Opener
`I opened a few 72-hour build slots. Fast execution, no fluff. Reply READY.`

### When they reply READY
`Perfect. Start here: [CHECKOUT_LINK]. We begin immediately after payment.`

### Price objection
`Start with fast-track at $199 today. Upgrade later if needed: [CHECKOUT_LINK]`

### Hesitation
`I can hold your slot for 30 minutes.`

### Final push
`Final check-in: closing this cycle now. Reply READY if you want in.`

## Scoreboard
- `Sent`
- `Replies`
- `Paid`

Target this cycle:
- `80 Sent`
- `10 Replies`
- `2 Paid`

## Emergency calm protocol (60 seconds)
1. Drink water.
2. 4 breaths: inhale 4, hold 4, exhale 6.
3. Repeat: `One move. One close. One payment.`
