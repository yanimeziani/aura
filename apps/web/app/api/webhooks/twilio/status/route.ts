import { NextResponse } from 'next/server';
import twilio from 'twilio';
import { getTwilioConfig } from '@/lib/comms/config';
import { supabaseAdmin } from '@/lib/supabase-admin';
import * as Sentry from '@sentry/nextjs';

export const runtime = 'nodejs';

/** Twilio sends status callbacks as POST application/x-www-form-urlencoded. */
export async function POST(request: Request) {
  try {
    const config = getTwilioConfig();
    if (!config.enabled || !config.authToken) {
      return NextResponse.json(
        { error: 'Twilio not configured' },
        { status: 503 }
      );
    }

    const signature = request.headers.get('x-twilio-signature');
    if (!signature) {
      return NextResponse.json(
        { error: 'Missing X-Twilio-Signature' },
        { status: 401 }
      );
    }

    const rawBody = await request.text();
    const params: Record<string, string> = {};
    new URLSearchParams(rawBody).forEach((value, key) => {
      params[key] = value;
    });

    const baseUrl = process.env.NEXT_PUBLIC_URL || request.url.split('/api')[0];
    const webhookUrl = `${baseUrl.replace(/\/$/, '')}/api/webhooks/twilio/status`;
    const isValid = twilio.validateRequest(config.authToken, signature, webhookUrl, params);
    if (!isValid) {
      return NextResponse.json(
        { error: 'Invalid signature' },
        { status: 401 }
      );
    }

    const messageSid = params.MessageSid;
    const messageStatus = params.MessageStatus;
    const to = params.To;

    if (!messageSid || !messageStatus) {
      return NextResponse.json(
        { error: 'Missing MessageSid or MessageStatus' },
        { status: 400 }
      );
    }

    let debtorId: string | null = null;
    let merchantId: string | null = null;
    if (to) {
      const { data: debtor } = await supabaseAdmin
        .from('debtors')
        .select('id, merchant_id')
        .eq('phone', to)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();
      if (debtor) {
        debtorId = debtor.id;
        merchantId = debtor.merchant_id;
      }
    }

    await supabaseAdmin.from('recovery_actions').insert({
      debtor_id: debtorId,
      merchant_id: merchantId,
      action_type: 'sms_status',
      status_after: messageStatus,
      note: `SMS ${messageSid} → ${messageStatus}${to ? ` to ${to}` : ''}`,
    });

    return NextResponse.json({ received: true });
  } catch (error) {
    console.error('[webhook] Twilio status error:', error);
    Sentry.captureException(error);
    return NextResponse.json(
      { error: 'Failed to process webhook' },
      { status: 500 }
    );
  }
}
