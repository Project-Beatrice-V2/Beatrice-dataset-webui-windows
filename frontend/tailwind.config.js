/** @type {import('tailwindcss').Config} */
// Colours are the "Aurora Void" CSS variables defined in src/index.css, so every
// utility follows the light/dark mode. `<alpha-value>` keeps opacity modifiers
// such as `bg-accent/10` working on top of the variables.
const token = (name) => `color-mix(in srgb, var(${name}) calc(<alpha-value> * 100%), transparent)`

export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        canvas: token('--bg-main'),
        raised: token('--bg-raised'),
        card: 'var(--bg-card)',
        'card-hover': 'var(--bg-card-hover)',
        'card-active': 'var(--bg-card-active)',
        line: 'var(--border-subtle)',
        'line-strong': 'var(--border-hover)',
        hi: token('--text-hi'),
        mid: token('--text-mid'),
        lo: token('--text-lo'),
        accent: token('--accent'),
        accent2: token('--accent2'),
        ok: token('--green'),
        bad: token('--red'),
      },
      fontFamily: {
        sans: ['Geist', '-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'sans-serif'],
        display: ['Geist', '-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'sans-serif'],
        mono: ['Geist Mono', 'SF Mono', 'ui-monospace', 'Consolas', 'monospace'],
      },
      borderRadius: {
        card: '16px',
        ctrl: '10px',
      },
      maxWidth: {
        content: '1120px',
      },
      animation: {
        fadeIn: 'fadeIn 0.4s cubic-bezier(0.16, 1, 0.3, 1) both',
        slideIn: 'slideIn 0.5s cubic-bezier(0.16, 1, 0.3, 1) both',
        breathe: 'breathe 2.4s ease-in-out infinite',
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        slideIn: {
          '0%': { transform: 'translateY(10px)', opacity: '0' },
          '100%': { transform: 'translateY(0)', opacity: '1' },
        },
        breathe: {
          '0%, 100%': { opacity: '0.55' },
          '50%': { opacity: '1' },
        },
      },
    },
  },
  plugins: [],
}
