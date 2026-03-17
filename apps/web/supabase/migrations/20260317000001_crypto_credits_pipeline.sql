-- Crypto credits system: wallets, credit ledger, LLM usage metering, market signals
-- Supports: Coinbase Commerce (hosted) + local self-custody wallets (USDC/BTC/ETH)

-- Wallets: each user can have deposit addresses per chain
CREATE TABLE IF NOT EXISTS wallets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id UUID NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
  chain TEXT NOT NULL CHECK (chain IN ('eth', 'btc', 'usdc')),
  address TEXT NOT NULL,
  address_type TEXT NOT NULL DEFAULT 'deposit' CHECK (address_type IN ('deposit', 'withdrawal')),
  label TEXT,
  verified BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (merchant_id, chain, address)
);

-- Credit ledger: every deposit, burn, refund is an immutable row
CREATE TABLE IF NOT EXISTS credit_ledger (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id UUID NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
  entry_type TEXT NOT NULL CHECK (entry_type IN ('deposit', 'burn', 'refund', 'bonus')),
  amount_usd NUMERIC(14,6) NOT NULL,         -- normalised to USD value at time of entry
  token TEXT NOT NULL CHECK (token IN ('usdc', 'btc', 'eth', 'fiat')),
  token_amount NUMERIC(20,8) NOT NULL,        -- raw token amount (e.g. 0.015 ETH)
  tx_hash TEXT,                               -- on-chain tx or coinbase charge id
  source TEXT NOT NULL CHECK (source IN ('coinbase', 'onchain', 'stripe', 'system')),
  description TEXT,
  balance_after NUMERIC(14,6) NOT NULL,       -- running balance snapshot
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- LLM usage log: every completion call is metered
CREATE TABLE IF NOT EXISTS usage_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id UUID NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
  model TEXT NOT NULL,
  tokens_in INTEGER NOT NULL DEFAULT 0,
  tokens_out INTEGER NOT NULL DEFAULT 0,
  cost_usd NUMERIC(10,6) NOT NULL DEFAULT 0,  -- computed cost
  endpoint TEXT,                               -- which gateway route
  latency_ms INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Market signals: derived data products from scraping + sentiment
CREATE TABLE IF NOT EXISTS market_signals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source TEXT NOT NULL,                        -- 'twitter', 'reddit', 'news', 'onchain'
  asset TEXT,                                  -- 'BTC', 'ETH', 'USDC', or sector tag
  signal_type TEXT NOT NULL CHECK (signal_type IN ('sentiment', 'volume', 'momentum', 'alert', 'aggregate')),
  score NUMERIC(5,3),                          -- normalised -1.0 to 1.0 for sentiment
  magnitude NUMERIC(10,2),                     -- raw magnitude (volume, count, etc.)
  payload JSONB NOT NULL DEFAULT '{}',         -- full signal data
  mesh_stream_id TEXT,                         -- ties to mesh data stream derivée
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Crypto charges: Coinbase Commerce charge tracking
CREATE TABLE IF NOT EXISTS crypto_charges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id UUID NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
  coinbase_charge_id TEXT UNIQUE,              -- from Coinbase Commerce API
  amount_usd NUMERIC(14,6) NOT NULL,
  token TEXT NOT NULL CHECK (token IN ('usdc', 'btc', 'eth')),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'failed', 'expired', 'resolved')),
  hosted_url TEXT,                             -- Coinbase Commerce checkout URL
  local_address TEXT,                          -- self-custody deposit address (if onchain)
  tx_hash TEXT,                                -- confirmed tx hash
  confirmations INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  confirmed_at TIMESTAMPTZ
);

-- Merchant credit balance (materialised for fast reads)
ALTER TABLE merchants ADD COLUMN IF NOT EXISTS credit_balance_usd NUMERIC(14,6) NOT NULL DEFAULT 0;

-- Indexes for hot queries
CREATE INDEX IF NOT EXISTS idx_credit_ledger_merchant ON credit_ledger(merchant_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_usage_log_merchant ON usage_log(merchant_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_market_signals_asset ON market_signals(asset, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_market_signals_type ON market_signals(signal_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_crypto_charges_merchant ON crypto_charges(merchant_id, status);
CREATE INDEX IF NOT EXISTS idx_crypto_charges_coinbase ON crypto_charges(coinbase_charge_id);
CREATE INDEX IF NOT EXISTS idx_wallets_merchant ON wallets(merchant_id);

-- RLS policies
ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE credit_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE usage_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE market_signals ENABLE ROW LEVEL SECURITY;
ALTER TABLE crypto_charges ENABLE ROW LEVEL SECURITY;

-- Service role can do everything (API routes use supabaseAdmin)
CREATE POLICY wallets_service ON wallets FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY credit_ledger_service ON credit_ledger FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY usage_log_service ON usage_log FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY market_signals_service ON market_signals FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY crypto_charges_service ON crypto_charges FOR ALL USING (true) WITH CHECK (true);
