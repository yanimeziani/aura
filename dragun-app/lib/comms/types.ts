export type CommsChannel = 'email' | 'sms';

export type CommsProviderName = 'resend' | 'twilio' | 'noop';

export type CommsTags = string[];

export type CommsMetadata = Record<string, string | number | boolean>;

export type EmailAddress = string | string[];

export interface EmailMessage {
  to: EmailAddress;
  subject: string;
  html?: string;
  text?: string;
  from?: string;
  tags?: CommsTags;
  metadata?: CommsMetadata;
}

export interface SmsMessage {
  to: string;
  body: string;
  from?: string;
  statusCallbackUrl?: string;
  metadata?: CommsMetadata;
}

export interface CommsError {
  provider: CommsProviderName;
  code: string;
  message: string;
  status?: number;
}

export interface CommsSuccess<TRaw = unknown> {
  ok: true;
  channel: CommsChannel;
  provider: CommsProviderName;
  id?: string;
  raw?: TRaw;
}

export interface CommsFailure {
  ok: false;
  channel: CommsChannel;
  provider: CommsProviderName;
  error: CommsError;
}

export type CommsResult<TRaw = unknown> = CommsSuccess<TRaw> | CommsFailure;

export interface EmailProvider {
  readonly name: CommsProviderName;
  send(message: EmailMessage): Promise<CommsResult>;
}

export interface SmsProvider {
  readonly name: CommsProviderName;
  send(message: SmsMessage): Promise<CommsResult>;
}

export type CommsDispatchRequest =
  | {
      channel: 'email';
      payload: EmailMessage;
    }
  | {
      channel: 'sms';
      payload: SmsMessage;
    };
