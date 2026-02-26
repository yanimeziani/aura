'use client';

import { useTranslations, useLocale } from 'next-intl';
import { Link, useRouter, usePathname } from '@/i18n/navigation';
import { useEffect, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { signOut } from '@/app/actions/auth';
import type { User } from '@supabase/supabase-js';
import { Globe } from 'lucide-react';
import Logo from '@/components/Logo';
import ThemeToggle from '@/components/ThemeToggle';

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
    <div className="sticky top-0 z-50 border-b border-border/80 bg-background/90 backdrop-blur-xl">
      <nav className="mx-auto flex w-full max-w-7xl items-center justify-between px-4 py-4 sm:px-6 lg:px-8">
        <Link href="/" className="flex items-center">
          <Logo className="h-8 w-auto" />
        </Link>

        <div className="hidden items-center gap-8 lg:flex">
          {[
            { label: t('features'), href: '/features' },
            { label: t('pricing'), href: '/pricing' },
            { label: t('faq'), href: '/faq' },
            { label: t('security'), href: '/legal' },
            { label: t('contact'), href: '/contact' },
          ].map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="text-[11px] font-semibold uppercase tracking-[0.18em] text-muted-foreground transition-colors hover:text-foreground"
            >
              {item.label}
            </Link>
          ))}
        </div>

        <div className="flex items-center gap-3">
          <div className="hidden items-center gap-2 rounded-xl border border-border bg-card px-3 py-2 sm:flex">
            <Globe className="h-3.5 w-3.5 text-muted-foreground" />
            <button
              onClick={() => switchLocale('en')}
              className={`text-[10px] font-bold uppercase tracking-widest ${locale === 'en' ? 'text-foreground' : 'text-muted-foreground hover:text-foreground'}`}
            >
              EN
            </button>
            <span className="text-muted-foreground">|</span>
            <button
              onClick={() => switchLocale('fr')}
              className={`text-[10px] font-bold uppercase tracking-widest ${locale === 'fr' ? 'text-foreground' : 'text-muted-foreground hover:text-foreground'}`}
            >
              FR
            </button>
          </div>

          <ThemeToggle />

          {user ? (
            <div className="flex items-center gap-2">
              <Link
                href="/dashboard"
                className="inline-flex h-10 items-center rounded-xl border border-border bg-card px-4 text-[11px] font-semibold uppercase tracking-[0.14em] text-foreground hover:bg-accent"
              >
                {t('dashboard')}
              </Link>
              <button
                onClick={async () => {
                  await signOut();
                  window.location.href = '/';
                }}
                className="inline-flex h-10 items-center rounded-xl bg-primary px-4 text-[11px] font-semibold uppercase tracking-[0.14em] text-primary-foreground hover:opacity-90"
              >
                {t('signOut')}
              </button>
            </div>
          ) : (
            <div className="flex items-center gap-2">
              <Link
                href="/#demo"
                className="hidden h-10 items-center rounded-xl border border-border bg-card px-4 text-[11px] font-semibold uppercase tracking-[0.14em] text-foreground hover:bg-accent sm:inline-flex"
              >
                {t('watchDemo')}
              </Link>
              <Link
                href="/login"
                className="inline-flex h-10 items-center rounded-xl bg-primary px-5 text-[11px] font-semibold uppercase tracking-[0.14em] text-primary-foreground hover:opacity-90"
              >
                {t('startPilot')}
              </Link>
            </div>
          )}
        </div>
      </nav>
    </div>
  );
}
