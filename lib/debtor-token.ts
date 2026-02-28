import crypto from 'crypto';

const SECRET = process.env.DEBTOR_PORTAL_SECRET || process.env.SUPABASE_SERVICE_ROLE_KEY || 'fallback-dev-secret';
const TOKEN_TTL_DAYS = 14;

export function createDebtorToken(debtorId: string): string {
  const expires = Date.now() + TOKEN_TTL_DAYS * 24 * 60 * 60 * 1000;
  const payload = `${debtorId}:${expires}`;
  const sig = crypto.createHmac('sha256', SECRET).update(payload).digest('hex').slice(0, 32);
  return Buffer.from(`${payload}:${sig}`).toString('base64url');
}

export function verifyDebtorToken(token: string): { debtorId: string } | null {
  try {
    const decoded = Buffer.from(token, 'base64url').toString('utf-8');
    const [debtorId, expiresStr, sig] = decoded.split(':');
    if (!debtorId || !expiresStr || !sig) return null;
    const expires = parseInt(expiresStr, 10);
    if (Date.now() > expires) return null;
    const payload = `${debtorId}:${expiresStr}`;
    const expected = crypto.createHmac('sha256', SECRET).update(payload).digest('hex').slice(0, 32);
    if (!crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(expected))) return null;
    return { debtorId };
  } catch {
    return null;
  }
}

export function buildDebtorPortalUrl(baseUrl: string, debtorId: string, path: 'chat' | 'pay', locale = 'en'): string {
  const token = createDebtorToken(debtorId);
  return `${baseUrl}/${locale}/${path}/${debtorId}?token=${token}`;
}
