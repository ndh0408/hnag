'use client';

import * as React from 'react';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/cn';

const badge = cva(
  ['inline-flex items-center gap-1 whitespace-nowrap font-medium rounded-full border'],
  {
    variants: {
      size: {
        sm: 'h-5 px-2 text-[11px] tracking-wide',
        md: 'h-6 px-2.5 text-[12px]',
        lg: 'h-7 px-3 text-[13px]',
      },
      variant: {
        default:  'bg-bgMuted text-text border-transparent',
        brand:    'bg-brand-500 text-white border-transparent',
        soft:     'bg-brand-50 text-brand-600 border-transparent dark:bg-brand-500/15 dark:text-brand-300',
        outline:  'bg-transparent text-text border-borderc',
        success:  'bg-basil-500/15 text-basil-600 dark:text-basil-400 border-transparent',
        warning:  'bg-turmeric-500/20 text-turmeric-600 dark:text-turmeric-400 border-transparent',
        danger:   'bg-chili-500/15 text-chili-600 dark:text-chili-400 border-transparent',
        ai:       'bg-ai-500/15 text-ai-600 dark:text-ai-400 border-transparent',
        gradient: 'bg-gradient-brand text-white border-transparent',
        glass:    'bg-white/20 text-white border-white/25',
        dot:      'bg-transparent text-text border-transparent before:content-[\'\'] before:size-1.5 before:rounded-full before:bg-brand-500 before:mr-1',
      },
    },
    defaultVariants: { size: 'md', variant: 'default' },
  },
);

export interface BadgeProps
  extends React.HTMLAttributes<HTMLSpanElement>,
    VariantProps<typeof badge> {}

export const Badge = React.forwardRef<HTMLSpanElement, BadgeProps>(
  ({ className, size, variant, ...rest }, ref) => (
    <span ref={ref} className={cn(badge({ size, variant }), className)} {...rest} />
  ),
);
Badge.displayName = 'Badge';
