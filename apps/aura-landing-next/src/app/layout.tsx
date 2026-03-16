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
  metadataBase: new URL('https://nexa.global'),
  title: 'Nexa | Sovereign Agentic Infrastructure',
  description:
    'Nexa is sovereign agentic infrastructure for governed automation, mesh-aware operations, and recovery-first deployment.',
  openGraph: {
    title: 'Nexa',
    description:
      'Sovereign agentic infrastructure for operators, systems, and recovery.',
    url: 'https://nexa.global',
    siteName: 'Nexa',
    locale: 'en_CA',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Nexa',
    description:
      'Sovereign agentic infrastructure for operators, systems, and recovery.',
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
