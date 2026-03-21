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

const siteUrl = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://nexa.meziani.ai'

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: 'Nexa | Governed Automation for High-Consequence Operations',
  description:
    'Nexa designs and deploys governed automation for collections, compliance, and document-heavy operations without brittle lock-in.',
  openGraph: {
    title: 'Nexa',
    description:
      'Governed automation for operators, systems, and high-consequence workflows.',
    url: siteUrl,
    siteName: 'Nexa',
    locale: 'en_CA',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Nexa',
    description:
      'Governed automation for operators, systems, and high-consequence workflows.',
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
