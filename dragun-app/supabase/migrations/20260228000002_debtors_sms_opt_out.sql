-- SMS opt-out: allow debtors to opt out of SMS (compliance / carrier expectations)
ALTER TABLE debtors ADD COLUMN IF NOT EXISTS sms_opt_out BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN debtors.sms_opt_out IS 'When true, do not send SMS to this debtor (opt-out / STOP).';
