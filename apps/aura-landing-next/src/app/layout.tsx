import type { Metadata } from 'next'
import { IBM_Plex_Mono, IBM_Plex_Sans, Space_Grotesk } from 'next/font/google'

import './globals.css'

const headlineFont = Space_Grotesk({
  subsets: ['latin'],
  variable: '--font-display',
  display: 'swap',
})

const bodyFont = IBM_Plex_Sans({
  subsets: ['latin'],
  variable: '--font-body',
  weight: ['400', '500', '600', '700'],
  display: 'swap',
})

const monoFont = IBM_Plex_Mono({
  subsets: ['latin'],
  variable: '--font-mono',
  weight: ['400', '500', '600', '700'],
  display: 'swap',
})

export const metadata: Metadata = {
  metadataBase: new URL('https://meziani.ai'),
  title: 'Meziani AI Labs | Sovereign AI Systems',
  description:
    'Landing surface for Meziani AI Labs: sovereign automation, governed AI systems, and Vercel-ready product fronts for serious operators.',
  openGraph: {
    title: 'Meziani AI Labs',
    description:
      'Sovereign automation, governed AI systems, and production-grade landing surfaces for Canadian and MENA operators.',
    url: 'https://meziani.ai',
    siteName: 'Meziani AI Labs',
    locale: 'en_CA',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Meziani AI Labs',
    description:
      'Sovereign automation, governed AI systems, and production-grade landing surfaces for serious operators.',
  },
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="en" className={`${headlineFont.variable} ${bodyFont.variable} ${monoFont.variable}`}>
      <body style={{ fontFamily: 'var(--font-body)', margin: 0 }}>
        {children}
      </body>
    </html>
  )
}
