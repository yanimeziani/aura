'use client';

import { useEffect, useState } from 'react';
import { Sun, Moon, Monitor } from 'lucide-react';

type Theme = 'light' | 'dark' | 'system';

function resolveTheme(value: Theme): 'dragun' | 'dragun-dark' {
  if (value === 'dark') return 'dragun-dark';
  if (value === 'light') return 'dragun';
  if (typeof window !== 'undefined' && window.matchMedia('(prefers-color-scheme: dark)').matches) {
    return 'dragun-dark';
  }
  return 'dragun';
}

function applyTheme(value: Theme) {
  document.documentElement.setAttribute('data-theme', resolveTheme(value));
}

export default function ThemeToggle() {
  const [theme, setTheme] = useState<Theme>('system');

  useEffect(() => {
    const saved = (localStorage.getItem('theme') as Theme) || 'system';
    setTheme(saved);
    applyTheme(saved);

    const media = window.matchMedia('(prefers-color-scheme: dark)');
    const handleSystemChange = () => {
      const current = (localStorage.getItem('theme') as Theme) || 'system';
      if (current === 'system') applyTheme('system');
    };
    media.addEventListener('change', handleSystemChange);
    return () => media.removeEventListener('change', handleSystemChange);
  }, []);

  const cycle = () => {
    const order: Theme[] = ['system', 'dark', 'light'];
    const next = order[(order.indexOf(theme) + 1) % order.length];
    setTheme(next);
    localStorage.setItem('theme', next);
    applyTheme(next);
  };

  const icons = { light: Moon, dark: Sun, system: Monitor };
  const Icon = icons[theme];

  return (
    <button
      type="button"
      onClick={cycle}
      className="btn btn-ghost btn-square h-10 min-h-10 w-10"
      aria-label={`Theme: ${theme}. Click to switch.`}
      title={`Theme: ${theme}`}
    >
      <Icon className="h-4 w-4" />
    </button>
  );
}
