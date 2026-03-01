'use server';

import { sendEmail } from '@/lib/comms';
import * as Sentry from '@sentry/nextjs';

const SUBJECT_KEYS: Record<string, string> = {
  general: 'General Inquiry',
  sales: 'Sales',
  support: 'Support',
  partnerships: 'Partnerships',
};

function parseContactTo(): string | null {
  const to = process.env.CONTACT_EMAIL?.trim();
  if (to) return to;
  const from = process.env.RESEND_FROM?.trim();
  if (!from) return null;
  const match = from.match(/<([^>]+)>/);
  return match ? match[1].trim() : from;
}

export type ContactResult = { success: true } | { success: false; error: string };

export async function submitContact(formData: FormData): Promise<ContactResult> {
  try {
    const fullName = (formData.get('fullName') as string)?.trim();
    const email = (formData.get('email') as string)?.trim();
    const subjectKey = (formData.get('subject') as string)?.trim() || 'general';
    const message = (formData.get('message') as string)?.trim();

    if (!fullName || !email || !message) {
      return { success: false, error: 'Missing required fields' };
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return { success: false, error: 'Invalid email address' };
    }

    const to = parseContactTo();
    if (!to) {
      return {
        success: false,
        error: 'Contact form is not configured. Please set CONTACT_EMAIL or RESEND_FROM.',
      };
    }

    const subjectLabel = SUBJECT_KEYS[subjectKey] ?? subjectKey;
    const subject = `[Dragun Contact] ${subjectLabel} — ${fullName}`;
    const html = `
      <p><strong>From:</strong> ${fullName} &lt;${email}&gt;</p>
      <p><strong>Subject:</strong> ${subjectLabel}</p>
      <hr />
      <p>${message.replace(/\n/g, '<br />')}</p>
    `.trim();
    const text = `From: ${fullName} <${email}>\nSubject: ${subjectLabel}\n\n${message}`;

    const result = await sendEmail({
      to,
      subject,
      html,
      text,
      tags: ['contact', 'website'],
      metadata: { source: 'contact_form', subject_key: subjectKey },
    });

    if (!result.ok) {
      throw new Error(result.error.message);
    }

    return { success: true };
  } catch (err) {
    Sentry.captureException(err);
    const message = err instanceof Error ? err.message : 'Failed to send message';
    return { success: false, error: message };
  }
}
