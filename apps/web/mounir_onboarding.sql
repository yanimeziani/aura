-- Onboarding Mounir (Venice Luxury Gym)
-- Run this in your Supabase SQL Editor

-- 1. Create the auth user for Mounir
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
  '00000000-0000-0000-0000-000000000002',
  'mounir@veniceluxury.gym',
  NOW(),
  '{"full_name": "Mounir (Venice Gym)", "provider": "google"}'::jsonb,
  '{"provider": "google", "providers": ["google"]}'::jsonb,
  'authenticated',
  'authenticated',
  NOW(),
  NOW()
)
ON CONFLICT (id) DO NOTHING;

-- 2. Create the merchant record
INSERT INTO merchants (
  id, 
  name, 
  email, 
  strictness_level, 
  settlement_floor, 
  onboarding_completed, 
  onboarding_complete,
  currency_preference
)
VALUES (
  '00000000-0000-0000-0000-000000000002',
  'Venice Luxury Gym & Wellness Center',
  'mounir@veniceluxury.gym',
  7,
  0.70,
  TRUE,
  TRUE,
  'CAD'
)
ON CONFLICT (id) DO NOTHING;

-- 3. Insert the membership agreement (Knowledge Base)
INSERT INTO contracts (
  id,
  merchant_id,
  file_name,
  file_path,
  raw_text
)
VALUES (
  '22222222-2222-2222-2222-222222222222',
  '00000000-0000-0000-0000-000000000002',
  'Venice_Gym_Membership_Agreement.pdf',
  'merchants/00000000-0000-0000-0000-000000000002/Venice_Gym_Membership_Agreement.pdf',
  '# MASTER SERVICE AGREEMENT & MEMBERSHIP CONTRACT
Business Entity: Venice Luxury Gym & Wellness Center (a Dragun Technologies Partner)
Revision Date: February 20, 2026

## 1. PAYMENT TERMS & BILLING CYCLE
1.1 Membership Dues: All monthly membership fees are billed on the 1st day of each calendar month.
1.2 Payment Methods: Members must maintain a valid Credit Card or ACH direct debit authorization on file via the Stripe Gateway.
1.3 Pre-paid Credits: Any pre-paid personal training credits expire within 60 days of purchase and are non-refundable.

## 2. LATE FEES & DELINQUENCY
2.1 Grace Period: A grace period of 5 calendar days is provided from the due date.
2.2 Late Penalty: A fixed late fee of $25.00 will be automatically applied to any balance unpaid after the 5th of the month.
2.3 Service Suspension: Access to facilities and training sessions will be suspended if an account is 10 days past due.

## 3. CANCELLATION & TERMINATION POLICY
3.1 Notice Period: Members must provide a minimum of 30 days written notice prior to their next billing cycle to cancel a membership.
3.2 Early Termination Fee: If a 12-month commitment contract is terminated before the 6th month, a flat $150.00 Early Termination Fee (ETF) applies.
3.3 Medical Exceptions: Cancellation notice may be waived only upon presentation of a signed medical certificate from a licensed physician stating the member is physically unable to utilize the facilities.

## 4. REFUND POLICY
4.1 Initiated Services: Once a membership cycle has begun or a training session has been attended, no refunds will be issued for that period.
4.2 Mistaken Charges: Any disputes regarding billing must be submitted in writing within 15 days of the transaction date.

## 5. COLLECTIONS & LEGAL PROTOCOL
5.1 Third-Party Referral: Accounts more than 32 days past due are automatically referred to our automated resolution agent, Dragun AI (Meziani AI), for recovery.
5.2 Recovery Costs: The member agrees to be responsible for all reasonable collection costs, including but not limited to platform fees (5%) and reasonable attorney fees if legal action is required.
5.3 Settlement Authority: Our AI agents are authorized to offer a maximum 30% discount (lump-sum settlement) for accounts older than 60 days, provided payment is made within 24 hours of the offer.

## 6. DISPUTE RESOLUTION
6.1 Governing Law: This agreement shall be governed by the laws of the State/Province where the facility is located.
6.2 Arbitration: All disputes not resolved via Dragun AI negotiation shall be referred to binding arbitration.'
)
ON CONFLICT (id) DO NOTHING;

-- 4. Seed the Debtors (Pilot Dataset)
INSERT INTO debtors (id, merchant_id, name, email, phone, total_debt, currency, status, days_overdue, last_contacted)
VALUES 
  (
    '10000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000002',
    'Jean-Claude Van Damme',
    'jcvd@example.com',
    '+15551234567',
    1250.00,
    'CAD',
    'pending',
    32,
    NULL
  ),
  (
    '10000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000002',
    'Arnold Schwarzenegger',
    'arnold@example.com',
    '+15559876543',
    850.00,
    'CAD',
    'contacted',
    15,
    NOW() - INTERVAL '2 days'
  ),
  (
    '10000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000002',
    'Sylvester Stallone',
    'sly@example.com',
    '+15554443333',
    150.00,
    'CAD',
    'promise_to_pay',
    45,
    NOW() - INTERVAL '5 days'
  ),
  (
    '10000000-0000-0000-0000-000000000004',
    '00000000-0000-0000-0000-000000000002',
    'Linda Hamilton',
    'linda@example.com',
    '+15552221111',
    500.00,
    'CAD',
    'pending',
    10,
    NULL
  )
ON CONFLICT (id) DO NOTHING;

-- 5. Add initial recovery actions for the audit trail
INSERT INTO recovery_actions (debtor_id, merchant_id, action_type, status_after, note, created_at)
VALUES 
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'import', 'pending', 'Pilot dataset import', NOW() - INTERVAL '1 day'),
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', 'email_outreach', 'contacted', 'Initial outreach sent', NOW() - INTERVAL '2 days'),
  ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000002', 'status_update', 'promise_to_pay', 'Debtor promised to pay by Friday', NOW() - INTERVAL '5 days'),
  ('10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000002', 'import', 'pending', 'Pilot dataset import', NOW() - INTERVAL '1 day');
