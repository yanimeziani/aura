-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Merchants Table
CREATE TABLE merchants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  country TEXT,
  currency_preference TEXT DEFAULT 'CAD',
  phone TEXT,
  strictness_level INT DEFAULT 5, -- 1-10 slider
  settlement_floor FLOAT DEFAULT 0.8, -- 80% default
  onboarding_step TEXT DEFAULT 'profile',
  onboarding_completed BOOLEAN DEFAULT FALSE,
  stripe_account_id TEXT,
  stripe_onboarding_complete BOOLEAN DEFAULT FALSE,
  onboarding_complete BOOLEAN DEFAULT FALSE,
  data_retention_days INT DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Contracts Table
CREATE TABLE contracts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE,
  file_name TEXT NOT NULL,
  file_path TEXT NOT NULL,
  raw_text TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Contract Embeddings (pgvector)
CREATE TABLE contract_embeddings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contract_id UUID REFERENCES contracts(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  embedding VECTOR(768), -- Gemini Text-Embedding-004 is 768 dims
  metadata JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Debtors Table
CREATE TABLE debtors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT,
  total_debt FLOAT NOT NULL,
  currency TEXT DEFAULT 'USD',
  status TEXT DEFAULT 'pending', -- pending, settled, disputed
  last_contacted TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Conversations Table
CREATE TABLE conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  debtor_id UUID REFERENCES debtors(id) ON DELETE CASCADE,
  role TEXT NOT NULL, -- 'user' or 'assistant'
  message TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Payments Table
CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  debtor_id UUID REFERENCES debtors(id) ON DELETE CASCADE,
  amount FLOAT NOT NULL,
  status TEXT NOT NULL, -- success, pending, failed
  stripe_session_id TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Collections workflow hardening (production pilot)
ALTER TABLE debtors ADD COLUMN IF NOT EXISTS days_overdue INT DEFAULT 0;
ALTER TABLE debtors ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

CREATE TABLE IF NOT EXISTS recovery_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  debtor_id UUID REFERENCES debtors(id) ON DELETE CASCADE,
  merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE,
  action_type TEXT NOT NULL DEFAULT 'status_update', -- call, sms, schedule, status_update
  status_after TEXT NOT NULL,
  note TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_recovery_actions_debtor_created ON recovery_actions(debtor_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_debtors_merchant_status ON debtors(merchant_id, status);

-- Function for vector search
CREATE OR REPLACE FUNCTION match_contract_embeddings(
  query_embedding VECTOR(768),
  match_threshold FLOAT,
  match_count INT,
  p_contract_id UUID
)
RETURNS TABLE (
  id UUID,
  content TEXT,
  similarity FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    ce.id,
    ce.content,
    1 - (ce.embedding <=> query_embedding) AS similarity
  FROM contract_embeddings ce
  WHERE ce.contract_id = p_contract_id
    AND 1 - (ce.embedding <=> query_embedding) > match_threshold
  ORDER BY similarity DESC
  LIMIT match_count;
END;
$$;
