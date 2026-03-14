import { getConfiguredEmailProvider, getConfiguredSmsProvider } from '@/lib/comms/config';
import { createResendEmailProvider } from '@/lib/comms/providers/resend';
import { createTwilioSmsProvider } from '@/lib/comms/providers/twilio';
import {
  CommsDispatchRequest,
  CommsFailure,
  CommsResult,
  EmailMessage,
  EmailProvider,
  SmsMessage,
  SmsProvider,
} from '@/lib/comms/types';

function fail(channel: 'email' | 'sms', provider: 'resend' | 'twilio' | 'noop', code: string, message: string): CommsFailure {
  return {
    ok: false,
    channel,
    provider,
    error: {
      provider,
      code,
      message,
    },
  };
}

function resolveEmailProvider(): EmailProvider | undefined {
  const configured = getConfiguredEmailProvider();

  if (configured === 'resend') {
    return createResendEmailProvider();
  }

  if (configured === 'noop') {
    return {
      name: 'noop',
      async send(): Promise<CommsResult> {
        return {
          ok: true,
          channel: 'email',
          provider: 'noop',
          id: `noop-email-${Date.now()}`,
        };
      },
    };
  }

  return undefined;
}

function resolveSmsProvider(): SmsProvider | undefined {
  const configured = getConfiguredSmsProvider();

  if (configured === 'twilio') {
    return createTwilioSmsProvider();
  }

  if (configured === 'noop') {
    return {
      name: 'noop',
      async send(): Promise<CommsResult> {
        return {
          ok: true,
          channel: 'sms',
          provider: 'noop',
          id: `noop-sms-${Date.now()}`,
        };
      },
    };
  }

  return undefined;
}

export async function sendEmail(message: EmailMessage): Promise<CommsResult> {
  const provider = resolveEmailProvider();

  if (!provider) {
    return fail('email', 'noop', 'EMAIL_PROVIDER_INVALID', 'EMAIL_PROVIDER is invalid or unsupported.');
  }

  return provider.send(message);
}

export async function sendSms(message: SmsMessage): Promise<CommsResult> {
  const provider = resolveSmsProvider();

  if (!provider) {
    return fail('sms', 'noop', 'SMS_PROVIDER_INVALID', 'SMS_PROVIDER is invalid or unsupported.');
  }

  return provider.send(message);
}

export async function dispatchComms(request: CommsDispatchRequest): Promise<CommsResult> {
  if (request.channel === 'email') {
    return sendEmail(request.payload);
  }

  return sendSms(request.payload);
}
