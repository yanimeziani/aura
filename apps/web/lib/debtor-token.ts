import crypto from 'crypto';

const _secret = process.env.DEBTOR_PORTAL_SECRET;
if (!_secret || _secret.length < 32) {
  if (process.env.NODE_ENV === 'production') {
    throw new Error('DEBTOR_PORTAL_SECRET must be set (min 32 chars) in production');
  }
}
// Dev-only fallback — never reaches production due to guard above
const SECRET = _secret || 'dev-only-fallback-not-for-production-use-32c';

const TOKEN_TTL_MS = 24 * 60 * 60 * 1000; // 1 day

export function createDebtorToken(debtorId: string): string {
  const expires = Date.now() + TOKEN_TTL_MS;
  const payload = `${debtorId}:${expires}`;
  // Full 256-bit HMAC — no truncation
  const sig = crypto.createHmac('sha256', SECRET).update(payload).digest('hex');
  return Buffer.from(`${payload}:${sig}`).toString('base64url');
}

export function verifyDebtorToken(token: string): { debtorId: string } | null {
  try {
    const decoded = Buffer.from(token, 'base64url').toString('utf-8');
    const parts = decoded.split(':');
    if (parts.length < 3) return null;
    // sig is last part; debtorId and expires are first two
    const sig = parts[parts.length - 1];
    const expiresStr = parts[parts.length - 2];
    const debtorId = parts.slice(0, parts.length - 2).join(':');
    if (!debtorId || !expiresStr || !sig) return null;
    const expires = parseInt(expiresStr, 10);
    if (!Number.isFinite(expires) || Date.now() > expires) return null;
    const payload = `${debtorId}:${expiresStr}`;
    const expected = crypto.createHmac('sha256', SECRET).update(payload).digest('hex');
    // Constant-time compare — same length guaranteed (both full hex)
    if (!crypto.timingSafeEqual(Buffer.from(sig, 'hex'), Buffer.from(expected, 'hex'))) return null;
    return { debtorId };
  } catch {
    return null;
  }
}

export function buildDebtorPortalUrl(baseUrl: string, debtorId: string, path: 'chat' | 'pay', locale = 'en'): string {
  const token = createDebtorToken(debtorId);
  return `${baseUrl}/${locale}/${path}/${debtorId}?token=${token}`;
}
