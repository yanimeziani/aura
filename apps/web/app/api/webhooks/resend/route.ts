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

    const isDev = process.env.NODE_ENV !== 'production';
    if (isDev) {
      console.log('[webhook] Received event:', {
        id: event.id,
        type: event.type,
        emailId: event.data.id,
      });
    }

    // Handle different event types
    switch (event.type) {
      case 'email.received':
        if (isDev) console.log('[webhook] Email received:', event.data.id);
        await routeInboundEmail(event.data);
        break;

      case 'email.sent':
        if (isDev) console.log('[webhook] Email sent:', event.data.id);
        break;

      case 'email.delivered':
        if (isDev) console.log('[webhook] Email delivered:', event.data.id);
        break;

      case 'email.opened':
        if (isDev) console.log('[webhook] Email opened:', event.data.id);
        break;

      case 'email.clicked':
        if (isDev) console.log('[webhook] Email clicked:', event.data.id);
        break;

      case 'email.complained':
        if (isDev) console.warn('[webhook] Email complained (spam):', event.data.id);
        await updateDebtorOnBounceOrComplaint(event.data.to);
        break;

      case 'email.bounced':
        console.error('[webhook] Email bounced:', event.data);
        await updateDebtorOnBounceOrComplaint(event.data.to);
        break;

      case 'email.deferred':
        if (isDev) console.warn('[webhook] Email deferred:', event.data.id);
        break;

      default:
        if (isDev) console.warn('[webhook] Unknown event type:', event.type);
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

async function routeInboundEmail(data: ResendWebhookEvent['data']) {
  const PERSONAL_EMAIL = 'mezianiyani0@gmail.com';
  
  try {
    const { Resend } = await import('resend');
    const resend = new Resend(process.env.RESEND_API_KEY);

    await resend.emails.send({
      from: process.env.RESEND_FROM || 'inbound@aura.meziani.org',
      to: PERSONAL_EMAIL,
      subject: `[Aura Inbound] ${data.subject || 'No Subject'}`,
      html: `
        <p><strong>From:</strong> ${data.from}</p>
        <p><strong>Subject:</strong> ${data.subject || '(No Subject)'}</p>
        <hr />
        ${data.html || data.text || '<p>(Empty content)</p>'}
        <hr />
        <p><small>Forwarded by Aura Media Outreach Agent</small></p>
      `,
      text: `
        From: ${data.from}
        Subject: ${data.subject || '(No Subject)'}
        ---
        ${data.text || '(Empty content)'}
        ---
        Forwarded by Aura Media Outreach Agent
      `,
    });
    
    if (process.env.NODE_ENV !== 'production') {
      console.log(`[webhook] Routed inbound email from ${data.from} to ${PERSONAL_EMAIL}`);
    }
  } catch (err) {
    console.error('[webhook] Failed to route inbound email:', err);
    Sentry.captureException(err);
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
