import { Resend } from 'resend';
import { buildNoopResultMeta, getResendConfig } from '@/lib/comms/config';
import { CommsFailure, CommsResult, EmailMessage, EmailProvider } from '@/lib/comms/types';

function asArray(to: EmailMessage['to']): string[] {
  return Array.isArray(to) ? to : [to];
}

function buildTags(message: EmailMessage): Array<{ name: string; value: string }> | undefined {
  const tags = message.tags?.map((tag) => ({ name: tag, value: 'true' })) ?? [];
  const metadata = Object.entries(message.metadata ?? {}).map(([name, value]) => ({
    name: `meta_${name}`.slice(0, 256),
    value: String(value).slice(0, 256),
  }));
  const merged = [...tags, ...metadata];

  return merged.length > 0 ? merged : undefined;
}

function fail(code: string, message: string, status?: number): CommsFailure {
  return {
    ok: false,
    channel: 'email',
    provider: 'resend',
    error: {
      provider: 'resend',
      code,
      message,
      status,
    },
  };
}

export function createResendEmailProvider(): EmailProvider {
  return {
    name: 'resend',
    async send(message: EmailMessage): Promise<CommsResult> {
      if (!message.html && !message.text) {
        return fail('EMAIL_CONTENT_REQUIRED', 'Email requires at least one of html or text.');
      }

      const config = getResendConfig();
      if (!config.enabled) {
        const noop = buildNoopResultMeta('email');
        return {
          ok: true,
          channel: 'email',
          provider: noop.provider,
          id: noop.id,
        };
      }

      const client = new Resend(config.apiKey);

      try {
        const response = await client.emails.send({
          to: asArray(message.to),
          from: message.from ?? config.from!,
          subject: message.subject,
          html: message.html,
          text: message.text,
          tags: buildTags(message),
        });

        if (response.error) {
          return fail(response.error.name ?? 'RESEND_ERROR', response.error.message);
        }

        return {
          ok: true,
          channel: 'email',
          provider: 'resend',
          id: response.data?.id,
          raw: response.data,
        };
      } catch (error) {
        const fallback = error instanceof Error ? error.message : 'Unknown Resend error';
        return fail('RESEND_REQUEST_FAILED', fallback);
      }
    },
  };
}
