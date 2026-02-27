import type { Config } from 'tailwindcss'
import tailwindcssAnimate from 'tailwindcss-animate'
import daisyui from 'daisyui'

const config: Config = {
  darkMode: ['class', '.dark'],
  content: [
    './pages/**/*.{ts,tsx}',
    './components/**/*.{ts,tsx}',
    './app/**/*.{ts,tsx}',
    './src/**/*.{ts,tsx}',
  ],
  theme: {
    container: {
      center: true,
      padding: '1rem',
      screens: { '2xl': '1280px' },
    },
    extend: {
      fontFamily: {
        sans: ['Space Grotesk', 'Inter', 'system-ui', 'sans-serif'],
        mono: ['Geist Mono', 'ui-monospace', 'SFMono-Regular', 'monospace'],
      },
      animation: {
        'fade-up': 'fadeUp 360ms ease both',
      },
      keyframes: {
        fadeUp: {
          '0%': { opacity: '0', transform: 'translateY(10px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
      },
    },
  },
  plugins: [tailwindcssAnimate, daisyui],
  daisyui: {
    themes: [
      {
        dragun: {
          primary: '#0E7490',
          'primary-content': '#EAFBFF',
          secondary: '#1D4ED8',
          'secondary-content': '#EFF6FF',
          accent: '#F59E0B',
          'accent-content': '#221005',
          neutral: '#1F2937',
          'neutral-content': '#F8FAFC',
          'base-100': '#F5F8FC',
          'base-200': '#EAF0F7',
          'base-300': '#D7E2EF',
          'base-content': '#0F172A',
          info: '#0891B2',
          success: '#16A34A',
          warning: '#D97706',
          error: '#DC2626',
        },
      },
      {
        'dragun-dark': {
          primary: '#22D3EE',
          'primary-content': '#052028',
          secondary: '#60A5FA',
          'secondary-content': '#041A3A',
          accent: '#FBBF24',
          'accent-content': '#2A1A03',
          neutral: '#0F172A',
          'neutral-content': '#E2E8F0',
          'base-100': '#0B1220',
          'base-200': '#131C2F',
          'base-300': '#1E293B',
          'base-content': '#E2E8F0',
          info: '#22D3EE',
          success: '#4ADE80',
          warning: '#F59E0B',
          error: '#F87171',
        },
      },
    ],
    darkTheme: 'dragun-dark',
    logs: false,
  },
}

export default config
