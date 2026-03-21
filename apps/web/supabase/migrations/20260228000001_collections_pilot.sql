-- Collections workflow (production pilot): debtor columns + recovery_actions
-- Ensures schema matches schema.sql for queue, statuses, and audit trail.

ALTER TABLE debtors ADD COLUMN IF NOT EXISTS days_overdue INT DEFAULT 0;
ALTER TABLE debtors ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

CREATE TABLE IF NOT EXISTS recovery_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  debtor_id UUID REFERENCES debtors(id) ON DELETE CASCADE,
  merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE,
  action_type TEXT NOT NULL DEFAULT 'status_update',
  status_after TEXT NOT NULL,
  note TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_recovery_actions_debtor_created ON recovery_actions(debtor_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_debtors_merchant_status ON debtors(merchant_id, status);
