'use server';

import { supabaseAdmin } from '@/lib/supabase-admin';
import { ensureMerchant } from '@/lib/merchant';

export async function getSovereignData() {
  try {
    const merchantId = await ensureMerchant();
    if (!merchantId) {
      return { success: false, error: 'Unauthorized' };
    }

    // 1. Fetch Recovery Stats for CURRENT MERCHANT
    const { data: merchants } = await supabaseAdmin
      .from('merchants')
      .select('id, name')
      .eq('id', merchantId)
      .single();

    let recoveryStats = { outstanding: 0, count: 0, recovered: 0 };
    let topDebtors = [];

    if (merchants) {
      const { data: debtors } = await supabaseAdmin
        .from('debtors')
        .select('*')
        .eq('merchant_id', merchants.id)
        .order('total_debt', { ascending: false })
        .limit(10); // Show up to 10 in the Terminal view

      if (debtors) {
        topDebtors = debtors;
        recoveryStats.outstanding = debtors.reduce((acc, d) => acc + d.total_debt, 0);
        recoveryStats.count = debtors.length;
        recoveryStats.recovered = debtors.filter(d => d.status === 'paid' || d.status === 'settled').length;
      }
    }

    // 2. Mock Agent Status (Real Cerberus check would happen via API)
    const agentStatus = {
      careerTwin: { status: 'idle', lastAction: 'Paved terrain for onboarding' },
      sdrAgent: { status: 'idle', lastAction: 'Waiting for targets' }
    };

    // 3. Calendar Status (Ready to sync)
    const calendarStatus = {
      paved: true,
      lastSync: new Date().toISOString(),
      upcomingEvents: [
        { id: '1', title: 'Onboarding Mounir', start: '2026-03-14T15:00:00Z', description: '15 min sync' }
      ]
    };

    return {
      success: true,
      recoveryStats,
      topDebtors,
      agentStatus,
      calendarStatus,
      systemTime: new Date().toISOString()
    };
  } catch (error) {
    console.error('Failed to fetch sovereign data:', error);
    return { success: false, error: 'Internal Server Error' };
  }
}
