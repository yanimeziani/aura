/**
 * Normalize phone to E.164-like form for Twilio.
 * Strips non-digits; if 10 digits assumes US (+1); if 11 digits and leading 1, keeps as +1XXXXXXXXXX.
 */
export function normalizePhoneToE164(raw: string): string {
  const digits = raw.replace(/\D/g, '');
  if (digits.length === 10) {
    return `+1${digits}`;
  }
  if (digits.length === 11 && digits.startsWith('1')) {
    return `+${digits}`;
  }
  if (digits.length >= 10 && digits.length <= 15) {
    return `+${digits}`;
  }
  return raw.trim();
}
