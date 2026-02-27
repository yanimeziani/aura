import { CommsChannel, CommsProviderName } from '@/lib/comms/types';

const warnedKeys = new Set<string>();

function clean(value: string | undefined): string | undefined {
  const next = value?.trim();
  return next ? next : undefined;
}

function warnOnce(key: string, message: string): void {
  if (warnedKeys.has(key)) {
    return;
  }

  warnedKeys.add(key);
  console.warn(`[comms] ${message}`);
}

function readProvider(raw: string | undefined, fallback: CommsProviderName): CommsProviderName {
  const value = clean(raw)?.toLowerCase();
  if (!value) {
    return fallback;
  }

  if (value === 'resend' || value === 'twilio' || value === 'noop') {
    return value;
  }

  warnOnce(`invalid-provider:${value}`, `Unsupported provider "${value}". Falling back to ${fallback}.`);
  return fallback;
}

export function getConfiguredEmailProvider(): CommsProviderName {
  return readProvider(process.env.EMAIL_PROVIDER, 'resend');
}

export function getConfiguredSmsProvider(): CommsProviderName {
  return readProvider(process.env.SMS_PROVIDER, 'twilio');
}

export function getResendConfig(): {
  apiKey?: string;
  from?: string;
  enabled: boolean;
} {
  const apiKey = clean(process.env.RESEND_API_KEY);
  const from = clean(process.env.RESEND_FROM);
  const enabled = Boolean(apiKey && from);

  if (!enabled) {
    warnOnce(
      'resend:missing',
      'RESEND_API_KEY and/or RESEND_FROM missing. Email delivery is running in noop mode.'
    );
  }

  return { apiKey, from, enabled };
}

export function getTwilioConfig(): {
  accountSid?: string;
  authToken?: string;
  from?: string;
  enabled: boolean;
} {
  const accountSid = clean(process.env.TWILIO_ACCOUNT_SID);
  const authToken = clean(process.env.TWILIO_AUTH_TOKEN);
  const from = clean(process.env.TWILIO_FROM);
  const enabled = Boolean(accountSid && authToken && from);

  if (!enabled) {
    warnOnce(
      'twilio:missing',
      'TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, and/or TWILIO_FROM missing. SMS delivery is running in noop mode.'
    );
  }

  return { accountSid, authToken, from, enabled };
}

export function isCommsTestTokenValid(requestToken: string | null): boolean {
  const configuredToken = clean(process.env.COMMS_TEST_TOKEN);

  if (!configuredToken) {
    warnOnce('comms-test-token:missing', 'COMMS_TEST_TOKEN is missing; test route will reject requests.');
    return false;
  }

  return requestToken === configuredToken;
}

export function buildNoopResultMeta(channel: CommsChannel): {
  id: string;
  provider: CommsProviderName;
} {
  return {
    id: `noop-${channel}-${Date.now()}`,
    provider: 'noop',
  };
}
