-- Enable RLS on all tables
ALTER TABLE merchants ENABLE ROW LEVEL SECURITY;
ALTER TABLE contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE contract_embeddings ENABLE ROW LEVEL SECURITY;
ALTER TABLE debtors ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- 1. Merchants Table
-- Merchants can only see and edit their own profile
CREATE POLICY "Merchants can view own profile" ON merchants
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Merchants can update own profile" ON merchants
  FOR UPDATE USING (auth.uid() = id);

-- 2. Contracts Table
-- Merchants can manage their own contracts
CREATE POLICY "Merchants can manage own contracts" ON contracts
  FOR ALL USING (merchant_id = auth.uid());

-- 3. Contract Embeddings
-- Inherit access from contracts
CREATE POLICY "Merchants can manage own embeddings" ON contract_embeddings
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM contracts
      WHERE contracts.id = contract_embeddings.contract_id
      AND contracts.merchant_id = auth.uid()
    )
  );

-- 4. Debtors Table
-- Merchants can manage their debtors
CREATE POLICY "Merchants can manage own debtors" ON debtors
  FOR ALL USING (merchant_id = auth.uid());

-- 5. Conversations Table
-- Merchants can view conversations for their debtors
CREATE POLICY "Merchants can view conversations" ON conversations
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM debtors
      WHERE debtors.id = conversations.debtor_id
      AND debtors.merchant_id = auth.uid()
    )
  );
-- 6. Payments
-- Merchants can view payments
CREATE POLICY "Merchants can view payments" ON payments
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM debtors
      WHERE debtors.id = payments.debtor_id
      AND debtors.merchant_id = auth.uid()
    )
  );
