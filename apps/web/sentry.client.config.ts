import * as Sentry from '@sentry/nextjs';

Sentry.init({
  dsn: process.env.NEXT_PUBLIC_SENTRY_DSN,

  integrations: [
    Sentry.replayIntegration({
      maskAllText: false,
      blockAllMedia: false,
    }),
    Sentry.browserTracingIntegration(),
  ],

  tracesSampleRate: 1.0,
  replaysSessionSampleRate: 0.1,
  replaysOnErrorSampleRate: 1.0,

  beforeSend(event) {
    if (event.exception?.values?.some(v =>
      v.value?.includes('ResizeObserver') ||
      v.value?.includes('Non-Error promise rejection')
    )) {
      return null;
    }
    return event;
  },

  environment: process.env.NODE_ENV,
  debug: false,
});
