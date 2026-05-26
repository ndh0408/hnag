// HNAG Hi-Fi Design System — tokens (TypeScript port of design/tokens.jsx)
// Single source of truth shared between web-marketing and owner-dashboard.

export const palette = {
  brand: {
    50:  '#FFF4ED',
    100: '#FFE6D5',
    200: '#FFC9A8',
    300: '#FFA170',
    400: '#FF8043',
    500: '#FF6B2B', // PRIMARY
    600: '#F04E0B',
    700: '#C73C08',
    800: '#9F310F',
    900: '#7F2A10',
    950: '#451104',
  },
  chili:    { 400: '#F26271', 500: '#E63946', 600: '#D02434' },
  turmeric: { 400: '#FFC93D', 500: '#F4B942', 600: '#D49520' },
  basil:    { 400: '#3DB374', 500: '#2D8B5C', 600: '#1F6A45' },
  ai:       { 400: '#C084FC', 500: '#A855F7', 600: '#8B3FE0' },
  info:     { 500: '#4A6FA5', 600: '#385a8c' },
  neutral: {
    0:    '#FFFFFF',
    25:   '#FBFAF7',
    50:   '#F7F5F1',
    100:  '#EFECE5',
    200:  '#E2DED5',
    300:  '#C9C3B6',
    400:  '#A39C8E',
    500:  '#7A7468',
    600:  '#5A554B',
    700:  '#3F3A33',
    800:  '#26231F',
    850:  '#1A1814',
    900:  '#14120F',
    950:  '#0E0B08',
    1000: '#000000',
  },
} as const;

export const semanticLight = {
  bg:           palette.neutral[25],
  bgRaised:     palette.neutral[0],
  bgSunken:     palette.neutral[50],
  bgElev:       palette.neutral[0],
  bgGlass:      'rgba(255,255,255,0.72)',
  bgMuted:      palette.neutral[100],

  text:         palette.neutral[900],
  textMuted:    palette.neutral[600],
  textFaint:    palette.neutral[400],
  textInv:      palette.neutral[0],

  border:       palette.neutral[200],
  borderStrong: palette.neutral[300],
  divider:      palette.neutral[100],

  brand:        palette.brand[500],
  brandFg:      '#FFFFFF',
  brandSoft:    palette.brand[50],

  success:      palette.basil[500],
  warning:      palette.turmeric[500],
  danger:       palette.chili[500],
  ai:           palette.ai[500],
};

export const semanticDark = {
  bg:           palette.neutral[950],
  bgRaised:     palette.neutral[900],
  bgSunken:     palette.neutral[1000],
  bgElev:       palette.neutral[850],
  bgGlass:      'rgba(20,18,15,0.65)',
  bgMuted:      palette.neutral[850],

  text:         '#F5F2EC',
  textMuted:    '#A39C8E',
  textFaint:    '#5A554B',
  textInv:      palette.neutral[950],

  border:       'rgba(255,255,255,0.08)',
  borderStrong: 'rgba(255,255,255,0.14)',
  divider:      'rgba(255,255,255,0.06)',

  brand:        palette.brand[400],
  brandFg:      '#FFFFFF',
  brandSoft:    'rgba(255,107,43,0.12)',

  success:      palette.basil[400],
  warning:      palette.turmeric[400],
  danger:       palette.chili[400],
  ai:           palette.ai[400],
};

export const spacing = {
  0: '0px',  1: '4px',  2: '8px',  3: '12px', 4: '16px',
  5: '20px', 6: '24px', 7: '32px', 8: '40px', 9: '48px',
  10: '64px', 11: '80px', 12: '96px',
} as const;

export const radius = {
  xs: '6px', sm: '10px', md: '14px', lg: '20px',
  xl: '28px', '2xl': '36px', full: '9999px',
} as const;

export const shadows = {
  1: '0 1px 2px rgba(20,18,15,0.04), 0 1px 3px rgba(20,18,15,0.03)',
  2: '0 4px 8px -2px rgba(20,18,15,0.06), 0 2px 4px -1px rgba(20,18,15,0.04)',
  3: '0 12px 24px -8px rgba(20,18,15,0.10), 0 4px 8px -2px rgba(20,18,15,0.06)',
  4: '0 24px 48px -12px rgba(20,18,15,0.14), 0 8px 16px -4px rgba(20,18,15,0.08)',
  glow:   '0 0 40px rgba(255,107,43,0.35), 0 0 16px rgba(255,107,43,0.20)',
  glowAi: '0 0 40px rgba(168,85,247,0.35), 0 0 16px rgba(168,85,247,0.20)',
} as const;

