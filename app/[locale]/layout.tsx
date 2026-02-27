import type { Metadata } from 'next';
import { Geist, Geist_Mono, Inter, Space_Grotesk } from 'next/font/google';
import { NextIntlClientProvider, hasLocale } from 'next-intl';
import { getMessages } from 'next-intl/server';
import { notFound } from 'next/navigation';
import { routing } from '@/i18n/routing';
import { Analytics } from '@vercel/analytics/next';
import '../globals.css';

const geistSans = Geist({
  variable: '--font-geist-sans',
  subsets: ['latin'],
  weight: ['400', '500', '600', '700'],
});
const geistMono = Geist_Mono({ variable: '--font-geist-mono', subsets: ['latin'] });
const inter = Inter({ variable: '--font-inter', subsets: ['latin'] });
const spaceGrotesk = Space_Grotesk({ variable: '--font-space-grotesk', subsets: ['latin'] });

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_URL ?? 'https://www.dragun.app'),
  title: 'Dragun.app | Intelligent Debt Recovery',
  description: 'Automated, empathetic, and firm debt recovery powered by AI negotiation workflows.',
  openGraph: {
    title: 'Dragun.app | Intelligent Debt Recovery',
    description: 'Automated, empathetic, and firm debt recovery powered by AI negotiation workflows.',
    url: '/',
    siteName: 'Dragun.app',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Dragun.app | Intelligent Debt Recovery',
    description: 'Automated, empathetic, and firm debt recovery powered by AI negotiation workflows.',
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
    <html lang={locale} data-theme="dragun" suppressHydrationWarning>
      <head>
        <script
          dangerouslySetInnerHTML={{
            __html: [
              `(function(){try{`,
              `var t=localStorage.getItem('theme')||'system';`,
              `var dark=t==='dark'||(t==='system'&&window.matchMedia('(prefers-color-scheme:dark)').matches);`,
              `document.documentElement.setAttribute('data-theme',dark?'dragun-dark':'dragun');`,
              `}catch(e){}})();`,
            ].join(''),
          }}
        />
      </head>
      <body
        className={`${geistSans.variable} ${geistMono.variable} ${inter.variable} ${spaceGrotesk.variable} min-h-screen font-sans antialiased`}
      >
        <NextIntlClientProvider messages={messages}>
          {children}
        </NextIntlClientProvider>
        <Analytics />
      </body>
    </html>
  );
}
