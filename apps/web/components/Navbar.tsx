'use client';

import { useTranslations, useLocale } from 'next-intl';
import { Link, useRouter, usePathname } from '@/i18n/navigation';
import { useEffect, useMemo, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { signOut } from '@/app/actions/auth';
import type { User } from '@supabase/supabase-js';
import { Globe, Menu, ArrowRight } from 'lucide-react';
import Logo from '@/components/Logo';
import ThemeToggle from '@/components/ThemeToggle';

const links = [
  { key: 'demo', href: '/demo' },
  { key: 'features', href: '/features' },
  { key: 'pricing', href: '/pricing' },
  { key: 'faq', href: '/faq' },
  { key: 'security', href: '/legal' },
  { key: 'contact', href: '/contact' },
] as const;

export default function Navbar() {
  const t = useTranslations('Navbar');
  const locale = useLocale();
  const router = useRouter();
  const pathname = usePathname();
  const [user, setUser] = useState<User | null>(null);
  const [scrolled, setScrolled] = useState(false);
  const supabase = useMemo(() => createClient(), []);

  useEffect(() => {
    const getUser = async () => {
      const { data } = await supabase.auth.getUser();
      setUser(data.user);
    };
    getUser();

    const { data } = supabase.auth.onAuthStateChange((_event, session) => {
      setUser(session?.user ?? null);
    });

    return () => data.subscription.unsubscribe();
  }, [supabase.auth]);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 10);
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  const switchLocale = (target: 'en' | 'fr') => {
    router.replace(pathname, { locale: target });
  };

  return (
    <header
      className={`sticky top-0 z-50 transition-all duration-300 ${
        scrolled
          ? 'border-b border-base-300/70 bg-base-100/90 backdrop-blur-xl shadow-sm'
          : 'bg-transparent'
      }`}
    >
      <div className="app-shell flex h-16 items-center justify-between sm:h-20">
        {/* Left */}
        <div className="flex items-center gap-3">
          <div className="dropdown lg:hidden">
            <label tabIndex={0} className="btn btn-ghost btn-square h-10 min-h-10" aria-label={t('openMenu')}>
              <Menu className="h-5 w-5" />
            </label>
            <ul tabIndex={0} className="menu dropdown-content z-20 mt-3 w-56 min-w-[min(100vw-2rem,14rem)] max-w-[calc(100vw-2rem)] rounded-2xl border border-base-300 bg-base-100 p-2 shadow-xl right-0 left-auto">
              {links.map((item) => (
                <li key={item.href}>
                  <Link href={item.href} className="text-sm min-h-[44px] flex items-center touch-manipulation">{t(item.key)}</Link>
                </li>
              ))}
              <li className="border-t border-base-300/50 mt-2 pt-2">
                <div className="flex gap-1 px-2 py-1">
                  <span className="text-[10px] font-semibold text-base-content/40 uppercase tracking-wider self-center">Lang</span>
                  <button type="button" onClick={() => switchLocale('en')} className={`flex-1 rounded-lg px-2 py-2 text-xs font-semibold min-h-[40px] touch-manipulation ${locale === 'en' ? 'bg-base-200 text-base-content' : 'text-base-content/50 hover:bg-base-200/60'}`}>EN</button>
                  <button type="button" onClick={() => switchLocale('fr')} className={`flex-1 rounded-lg px-2 py-2 text-xs font-semibold min-h-[40px] touch-manipulation ${locale === 'fr' ? 'bg-base-200 text-base-content' : 'text-base-content/50 hover:bg-base-200/60'}`}>FR</button>
                </div>
              </li>
            </ul>
          </div>
          <Link href="/" className="tap-safe inline-flex items-center" aria-label={t('dragunHome')}>
            <Logo className="h-8 w-auto sm:h-9" />
          </Link>
        </div>

        {/* Center */}
        <nav className="hidden lg:flex">
          <ul className="flex items-center gap-1 rounded-full border border-base-300/50 bg-base-200/40 px-1.5 py-1">
            {links.map((item) => (
              <li key={item.href}>
                <Link
                  href={item.href}
                  className={`rounded-full px-4 py-1.5 text-[13px] font-medium transition-colors ${
                    pathname === item.href
                      ? 'bg-base-100 text-base-content shadow-sm'
                      : 'text-base-content/55 hover:text-base-content'
                  }`}
                >
                  {t(item.key)}
                </Link>
              </li>
            ))}
          </ul>
        </nav>

        {/* Right */}
        <div className="flex items-center gap-2">
          <div className="hidden items-center gap-0.5 rounded-full border border-base-300/50 bg-base-200/40 p-0.5 sm:flex">
            <Globe className="ml-2 h-3 w-3 text-base-content/40" />
            <button
              onClick={() => switchLocale('en')}
              className={`rounded-full px-2.5 py-0.5 text-[11px] font-semibold transition-all ${
                locale === 'en' ? 'bg-base-100 text-base-content shadow-sm' : 'text-base-content/40 hover:text-base-content'
              }`}
              type="button"
            >
              EN
            </button>
            <button
              onClick={() => switchLocale('fr')}
              className={`rounded-full px-2.5 py-0.5 text-[11px] font-semibold transition-all ${
                locale === 'fr' ? 'bg-base-100 text-base-content shadow-sm' : 'text-base-content/40 hover:text-base-content'
              }`}
              type="button"
            >
              FR
            </button>
          </div>

          <ThemeToggle />

          {user ? (
            <>
              <Link href="/dashboard" className="btn btn-sm btn-ghost h-10 min-h-10 px-4 text-sm font-semibold">{t('dashboard')}</Link>
              <button
                onClick={async () => {
                  await signOut();
                  window.location.href = '/';
                }}
                className="btn btn-sm btn-primary h-10 min-h-10 rounded-full px-5"
                type="button"
              >
                {t('signOut')}
              </button>
            </>
          ) : (
            <>
              <Link href="/demo" className="btn btn-sm btn-ghost h-10 min-h-10 hidden sm:inline-flex text-sm text-base-content/55">{t('watchDemo')}</Link>
              <Link href="/login" className="btn btn-sm btn-primary h-10 min-h-10 rounded-full gap-1.5 px-5">
                {t('startPilot')}
                <ArrowRight className="h-4 w-4" />
              </Link>
            </>
          )}
        </div>
      </div>
    </header>
  );
}
