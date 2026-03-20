import * as dotenv from 'dotenv';
import path from 'path';
import fs from 'fs';

// Load .env
dotenv.config({ path: path.resolve(__dirname, '../.env') });

import { supabaseAdmin } from '../lib/supabase-admin';

async function runOnboarding() {
  console.log('🏗️ Loading mounir_onboarding.sql...');
  
  const sqlPath = path.resolve(__dirname, '../mounir_onboarding.sql');
  const sql = fs.readFileSync(sqlPath, 'utf8');

  // Supabase client doesn't support running raw SQL strings with multiple statements easily via RPC
  // So we will split by standard SQL delimiters or just notify the user.
  // Actually, the best way for a one-off is to use the Supabase SQL Editor, 
  // but I can try to execute the core inserts via the client for you.

  console.log('🚀 Executing core onboarding inserts...');

  // 1. Merchant
  const { error: mErr } = await supabaseAdmin.from('merchants').upsert({
    id: '00000000-0000-0000-0000-000000000002',
    name: 'Venice Luxury Gym & Wellness Center',
    email: 'mounir@veniceluxury.gym',
    strictness_level: 7,
    settlement_floor: 0.70,
    onboarding_completed: true,
    onboarding_complete: true,
    currency_preference: 'CAD'
  });
  if (mErr) console.error('Merchant Error:', mErr); else console.log('✅ Merchant created.');

  // 2. Contract
  const { error: cErr } = await supabaseAdmin.from('contracts').upsert({
    id: '22222222-2222-2222-2222-222222222222',
    merchant_id: '00000000-0000-0000-0000-000000000002',
    file_name: 'Venice_Gym_Membership_Agreement.pdf',
    file_path: 'merchants/00000000-0000-0000-0000-000000000002/Venice_Gym_Membership_Agreement.pdf',
    raw_text: `
# MASTER SERVICE AGREEMENT & MEMBERSHIP CONTRACT
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
6.2 Arbitration: All disputes not resolved via Dragun AI negotiation shall be referred to binding arbitration.
    `
  });
  if (cErr) console.error('Contract Error:', cErr); else console.log('✅ Contract created.');

  // 3. Debtors
  const debtors = [
    {
      id: '10000000-0000-0000-0000-000000000001',
      merchant_id: '00000000-0000-0000-0000-000000000002',
      name: 'Jean-Claude Van Damme',
      email: 'jcvd@example.com',
      phone: '+15551234567',
      total_debt: 1250.00,
      currency: 'CAD',
      status: 'pending',
      days_overdue: 32
    },
    {
      id: '10000000-0000-0000-0000-000000000002',
      merchant_id: '00000000-0000-0000-0000-000000000002',
      name: 'Arnold Schwarzenegger',
      email: 'arnold@example.com',
      phone: '+15559876543',
      total_debt: 850.00,
      currency: 'CAD',
      status: 'contacted',
      days_overdue: 15
    }
  ];

  const { error: dErr } = await supabaseAdmin.from('debtors').upsert(debtors);
  if (dErr) console.error('Debtors Error:', dErr); else console.log('✅ Debtors created.');

  console.log('🎉 Onboarding successful!');
}

runOnboarding().catch(console.error);
