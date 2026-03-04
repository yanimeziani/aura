# Deployment Guide

This repo includes an automated GitHub → Vercel CI/CD pipeline via:

- `.github/workflows/ci.yml`
- `.github/workflows/deploy-vercel.yml`

- Pull Requests to `main` → CI + **Preview deploy**
- Pushes to `main` → CI + **Production deploy**

If you need fallback, manual deployment steps remain below.

## Required GitHub Secrets (for CI/CD)

Add these in **GitHub → Settings → Secrets and variables → Actions**:

- `VERCEL_TOKEN`
- `VERCEL_ORG_ID`
- `VERCEL_PROJECT_ID`

## Minimal Safe Branch Policy

Recommended branch protection for `main`:

- Require pull request before merging
- Require status check: `Lint + Build`
- Block force pushes
- Restrict who can push directly to main

# Manual Deployment Guide

## Prerequisites

1. **Vercel Account** - Sign up at [vercel.com](https://vercel.com)
2. **GitHub Repository Access** - Ensure you have push access to the repository
3. **Vercel CLI** (optional) - Install with `npm i -g vercel`

## Deployment Options

### Option 1: Vercel Dashboard (Recommended)

1. **Import Repository**
   - Go to [Vercel Dashboard](https://vercel.com/dashboard)
   - Click "New Project"
   - Select your GitHub repository
   - Click "Import"

2. **Configure Environment Variables**
   - Go to Project Settings > Environment Variables
   - Add all variables from `ENVIRONMENT.md`:
     ```
     NEXT_PUBLIC_URL
     NEXT_PUBLIC_SUPABASE_URL
     NEXT_PUBLIC_SUPABASE_ANON_KEY
     SUPABASE_SERVICE_ROLE_KEY
      DEBTOR_PORTAL_SECRET
      ARCJET_KEY
      SENTRY_DSN
      NEXT_PUBLIC_SENTRY_DSN
     STRIPE_SECRET_KEY
     STRIPE_WEBHOOK_SECRET
     ```

3. **Deploy**
   - Click "Deploy"
   - Vercel will automatically detect Next.js and use `vercel.json`

### Option 2: Vercel CLI

1. **Login to Vercel**
   ```bash
   vercel login
   ```

2. **Link Project**
   ```bash
   vercel link
   ```

3. **Add Environment Variables**
   ```bash
   vercel env add NEXT_PUBLIC_URL
   vercel env add NEXT_PUBLIC_SUPABASE_URL
   vercel env add NEXT_PUBLIC_SUPABASE_ANON_KEY
   vercel env add SUPABASE_SERVICE_ROLE_KEY
    vercel env add DEBTOR_PORTAL_SECRET
    vercel env add ARCJET_KEY
    vercel env add SENTRY_DSN
    vercel env add NEXT_PUBLIC_SENTRY_DSN
   vercel env add STRIPE_SECRET_KEY
   vercel env add STRIPE_WEBHOOK_SECRET
   ```

4. **Deploy**
   ```bash
   vercel --prod
   ```

## Post-Deployment Checklist

1. **Verify Environment Variables**
   - Check that all 7 environment variables are set correctly
   - Test with `npm run build` locally first

2. **Test Application**
   - Visit your deployed URL
   - Test key features:
     - User authentication
     - Supabase connection
     - Stripe integration
     - AI functionality

3. **Configure Webhook** (if using Stripe)
   - Set up Stripe webhook in production
   - Test webhook endpoint

4. **Setup Custom Domain** (optional)
   - Add custom domain in Vercel dashboard
   - Configure DNS settings

## Automated CI/CD Setup

Once you have deployment working, you can set up automated deployment:

1. **Enable GitHub Integration** in Vercel dashboard
2. **Grant Permissions** for workflow scope
3. **Restore GitHub Actions** from backup

## Troubleshooting

### Common Issues

1. **Build Failures**
   - Check environment variables in Vercel dashboard
   - Verify API keys are valid
   - Test locally with `npm run build`

2. **Environment Variables Not Loading**
   - Ensure variables are set for correct environment (Production/Preview)
   - Check variable names exactly match

3. **CORS Issues**
   - Verify `NEXT_PUBLIC_SUPABASE_URL` uses `https://`
   - Check Supabase CORS settings

### Debug Commands

```bash
# Test build locally
npm run build

# Check environment validation
node -e "require('./lib/env.ts')"

# Deploy with debug output
vercel --debug
```

## Next Steps

1. Deploy using Vercel dashboard or CLI
2. Configure all environment variables
3. Test application functionality
4. Set up custom domain if needed
5. Configure CI/CD once deployment is stable

The application is ready for deployment once environment variables are properly configured.
