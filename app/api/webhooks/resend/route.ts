import { NextResponse } from 'next/server';
import { Resend } from 'resend';
import crypto from 'crypto';

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
        // Recipient marked as spam
        console.warn('[webhook] Email complained (spam):', event.data.id);
        break;

      case 'email.bounced':
        // Email bounced
        console.error('[webhook] Email bounced:', event.data);
        // TODO: Update debtor status or record bounce
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
