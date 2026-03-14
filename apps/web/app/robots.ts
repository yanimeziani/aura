import type { MetadataRoute } from 'next';

const baseUrl = process.env.NEXT_PUBLIC_URL ?? 'https://www.dragun.app';

export default function robots(): MetadataRoute.Robots {
  return {
    rules: {
      userAgent: '*',
      allow: '/',
      disallow: ['/api/', '/dashboard', '/chat/', '/pay/', '/onboarding', '/login', '/register'],
    },
    sitemap: `${baseUrl}/sitemap.xml`,
    host: baseUrl,
  };
}
