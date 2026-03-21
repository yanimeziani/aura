-- Lock down prototype-era public access on debtor data.
-- Debtor portal now reads via server routes/components using service role.

DROP POLICY IF EXISTS "Public read access to debtors by ID" ON debtors;
DROP POLICY IF EXISTS "Public chat access" ON conversations;
