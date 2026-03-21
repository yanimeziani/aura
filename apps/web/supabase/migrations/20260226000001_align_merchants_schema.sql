ALTER TABLE merchants ADD COLUMN IF NOT EXISTS country TEXT;
ALTER TABLE merchants ADD COLUMN IF NOT EXISTS currency_preference TEXT DEFAULT 'CAD';
ALTER TABLE merchants ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE merchants ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN DEFAULT FALSE;
ALTER TABLE merchants ADD COLUMN IF NOT EXISTS stripe_account_id TEXT;
ALTER TABLE merchants ADD COLUMN IF NOT EXISTS stripe_onboarding_complete BOOLEAN DEFAULT FALSE;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'merchants'
      AND column_name = 'onboarding_step'
      AND data_type <> 'text'
  ) THEN
    ALTER TABLE merchants
      ALTER COLUMN onboarding_step TYPE TEXT
      USING onboarding_step::text;
  ELSIF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'merchants'
      AND column_name = 'onboarding_step'
  ) THEN
    ALTER TABLE merchants ADD COLUMN onboarding_step TEXT DEFAULT 'profile';
  END IF;
END $$;
