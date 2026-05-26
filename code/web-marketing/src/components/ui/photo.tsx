'use client';

import * as React from 'react';
import { cn } from '@/lib/cn';

const FOOD_GRADIENTS: Record<string, string> = {
  pho:     'linear-gradient(135deg, #D4651C, #8B3A0B)',
  bunbo:   'linear-gradient(135deg, #E63946, #8B1A23)',
  comga:   'linear-gradient(135deg, #F4B942, #C68820)',
  banhmi:  'linear-gradient(135deg, #E8B86A, #A67841)',
  bunch:   'linear-gradient(135deg, #FF8043, #C73C08)',
  comtam:  'linear-gradient(135deg, #FFD166, #E89020)',
  goicuon: 'linear-gradient(135deg, #8FCB9C, #3DB374)',
  banhxeo: 'linear-gradient(135deg, #FFC93D, #D49520)',
  lau:     'linear-gradient(135deg, #D02434, #7B1421)',
  chao:    'linear-gradient(135deg, #F7F5F1, #C9C3B6)',
  mi:      'linear-gradient(135deg, #E89020, #9F310F)',
  che:     'linear-gradient(135deg, #EC4899, #A92160)',
  caphe:   'linear-gradient(135deg, #6B4226, #2E1810)',
  trasua:  'linear-gradient(135deg, #DFC4A3, #8B6F4E)',
  sushi:   'linear-gradient(135deg, #F26271, #C73C08)',
  pizza:   'linear-gradient(135deg, #FF8043, #D02434)',
};
export const FOOD_GRADIENT_KEYS = Object.keys(FOOD_GRADIENTS);

interface PhotoProps {
  src?: string;
  alt?: string;
  foodSlug?: string;
  gradient?: string;
  className?: string;
  aspect?: string; // CSS aspect-ratio value, e.g. '1', '16/9'
  width?: number | string;
  height?: number | string;
  label?: string;
  children?: React.ReactNode;
  rounded?: 'sm' | 'md' | 'lg' | 'xl' | 'full' | 'none';
}

const ROUNDED: Record<NonNullable<PhotoProps['rounded']>, string> = {
  none: 'rounded-none', sm: 'rounded-[10px]', md: 'rounded-[14px]',
  lg: 'rounded-[20px]', xl: 'rounded-[28px]', full: 'rounded-full',
};

export function Photo({
  src, alt = '', foodSlug, gradient, className, aspect = '1',
  width, height, label, children, rounded = 'md',
}: PhotoProps) {
  const bg = gradient
    ?? (foodSlug ? FOOD_GRADIENTS[foodSlug] : null)
    ?? `repeating-linear-gradient(135deg, rgba(20,18,15,0.04) 0 10px, transparent 10px 12px), #EFECE5`;

  return (
    <div
      className={cn('relative overflow-hidden flex items-center justify-center', ROUNDED[rounded], className)}
      style={{ aspectRatio: aspect, background: src ? '#000' : bg, width, height }}
    >
      {src && <img src={src} alt={alt} className="size-full object-cover absolute inset-0" />}
      {label && !children && (
        <span className="font-mono text-[11px] text-black/60 bg-white/70 rounded px-2 py-1">
          {label}
        </span>
      )}
      {children}
    </div>
  );
}
