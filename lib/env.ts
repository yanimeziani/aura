const REQUIRED_VARS = [
  'NEXT_PUBLIC_URL',
  'NEXT_PUBLIC_SUPABASE_URL',
  'NEXT_PUBLIC_SUPABASE_ANON_KEY',
  'SUPABASE_SERVICE_ROLE_KEY',
  'STRIPE_SECRET_KEY',
  'STRIPE_WEBHOOK_SECRET',
] as const;

const PRODUCTION_VARS = [
  'ARCJET_KEY',
  'SENTRY_DSN',
  'NEXT_PUBLIC_SENTRY_DSN',
] as const;

export function validateEnv() {
  const isProduction = process.env.NODE_ENV === 'production';
  const required = isProduction
    ? [...REQUIRED_VARS, ...PRODUCTION_VARS]
    : [...REQUIRED_VARS];

  const missing = required.filter((key) => !process.env[key]);

  if (missing.length > 0) {
    throw new Error(
      `Missing required environment variables:\n${missing.map((m) => `  - ${m}`).join('\n')}`
    );
  }

  if (
    process.env.NEXT_PUBLIC_SUPABASE_URL &&
    !process.env.NEXT_PUBLIC_SUPABASE_URL.startsWith('https://')
  ) {
    throw new Error('NEXT_PUBLIC_SUPABASE_URL must start with https://');
  }

  const provider = (process.env.AI_PROVIDER ?? 'groq').toLowerCase();
  const hasGroq = !!process.env.GROQ_API_KEY;
  const hasAI = hasGroq || provider === 'local';
  if (!hasAI) {
    const msg =
      provider === 'local'
        ? 'AI_PROVIDER=local requires a local server (e.g. Ollama). Set LOCAL_API_BASE_URL if not http://127.0.0.1:11434/v1.'
        : 'No AI provider configured. Set GROQ_API_KEY or use AI_PROVIDER=local with a local server.';
    if (isProduction) throw new Error(msg);
    console.warn(`[env] ${msg}`);
  }

  if (!isProduction) {
    const optionalMissing = PRODUCTION_VARS.filter((key) => !process.env[key]);
    if (optionalMissing.length > 0) {
      console.warn(
        `[env] Missing production-only vars (ok in dev):\n${optionalMissing.map((m) => `  - ${m}`).join('\n')}`
      );
    }
  }
}
