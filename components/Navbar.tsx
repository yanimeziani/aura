'use client';

import { useTranslations, useLocale } from 'next-intl';
import { Link, useRouter, usePathname } from '@/i18n/navigation';
import { useEffect, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { signOut } from '@/app/actions/auth';
import { User } from '@supabase/supabase-js';
import { Globe } from 'lucide-react';

export default function Navbar() {
  const t = useTranslations('Navbar');
  const locale = useLocale();
  const router = useRouter();
  const pathname = usePathname();
  const [user, setUser] = useState<User | null>(null);
  const supabase = createClient();

  useEffect(() => {
    const getUser = async () => {
      const { data: { user } } = await supabase.auth.getUser();
      setUser(user);
    };
    getUser();

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setUser(session?.user ?? null);
    });

    return () => subscription.unsubscribe();
  }, [supabase.auth]);

  const isFrench = locale === 'fr';

  const switchLocale = (target: 'en' | 'fr') => {
    router.replace(pathname, { locale: target });
  };

  return (
    <div className="fixed top-0 left-0 right-0 z-50 px-6 py-8 pointer-events-none pt-[env(safe-area-inset-top,2rem)] pl-[env(safe-area-inset-left,1.5rem)] pr-[env(safe-area-inset-right,1.5rem)]">
      <nav className="max-w-7xl mx-auto flex justify-between items-center px-8 py-4 rounded-[2rem] border border-[rgba(255,255,255,0.08)] bg-[#050A14]/80 backdrop-blur-xl shadow-[0_20px_50px_rgba(5,10,20,0.7)] pointer-events-auto">
        <Link href="/" className="flex items-center gap-3 group">
          <div className="w-10 h-10 bg-gradient-to-br from-[#1B2333] to-[#0D1520] border border-white/10 rounded-xl flex items-center justify-center font-bold text-white shadow-2xl relative transition-all group-hover:scale-110 group-hover:border-accent-indigo/60">
            <div className="absolute inset-0 bg-accent-indigo/10 blur-lg opacity-0 group-hover:opacity-100 transition-opacity" />
            <span className="relative z-10 text-[10px] font-black uppercase tracking-tighter">DRGN</span>
          </div>
          <span className="text-xl font-black tracking-[0.2em] text-text-primary uppercase hidden sm:block">
            DRAGUN<span className="text-accent-indigo">.</span>
          </span>
        </Link>

        <div className="hidden lg:flex items-center gap-10">
          {[
            { label: t('features'), href: '/features' },
            { label: t('pricing'), href: '/pricing' },
            { label: t('faq'), href: '/faq' },
            { label: t('contact'), href: '/contact' },
          ].map((link) => (
            <Link 
              key={link.href} 
              href={link.href} 
              className="text-[10px] font-black uppercase tracking-[0.3em] text-text-muted hover:text-accent-indigo transition-all"
            >
              {link.label}
            </Link>
          ))}
        </div>

        <div className="flex items-center gap-6">
          <div className="hidden sm:flex items-center gap-4 px-4 py-2 rounded-full bg-white/[0.03] border border-white/10">
             <Globe className="w-3.5 h-3.5 text-text-muted" />
             <div className="flex items-center gap-2 text-[9px] font-black uppercase tracking-widest">
                <button
                  onClick={() => switchLocale('en')}
                  className={`transition-colors ${!isFrench ? 'text-accent-indigo' : 'text-text-muted hover:text-text-primary'}`}
                >
                  EN
                </button>
                <span className="text-white/20">|</span>
                <button
                  onClick={() => switchLocale('fr')}
                  className={`transition-colors ${isFrench ? 'text-accent-indigo' : 'text-text-muted hover:text-text-primary'}`}
                >
                  FR
                </button>
             </div>
          </div>

          {user ? (
            <div className="flex items-center gap-3">
              <Link 
                href="/dashboard" 
                className="h-10 px-6 rounded-xl bg-white/[0.05] border border-white/10 text-[10px] font-black uppercase tracking-widest text-text-primary hover:bg-white/10 transition-all flex items-center"
              >
                {t('dashboard')}
              </Link>
              <button
                onClick={async () => {
                  await signOut();
                  window.location.href = '/';
                }}
                className="h-10 px-6 rounded-xl bg-accent-indigo text-white text-[10px] font-black uppercase tracking-widest hover:bg-accent-indigo-hover transition-all shadow-xl shadow-glow-indigo"
              >
                {t('signOut')}
              </button>
            </div>
          ) : (
            <Link 
              href="/login" 
              className="h-10 px-8 rounded-xl bg-accent-indigo text-white text-[10px] font-black uppercase tracking-[0.2em] hover:bg-accent-indigo-hover transition-all shadow-2xl flex items-center"
            >
              {t('signIn')}
            </Link>
          )}
        </div>
      </nav>
    </div>
  );
}
