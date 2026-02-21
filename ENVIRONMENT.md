# Environment Variables Configuration

This document outlines all environment variables required for the Dragun application and how to configure them for local development, Vercel deployment, and CI/CD.

## Required Environment Variables

### Production & Development
| Variable | Type | Description | Example |
|----------|------|-------------|---------|
| `NEXT_PUBLIC_URL` | Public | Base URL of your application | `https://dragun.vercel.app` |
| `NEXT_PUBLIC_SUPABASE_URL` | Public | Supabase project URL | `https://xyzabcd.supabase.co` |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Public | Supabase anonymous key | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` |
| `SUPABASE_SERVICE_ROLE_KEY` | Private | Supabase service role key | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` |
| `GOOGLE_GENERATIVE_AI_API_KEY` | Private | Google Gemini API key | `AIzaSyBxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |
| `STRIPE_SECRET_KEY` | Private | Stripe secret key | `sk_test_51xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |
| `STRIPE_WEBHOOK_SECRET` | Private | Stripe webhook signing secret | `whsec_1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |

## Local Development Setup

### Option 1: Environment Variables File
Create a `.env.local` file in your project root:

```bash
NEXT_PUBLIC_URL=http://localhost:3000
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
GOOGLE_GENERATIVE_AI_API_KEY=your_google_api_key
STRIPE_SECRET_KEY=your_stripe_secret_key
STRIPE_WEBHOOK_SECRET=your_webhook_secret
```

### Option 2: Command Line
```bash
export NEXT_PUBLIC_URL=http://localhost:3000
export NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
export NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
export SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
export GOOGLE_GENERATIVE_AI_API_KEY=your_google_api_key
export STRIPE_SECRET_KEY=your_stripe_secret_key
export STRIPE_WEBHOOK_SECRET=your_webhook_secret
```

## Vercel Deployment

### 1. Environment Variables in Vercel Dashboard
1. Go to your Vercel project dashboard
2. Navigate to **Settings** > **Environment Variables**
3. Add each required variable with the appropriate value
4. Make sure to set the correct scope (Preview, Production, or both)

### 2. Environment Variables in vercel.json
The `vercel.json` file already includes environment variable mappings. Replace the placeholders with actual values or Vercel environment variable references:

```json
{
  "env": {
    "NEXT_PUBLIC_URL": "https://your-domain.vercel.app",
    "NEXT_PUBLIC_SUPABASE_URL": "@supabase_url",
    "NEXT_PUBLIC_SUPABASE_ANON_KEY": "@supabase_anon_key",
    "SUPABASE_SERVICE_ROLE_KEY": "@supabase_service_role_key",
    "GOOGLE_GENERATIVE_AI_API_KEY": "@google_generative_ai_api_key",
    "STRIPE_SECRET_KEY": "@stripe_secret_key",
    "STRIPE_WEBHOOK_SECRET": "@stripe_webhook_secret"
  }
}
```

## CI/CD Configuration

### GitHub Secrets
Add the following secrets to your GitHub repository:

- `VERCEL_TOKEN`: Your Vercel deployment token
- `ORG_ID`: Your Vercel organization ID
- `PROJECT_ID`: Your Vercel project ID

### Environment Variables in CI/CD
The GitHub Actions workflow automatically uses environment variables defined in:
1. Vercel project settings
2. GitHub repository secrets
3. Environment-specific configurations

## Validation

The application includes environment validation in `lib/env.ts`. To test your configuration:

```bash
npm run build
```

If any required environment variables are missing, the build will fail with a detailed error message.

## Security Considerations

1. **Never commit environment variables** to version control
2. **Use different values** for development, staging, and production
3. **Regularly rotate** API keys and secrets
4. **Limit access** to sensitive environment variables
5. **Use Vercel's environment variable scopes** to control environment-specific access

## Troubleshooting

### Common Issues

1. **Missing Environment Variables**: Ensure all required variables are set in both local development and Vercel
2. **CORS Issues**: Verify `NEXT_PUBLIC_SUPABASE_URL` uses `https://` in production
3. **Build Failures**: Check environment validation during CI/CD pipeline execution
4. **Vercel Deployment Issues**: Verify GitHub secrets are correctly configured

### Debug Commands

```bash
# Check environment variables
npm run build

# Run with verbose output
npm run build -- --verbose

# Check environment validation
node -e "require('./lib/env.ts')"
```

## Next Steps

1. Set up environment variables for your specific deployment
2. Test local development with proper environment configuration
3. Configure Vercel project environment variables
4. Test CI/CD pipeline with GitHub Actions
5. Validate application functionality in all environments