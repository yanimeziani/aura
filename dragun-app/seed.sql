-- ============================================================
-- Seed script for local/dev testing with Google Auth (Supabase)
-- 
-- Since merchants.id = auth.users.id (enforced by RLS),
-- we must insert a user into auth.users first, then reference
-- that same UUID for the merchant and related records.
-- ============================================================

-- 1. Seed a fake auth user (mimics a Google OAuth sign-in)
--    The callback route uses user.id, user.email, and
--    user.user_metadata.full_name when creating the merchant.
INSERT INTO auth.users (
  id,
  email,
  email_confirmed_at,
  raw_user_meta_data,
  raw_app_meta_data,
  aud,
  role,
  created_at,
  updated_at
)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  'mezianiyani0@gmail.com',
  NOW(),
  '{"full_name": "Yani Meziani", "provider": "google"}'::jsonb,
  '{"provider": "google", "providers": ["google"]}'::jsonb,
  'authenticated',
  'authenticated',
  NOW(),
  NOW()
)
ON CONFLICT (id) DO NOTHING;

-- 2. Seed the merchant — id must match auth.users.id for RLS
INSERT INTO merchants (id, name, email, strictness_level, settlement_floor)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  'Yani Meziani',
  'mezianiyani0@gmail.com',
  7,
  0.75
)
ON CONFLICT (id) DO NOTHING;

-- 3. Seed a debtor tied to the merchant
INSERT INTO debtors (id, merchant_id, name, email, total_debt, currency, status)
VALUES (
  '11111111-1111-1111-1111-111111111111',
  '00000000-0000-0000-0000-000000000001',
  'Yani',
  'yani@example.com',
  250.00,
  'USD',
  'pending'
)
ON CONFLICT (id) DO NOTHING;
