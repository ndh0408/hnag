import type { Config } from 'tailwindcss';
import { palette, spacing, radius, shadows, gradients } from './src/lib/tokens';

const config: Config = {
  darkMode: ['class'],
  content: ['./src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        brand: palette.brand,
        chili: palette.chili,
        turmeric: palette.turmeric,
        basil: palette.basil,
        ai: palette.ai,
        info: palette.info,
        neutral: palette.neutral,
        bg:           'rgb(var(--bg) / <alpha-value>)',
        bgRaised:     'rgb(var(--bg-raised) / <alpha-value>)',
        bgSunken:     'rgb(var(--bg-sunken) / <alpha-value>)',
        bgElev:       'rgb(var(--bg-elev) / <alpha-value>)',
        bgMuted:      'rgb(var(--bg-muted) / <alpha-value>)',
        text:         'rgb(var(--text) / <alpha-value>)',
        textMuted:    'rgb(var(--text-muted) / <alpha-value>)',
        textFaint:    'rgb(var(--text-faint) / <alpha-value>)',
        borderc:      'rgb(var(--border) / <alpha-value>)',
        borderStrong: 'rgb(var(--border-strong) / <alpha-value>)',
        divider:      'rgb(var(--divider) / <alpha-value>)',
        success:      palette.basil[500],
        warning:      palette.turmeric[500],
        danger:       palette.chili[500],
      },
      fontFamily: {
        sans:    ['Inter', 'system-ui', 'sans-serif'],
        display: ['Urbanist', 'Inter', 'system-ui', 'sans-serif'],
        mono:    ['JetBrains Mono', 'SF Mono', 'monospace'],
      },
      spacing,
      borderRadius: radius,
      boxShadow: {
        s1: shadows[1], s2: shadows[2], s3: shadows[3], s4: shadows[4],
        glow: shadows.glow, glowAi: shadows.glowAi,
      },
      backgroundImage: {
        'gradient-brand':   gradients.brand,
        'gradient-premium': gradients.premium,
        'gradient-ai':      gradients.ai,
        'gradient-aiVivid': gradients.aiVivid,
        'gradient-night':   gradients.night,
        'gradient-morning': gradients.morning,
        'gradient-basil':   gradients.basil,
        'gradient-aurora':  gradients.aurora,
      },
    },
  },
  plugins: [require('tailwindcss-animate')],
};
export default config;
