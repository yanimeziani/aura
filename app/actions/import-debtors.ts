'use server';

import { supabaseAdmin } from '@/lib/supabase-admin';
import { revalidatePath } from 'next/cache';
import { getMerchantId } from '@/lib/auth';
import { checkPaywall } from '@/lib/paywall';

interface ParsedDebtor {
  name: string;
  email: string;
  phone: string | null;
  total_debt: number;
  currency: string;
  days_overdue: number;
}

function parseCSVLine(line: string): string[] {
  const result: string[] = [];
  let current = '';
  let inQuotes = false;

  for (let i = 0; i < line.length; i++) {
    const char = line[i];
    if (char === '"') {
      inQuotes = !inQuotes;
    } else if (char === ',' && !inQuotes) {
      result.push(current.trim());
      current = '';
    } else {
      current += char;
    }
  }
  result.push(current.trim());
  return result;
}

export async function importDebtors(
  formData: FormData
): Promise<{ success: boolean; imported: number; errors: string[]; outreachSent?: number }> {
  const merchantId = await getMerchantId();
  if (!merchantId) throw new Error('Unauthorized');

  const file = formData.get('csv') as File | null;
  if (!file) return { success: false, imported: 0, errors: ['No file uploaded'] };

  const text = await file.text();
  const lines = text.split(/\r?\n/).filter(l => l.trim());
  if (lines.length < 2) return { success: false, imported: 0, errors: ['CSV must have a header row and at least one data row'] };

  const headerRaw = parseCSVLine(lines[0]);
  const headers = headerRaw.map(h => h.toLowerCase().replace(/[^a-z0-9_]/g, '_'));

  const nameIdx = headers.findIndex(h => h === 'name' || h === 'debtor_name' || h === 'full_name');
  const emailIdx = headers.findIndex(h => h === 'email' || h === 'debtor_email');
  const debtIdx = headers.findIndex(h => h === 'total_debt' || h === 'amount' || h === 'debt' || h === 'balance');
  const currencyIdx = headers.findIndex(h => h === 'currency');
  const phoneIdx = headers.findIndex(h => h === 'phone' || h === 'phone_number');
  const daysIdx = headers.findIndex(h => h === 'days_overdue' || h === 'overdue_days' || h === 'days');

  if (nameIdx === -1 || emailIdx === -1 || debtIdx === -1) {
    return { success: false, imported: 0, errors: ['CSV must have columns: name, email, total_debt (or amount/debt/balance)'] };
  }

  const paywall = await checkPaywall(merchantId);
  const remainingSlots = paywall.limit - paywall.currentCount;

  const parsed: ParsedDebtor[] = [];
  const errors: string[] = [];

  for (let i = 1; i < lines.length; i++) {
    const cols = parseCSVLine(lines[i]);
    const name = cols[nameIdx]?.trim();
    const email = cols[emailIdx]?.trim();
    const debtStr = cols[debtIdx]?.trim().replace(/[$,]/g, '');
    const total_debt = parseFloat(debtStr || '0');

    if (!name || !email) {
      errors.push(`Row ${i + 1}: missing name or email`);
      continue;
    }
    if (isNaN(total_debt) || total_debt <= 0) {
      errors.push(`Row ${i + 1}: invalid debt amount "${cols[debtIdx]}"`);
      continue;
    }

    parsed.push({
      name,
      email,
      phone: phoneIdx >= 0 ? (cols[phoneIdx]?.trim() || null) : null,
      total_debt,
      currency: currencyIdx >= 0 ? (cols[currencyIdx]?.trim().toUpperCase() || 'USD') : 'USD',
      days_overdue: daysIdx >= 0 ? Math.max(0, parseInt(cols[daysIdx] || '0') || 0) : 0,
    });
  }

  if (parsed.length === 0) {
    return { success: false, imported: 0, errors: errors.length ? errors : ['No valid rows found in CSV'] };
  }

  const toInsert = parsed.slice(0, Math.max(0, remainingSlots));
  const skipped = parsed.length - toInsert.length;

  if (skipped > 0) {
    errors.push(`${skipped} debtors skipped -- upgrade your plan to import more (${paywall.plan} plan: ${paywall.limit} debtor limit)`);
  }

  if (toInsert.length === 0) {
    return { success: false, imported: 0, errors: ['Debtor limit reached. Upgrade your plan to import debtors.'] };
  }

  const { data: inserted, error: insertError } = await supabaseAdmin
    .from('debtors')
    .insert(
      toInsert.map((d) => ({
        merchant_id: merchantId,
        name: d.name,
        email: d.email,
        phone: d.phone,
        total_debt: d.total_debt,
        currency: d.currency,
        days_overdue: d.days_overdue,
        status: 'pending',
      }))
    )
    .select('id');

  if (insertError) {
    return { success: false, imported: 0, errors: [insertError.message] };
  }

  const autoSend = formData.get('auto_send_outreach') === 'true';
  let outreachSent = 0;
  if (autoSend && inserted?.length) {
    const { sendInitialOutreach } = await import('@/app/actions/send-outreach');
    for (const row of inserted) {
      const fd = new FormData();
      fd.set('debtor_id', row.id);
      const res = await sendInitialOutreach(fd);
      if (res.success) outreachSent++;
    }
  }

  revalidatePath('/[locale]/dashboard', 'page');
  return {
    success: true,
    imported: inserted?.length ?? 0,
    errors,
    outreachSent: autoSend ? outreachSent : undefined,
  };
}
