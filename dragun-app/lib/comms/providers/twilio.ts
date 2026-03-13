import twilio from 'twilio';
import { buildNoopResultMeta, getTwilioConfig } from '@/lib/comms/config';
import { CommsFailure, CommsResult, SmsMessage, SmsProvider } from '@/lib/comms/types';

function fail(code: string, message: string, status?: number): CommsFailure {
  return {
    ok: false,
    channel: 'sms',
    provider: 'twilio',
    error: {
      provider: 'twilio',
      code,
      message,
      status,
    },
  };
}

export function createTwilioSmsProvider(): SmsProvider {
  return {
    name: 'twilio',
    async send(message: SmsMessage): Promise<CommsResult> {
      if (!message.body?.trim()) {
        return fail('SMS_BODY_REQUIRED', 'SMS body is required.');
      }

      const config = getTwilioConfig();
      if (!config.enabled) {
        const noop = buildNoopResultMeta('sms');
        return {
          ok: true,
          channel: 'sms',
          provider: noop.provider,
          id: noop.id,
        };
      }

      try {
        const client = twilio(config.accountSid!, config.authToken!);
        const created = await client.messages.create({
          to: message.to,
          body: message.body,
          from: message.from ?? config.from!,
          statusCallback: message.statusCallbackUrl ?? config.statusCallbackUrl,
        });

        return {
          ok: true,
          channel: 'sms',
          provider: 'twilio',
          id: created.sid,
          raw: {
            sid: created.sid,
            status: created.status,
            to: created.to,
            from: created.from,
          },
        };
      } catch (error: unknown) {
        if (typeof error === 'object' && error !== null) {
          const maybeCode = 'code' in error ? String(error.code) : 'TWILIO_REQUEST_FAILED';
          const maybeMessage = 'message' in error ? String(error.message) : 'Unknown Twilio error';
          const maybeStatus = 'status' in error ? Number(error.status) : undefined;
          return fail(maybeCode, maybeMessage, maybeStatus);
        }

        return fail('TWILIO_REQUEST_FAILED', 'Unknown Twilio error');
      }
    },
  };
}
