import type { Metadata, Viewport } from 'next';
import { NextIntlClientProvider, hasLocale } from 'next-intl';
import { getMessages } from 'next-intl/server';
import { notFound } from 'next/navigation';
import { routing } from '@/i18n/routing';
import '../globals.css';

const baseUrl = process.env.NEXT_PUBLIC_URL ?? 'https://www.dragun.app';

export const viewport: Viewport = {
  themeColor: '#000000',
  width: 'device-width',
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
  viewportFit: 'cover',
};

export const metadata: Metadata = {
  metadataBase: new URL(baseUrl),
  title: 'SOVEREIGN OS // DRAGUN',
  description: 'RAW_COMMAND_INTERFACE',
  manifest: '/manifest.json',
  appleWebApp: {
    capable: true,
    statusBarStyle: 'black-translucent',
    title: 'Sovereign',
  },
};

export default async function LocaleLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  if (!hasLocale(routing.locales, locale)) notFound();

  const messages = await getMessages();

  return (
    <html lang={locale} suppressHydrationWarning>
      <head>
        <meta name="apple-mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
        <link rel="apple-touch-icon" href="/dragun-logo.svg" />
        <script
          dangerouslySetInnerHTML={{
            __html: [
              `if ('serviceWorker' in navigator) {`,
              `  window.addEventListener('load', function() {`,
              `    navigator.serviceWorker.register('/sw.js');`,
              `  });`,
              `}`,
            ].join(''),
          }}
        />
      </head>
      <body className="min-h-screen bg-black text-white selection:bg-white selection:text-black antialiased">
        <NextIntlClientProvider messages={messages}>
          {children}
        </NextIntlClientProvider>
      </body>
    </html>
  );
}
