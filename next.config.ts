import type { NextConfig } from "next";
import createNextIntlPlugin from 'next-intl/plugin';
import { withSentryConfig } from '@sentry/nextjs';

const withNextIntl = createNextIntlPlugin('./i18n/request.ts');

const securityHeaders = [
  { key: 'X-DNS-Prefetch-Control', value: 'on' },
  { key: 'X-Frame-Options', value: 'DENY' },
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'X-Permitted-Cross-Domain-Policies', value: 'none' },
  { key: 'Cross-Origin-Opener-Policy', value: 'same-origin' },
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
  { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
  {
    key: 'Strict-Transport-Security',
    value: 'max-age=63072000; includeSubDomains; preload',
  },
  {
    key: 'Content-Security-Policy',
    value: [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://js.stripe.com",
      "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
      "font-src 'self' https://fonts.gstatic.com",
      "frame-src https://js.stripe.com https://hooks.stripe.com",
      "connect-src 'self' https://*.supabase.co https://gateway.vercel.ai https://*.ingest.sentry.io https://*.sentry.io https://api.stripe.com https://q.stripe.com https://checkout.stripe.com",
      "img-src 'self' data: blob:",
      "object-src 'none'",
      "base-uri 'self'",
      "form-action 'self' https://checkout.stripe.com",
      "frame-ancestors 'none'",
      "worker-src 'self' blob: https://*.sentry.io",
    ].join('; '),
  },
];

const nextConfig: NextConfig = {
  async redirects() {
    return [
      { source: '/dashboard', destination: '/en/dashboard', permanent: false },
      {
        source: '/dashboard/chat/:path*',
        destination: '/en/dashboard',
        permanent: false,
      },
      { source: '/login', destination: '/en/login', permanent: false },
      { source: '/register', destination: '/en/register', permanent: false },
      {
        source: '/onboarding/:path*',
        destination: '/en/onboarding/:path*',
        permanent: false,
      },
    ];
  },
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: securityHeaders,
      },
    ];
  },
};

const sentryConfig = {
  silent: true,
  org: 'dragun',
  project: 'prod-beta',
  authToken: process.env.SENTRY_AUTH_TOKEN,
};

export default withSentryConfig(withNextIntl(nextConfig), sentryConfig);
