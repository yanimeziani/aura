export function validateEnv() {
  const required = [
    'NEXT_PUBLIC_URL',
    'NEXT_PUBLIC_SUPABASE_URL',
    'NEXT_PUBLIC_SUPABASE_ANON_KEY',
    'SUPABASE_SERVICE_ROLE_KEY',
    'OPENROUTER_API_KEY',
    'GOOGLE_GENERATIVE_AI_API_KEY',
    'STRIPE_SECRET_KEY',
    'STRIPE_WEBHOOK_SECRET',
  ];

  const missing = required.filter((key) => !process.env[key]);

  if (missing.length > 0) {
    throw new Error(
      'Missing required environment variables:\n' + missing.map((m) => ' - ' + m).join('\n')
    );
  }

  // specific checks
  if (!process.env.NEXT_PUBLIC_SUPABASE_URL?.startsWith('https://')) {
     console.warn('NEXT_PUBLIC_SUPABASE_URL should start with https://');
  }
}
