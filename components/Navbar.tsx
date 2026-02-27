'use client';

import { useTranslations, useLocale } from 'next-intl';
import { Link, useRouter, usePathname } from '@/i18n/navigation';
import { useEffect, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { signOut } from '@/app/actions/auth';
import type { User } from '@supabase/supabase-js';
import { Globe, Menu } from 'lucide-react';
import Logo from '@/components/Logo';
import ThemeToggle from '@/components/ThemeToggle';

const links = [
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
  const supabase = createClient();

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

  const switchLocale = (target: 'en' | 'fr') => {
    router.replace(pathname, { locale: target });
  };

  return (
    <header className="sticky top-0 z-50 border-b border-base-300/70 bg-base-100/85 backdrop-blur">
      <div className="app-shell navbar min-h-16 px-0 sm:min-h-20">
        <div className="navbar-start gap-2">
          <div className="dropdown lg:hidden">
            <label tabIndex={0} className="btn btn-ghost btn-square btn-sm" aria-label="Open menu">
              <Menu className="h-5 w-5" />
            </label>
            <ul tabIndex={0} className="menu dropdown-content z-20 mt-3 w-56 rounded-box border border-base-300 bg-base-100 p-2 shadow-lg">
              {links.map((item) => (
                <li key={item.href}>
                  <Link href={item.href}>{t(item.key)}</Link>
                </li>
              ))}
            </ul>
          </div>
          <Link href="/" className="tap-safe inline-flex items-center" aria-label="Dragun home">
            <Logo className="h-8 w-auto sm:h-9" />
          </Link>
        </div>

        <div className="navbar-center hidden lg:flex">
          <ul className="menu menu-horizontal rounded-box border border-base-300/60 bg-base-200/50 px-2 text-sm">
            {links.map((item) => (
              <li key={item.href}>
                <Link href={item.href}>{t(item.key)}</Link>
              </li>
            ))}
          </ul>
        </div>

        <div className="navbar-end gap-1 sm:gap-2">
          <div className="hidden items-center gap-1 rounded-box border border-base-300/70 bg-base-200/60 p-1 sm:flex">
            <Globe className="ml-1 h-3.5 w-3.5 text-base-content/55" />
            <button
              onClick={() => switchLocale('en')}
              className={`btn btn-xs ${locale === 'en' ? 'btn-primary' : 'btn-ghost'}`}
              type="button"
            >
              EN
            </button>
            <button
              onClick={() => switchLocale('fr')}
              className={`btn btn-xs ${locale === 'fr' ? 'btn-primary' : 'btn-ghost'}`}
              type="button"
            >
              FR
            </button>
          </div>

          <ThemeToggle />

          {user ? (
            <>
              <Link href="/dashboard" className="btn btn-sm btn-outline">{t('dashboard')}</Link>
              <button
                onClick={async () => {
                  await signOut();
                  window.location.href = '/';
                }}
                className="btn btn-sm btn-primary"
                type="button"
              >
                {t('signOut')}
              </button>
            </>
          ) : (
            <>
              <Link href="/#demo" className="btn btn-sm btn-ghost hidden sm:inline-flex">{t('watchDemo')}</Link>
              <Link href="/login" className="btn btn-sm btn-primary">{t('startPilot')}</Link>
            </>
          )}
        </div>
      </div>
    </header>
  );
}
