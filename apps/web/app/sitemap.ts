import type { MetadataRoute } from 'next';

const baseUrl = process.env.NEXT_PUBLIC_URL ?? 'https://www.dragun.app';
const locales = ['en', 'fr'];
const publicPaths = ['', '/pricing', '/features', '/faq', '/about', '/contact', '/legal', '/integrations'];

export default function sitemap(): MetadataRoute.Sitemap {
  const now = new Date();

  return locales.flatMap((locale) =>
    publicPaths.map((path) => ({
      url: `${baseUrl}/${locale}${path}`,
      lastModified: now,
      changeFrequency: 'weekly' as const,
      priority: path === '' ? 1 : 0.7,
    }))
  );
}
