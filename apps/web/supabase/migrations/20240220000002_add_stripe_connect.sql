-- Add stripe_account_id to merchants table
ALTER TABLE merchants ADD COLUMN IF NOT EXISTS stripe_account_id TEXT;
ALTER TABLE merchants ADD COLUMN IF NOT EXISTS stripe_onboarding_complete BOOLEAN DEFAULT FALSE;
