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

  const hasAI =
    process.env.GOOGLE_GENERATIVE_AI_API_KEY || process.env.OPENROUTER_API_KEY;
  if (!hasAI) {
    const msg =
      'No AI provider configured. Set at least one of: GOOGLE_GENERATIVE_AI_API_KEY, OPENROUTER_API_KEY';
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
