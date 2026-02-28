import { NextResponse } from 'next/server';
import crypto from 'crypto';
import { supabaseAdmin } from '@/lib/supabase-admin';
import * as Sentry from '@sentry/nextjs';

export const runtime = 'nodejs';

const RESEND_WEBHOOK_SECRET = process.env.RESEND_WEBHOOK_SECRET;

interface ResendWebhookEvent {
  id: string;
  created_at: string;
  type: string;
  data: {
    id: string;
    created_at: string;
    from: string;
    to: string[];
    subject?: string;
    html?: string;
    text?: string;
    headers?: Record<string, string>;
    tags?: Array<{ name: string; value: string }>;
  };
}

export async function POST(request: Request) {
  try {
    // Get raw body for signature verification
    const rawBody = await request.text();

    // Verify webhook signature
    const signature = request.headers.get('resend-signature');
    if (!signature) {
      return NextResponse.json(
        { error: 'Missing resend-signature header' },
        { status: 401 }
      );
    }

    if (!RESEND_WEBHOOK_SECRET) {
      return NextResponse.json(
        { error: 'RESEND_WEBHOOK_SECRET not configured' },
        { status: 500 }
      );
    }

    // Verify the webhook signature
    const expectedSignature = crypto
      .createHmac('sha256', RESEND_WEBHOOK_SECRET)
      .update(rawBody)
      .digest('hex');

    if (!crypto.timingSafeEqual(
      Buffer.from(signature),
      Buffer.from(expectedSignature)
    )) {
      return NextResponse.json(
        { error: 'Invalid signature' },
        { status: 401 }
      );
    }

    // Parse webhook event
    const event: ResendWebhookEvent = JSON.parse(rawBody);

    console.log('[webhook] Received event:', {
      id: event.id,
      type: event.type,
      emailId: event.data.id,
    });

    // Handle different event types
    switch (event.type) {
      case 'email.sent':
        // Email was successfully sent
        console.log('[webhook] Email sent:', event.data.id);
        break;

      case 'email.delivered':
        // Email was delivered to recipient
        console.log('[webhook] Email delivered:', event.data.id);
        break;

      case 'email.opened':
        // Recipient opened the email
        console.log('[webhook] Email opened:', event.data.id);
        break;

      case 'email.clicked':
        // Recipient clicked a link in the email
        console.log('[webhook] Email clicked:', event.data.id);
        break;

      case 'email.complained':
        console.warn('[webhook] Email complained (spam):', event.data.id);
        await updateDebtorOnBounceOrComplaint(event.data.to);
        break;

      case 'email.bounced':
        console.error('[webhook] Email bounced:', event.data);
        await updateDebtorOnBounceOrComplaint(event.data.to);
        break;

      case 'email.deferred':
        // Email delivery delayed
        console.warn('[webhook] Email deferred:', event.data.id);
        break;

      default:
        console.warn('[webhook] Unknown event type:', event.type);
    }

    return NextResponse.json({ received: true });

  } catch (error) {
    console.error('[webhook] Error processing webhook:', error);
    return NextResponse.json(
      { error: 'Failed to process webhook' },
      { status: 500 }
    );
  }
}

async function updateDebtorOnBounceOrComplaint(to: string[]) {
  if (!to?.length) return;
  const email = to[0];
  try {
    const { data: debtor } = await supabaseAdmin
      .from('debtors')
      .select('id, merchant_id, status')
      .eq('email', email)
      .single();

    if (debtor) {
      await supabaseAdmin
        .from('recovery_actions')
        .insert({
          debtor_id: debtor.id,
          merchant_id: debtor.merchant_id,
          action_type: 'email_bounce',
          status_after: debtor.status,
          note: 'Email bounced or marked as spam',
        });
    }
  } catch (err) {
    Sentry.captureException(err);
  }
}
