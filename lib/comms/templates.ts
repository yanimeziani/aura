interface OutreachParams {
  debtorName: string;
  merchantName: string;
  amount: string;
  currency: string;
  chatUrl: string;
  payUrl: string;
}

export function initialOutreachEmail(p: OutreachParams) {
  const firstName = p.debtorName.split(' ')[0];

  return {
    subject: `${p.merchantName} — Open balance on your account`,
    text: [
      `Hi ${firstName},`,
      '',
      `We're reaching out about an outstanding balance of ${p.currency} ${p.amount} on your account with ${p.merchantName}.`,
      '',
      `We understand that situations vary, so we offer several flexible resolution options:`,
      `• Full payment`,
      `• Settlement at a reduced amount`,
      `• Monthly payment plan`,
      '',
      `You can review your options and chat with our resolution assistant here:`,
      p.chatUrl,
      '',
      `Or go directly to the payment page:`,
      p.payUrl,
      '',
      `If you believe this is an error, simply reply to this message or use the chat link above.`,
      '',
      `Best regards,`,
      `${p.merchantName} — Account Resolution`,
    ].join('\n'),
    html: `
      <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; max-width: 560px; margin: 0 auto; color: #333;">
        <p>Hi ${firstName},</p>
        <p>We're reaching out about an outstanding balance of <strong>${p.currency} ${p.amount}</strong> on your account with ${p.merchantName}.</p>
        <p>We understand that situations vary, so we offer several flexible resolution options:</p>
        <ul style="padding-left: 1.2em;">
          <li>Full payment</li>
          <li>Settlement at a reduced amount</li>
          <li>Monthly payment plan</li>
        </ul>
        <p style="margin-top: 24px;">
          <a href="${p.chatUrl}" style="display: inline-block; background: #2563eb; color: white; padding: 12px 24px; border-radius: 8px; text-decoration: none; font-weight: 600;">Review Options</a>
        </p>
        <p style="margin-top: 16px; font-size: 14px; color: #888;">
          Or <a href="${p.payUrl}" style="color: #2563eb;">go directly to the payment page</a>.
        </p>
        <p style="font-size: 13px; color: #999; margin-top: 32px; border-top: 1px solid #eee; padding-top: 16px;">
          If you believe this is an error, simply reply to this message or use the chat link above.<br/>
          ${p.merchantName} — Account Resolution
        </p>
      </div>
    `.trim(),
  };
}

export function followUpEmail(p: OutreachParams, daysSinceFirst: number) {
  const firstName = p.debtorName.split(' ')[0];

  return {
    subject: `${p.merchantName} — Friendly follow-up on your account`,
    text: [
      `Hi ${firstName},`,
      '',
      `We reached out ${daysSinceFirst} days ago about a balance of ${p.currency} ${p.amount} with ${p.merchantName}.`,
      '',
      `We'd love to help you resolve this. Our flexible options are still available, including payment plans.`,
      '',
      `Chat with our resolution assistant: ${p.chatUrl}`,
      `Payment options: ${p.payUrl}`,
      '',
      `Best regards,`,
      `${p.merchantName} — Account Resolution`,
    ].join('\n'),
    html: `
      <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; max-width: 560px; margin: 0 auto; color: #333;">
        <p>Hi ${firstName},</p>
        <p>We reached out ${daysSinceFirst} days ago about a balance of <strong>${p.currency} ${p.amount}</strong> with ${p.merchantName}.</p>
        <p>We'd love to help you resolve this. Our flexible options are still available, including payment plans.</p>
        <p style="margin-top: 24px;">
          <a href="${p.chatUrl}" style="display: inline-block; background: #2563eb; color: white; padding: 12px 24px; border-radius: 8px; text-decoration: none; font-weight: 600;">View Options</a>
        </p>
        <p style="font-size: 13px; color: #999; margin-top: 32px; border-top: 1px solid #eee; padding-top: 16px;">
          ${p.merchantName} — Account Resolution
        </p>
      </div>
    `.trim(),
  };
}