export const motion = {
  spring: 'cubic-bezier(0.34, 1.56, 0.64, 1)',
  out:    'cubic-bezier(0.16, 1, 0.3, 1)',
  inOut:  'cubic-bezier(0.65, 0, 0.35, 1)',
  fast:   '150ms',
  base:   '220ms',
  slow:   '380ms',
  reveal: '600ms',
} as const;

export const gradients = {
  brand:     'linear-gradient(135deg, #FF8043 0%, #FF6B2B 50%, #E63946 100%)',
  brandSoft: 'linear-gradient(135deg, #FFE6D5 0%, #FFC9A8 100%)',
  premium:   'linear-gradient(135deg, #F4B942 0%, #FF6B2B 50%, #E63946 100%)',
  ai:        'linear-gradient(135deg, #A855F7 0%, #FF6B2B 100%)',
  aiVivid:   'linear-gradient(135deg, #8B5CF6 0%, #EC4899 50%, #FF6B2B 100%)',
  night:     'linear-gradient(180deg, #1A1A40 0%, #4A1B5C 100%)',
  morning:   'linear-gradient(135deg, #FFD166 0%, #FF6B2B 100%)',
  basil:     'linear-gradient(135deg, #3DB374 0%, #2D8B5C 100%)',
  aurora:
    'radial-gradient(at 30% 20%, #FF8043 0px, transparent 50%),' +
    'radial-gradient(at 80% 50%, #A855F7 0px, transparent 50%),' +
    'radial-gradient(at 40% 90%, #F4B942 0px, transparent 50%)',
} as const;

export const fonts = {
  display: '"Urbanist", "Inter", -apple-system, BlinkMacSystemFont, sans-serif',
  body:    '"Inter", -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
  mono:    '"JetBrains Mono", "SF Mono", "Cascadia Code", ui-monospace, monospace',
} as const;

export const type = {
  d1:     { fontSize: '56px', lineHeight: 1.05, fontWeight: 800, letterSpacing: '-0.025em', fontFamily: fonts.display },
  d2:     { fontSize: '42px', lineHeight: 1.08, fontWeight: 800, letterSpacing: '-0.024em', fontFamily: fonts.display },
  d3:     { fontSize: '32px', lineHeight: 1.12, fontWeight: 700, letterSpacing: '-0.022em', fontFamily: fonts.display },
  h1:     { fontSize: '26px', lineHeight: 1.18, fontWeight: 700, letterSpacing: '-0.02em',  fontFamily: fonts.display },
  h2:     { fontSize: '22px', lineHeight: 1.22, fontWeight: 700, letterSpacing: '-0.018em', fontFamily: fonts.display },
  h3:     { fontSize: '18px', lineHeight: 1.28, fontWeight: 600, letterSpacing: '-0.014em', fontFamily: fonts.display },
  h4:     { fontSize: '16px', lineHeight: 1.32, fontWeight: 600, letterSpacing: '-0.012em', fontFamily: fonts.display },
  bodyLg: { fontSize: '16px', lineHeight: 1.5,  fontWeight: 400, letterSpacing: '-0.005em', fontFamily: fonts.body },
  body:   { fontSize: '14px', lineHeight: 1.5,  fontWeight: 400, letterSpacing: '-0.003em', fontFamily: fonts.body },
  bodySm: { fontSize: '13px', lineHeight: 1.5,  fontWeight: 400, fontFamily: fonts.body },
  label:  { fontSize: '13px', lineHeight: 1.3,  fontWeight: 500, letterSpacing: '-0.002em', fontFamily: fonts.body },
  labelSm:{ fontSize: '12px', lineHeight: 1.3,  fontWeight: 500, fontFamily: fonts.body },
  micro:  { fontSize: '11px', lineHeight: 1.2,  fontWeight: 500, letterSpacing: '0.02em',  fontFamily: fonts.body },
  caps:   { fontSize: '11px', lineHeight: 1.0,  fontWeight: 600, letterSpacing: '0.08em', textTransform: 'uppercase' as const, fontFamily: fonts.body },
  numLg:  { fontSize: '32px', lineHeight: 1.0,  fontWeight: 700, letterSpacing: '-0.02em', fontFamily: fonts.display, fontFeatureSettings: '"tnum"' as const },
  mono:   { fontSize: '12px', lineHeight: 1.4,  fontWeight: 500, fontFamily: fonts.mono },
} as const;

export type TypeKey = keyof typeof type;

/** Helper: turn a hex into rgba with given alpha */
export function alpha(hex: string, a: number): string {
  const h = hex.replace('#', '');
  const r = parseInt(h.slice(0, 2), 16);
  const g = parseInt(h.slice(2, 4), 16);
  const b = parseInt(h.slice(4, 6), 16);
  return `rgba(${r},${g},${b},${a})`;
}
