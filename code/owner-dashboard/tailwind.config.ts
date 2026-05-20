import type { Config } from 'tailwindcss';

const config: Config = {
  content: ['./src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        background: 'hsl(var(--background))',
        foreground: 'hsl(var(--foreground))',
        primary: { DEFAULT: '#FF6B2B', foreground: '#FFFFFF' },
        muted: { DEFAULT: 'hsl(var(--muted))', foreground: 'hsl(var(--muted-foreground))' },
        border: 'hsl(var(--border))',
        ring: '#FF6B2B',
        success: '#2D8B5C',
        warning: '#F4B942',
        danger: '#E63946',
      },
      fontFamily: {
        sans: ['Be Vietnam Pro', 'Inter', 'system-ui'],
      },
      borderRadius: {
        lg: '1rem',
        md: '0.625rem',
        sm: '0.5rem',
      },
    },
  },
  plugins: [require('tailwindcss-animate')],
};
export default config;
