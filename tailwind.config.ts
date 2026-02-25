import type { Config } from 'tailwindcss';

const config: Config = {
  content: [
    './app/**/*.{js,ts,jsx,tsx}',
    './components/**/*.{js,ts,jsx,tsx}',
  ],
  theme: {
    extend: {
      colors: {
        bg: '#050A14',
        surface: '#0D1520',
        'accent-indigo': '#6366F1',
        'accent-emerald': '#10B981',
        'accent-red': '#EF4444',
        'text-primary': '#F8FAFC',
        'text-muted': '#94A3B8',
      },
      fontFamily: {
        sans: ['Inter', 'sans-serif'],
        display: ['Space Grotesk', 'sans-serif'],
        mono: ['Space Mono', 'monospace'],
      },
      borderRadius: {
        card: '16px',
        lg: '24px',
      },
      boxShadow: {
        'glow-indigo': '0 0 40px rgba(99, 102, 241, 0.15)',
        'glow-emerald': '0 0 40px rgba(16, 185, 129, 0.15)',
      },
    },
  },
  plugins: [require('daisyui')],
};

export default config;
