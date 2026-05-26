'use client';

import * as React from 'react';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/cn';

const card = cva(
  ['rounded-[20px] transition-all duration-150 ease-out'],
  {
    variants: {
      variant: {
        default:  'bg-bgElev border border-borderc shadow-s1',
        raised:   'bg-bgRaised border border-borderc shadow-s2',
        elevated: 'bg-bgElev border border-borderc shadow-s3',
        glass:    'bg-glass border border-borderc shadow-s2',
        flat:     'bg-bgMuted border-0',
        outline:  'bg-transparent border border-borderc',
        dashed:   'bg-transparent border border-dashed border-borderStrong',
        gradient: 'bg-gradient-brand text-white shadow-glow border border-transparent',
        dark:     'bg-neutral-900 text-white border border-neutral-800',
        soft:     'bg-brand-50 border border-brand-500/20 dark:bg-brand-500/15',
      },
      pad: { none: 'p-0', sm: 'p-3', md: 'p-4', lg: 'p-6', xl: 'p-8' },
      hoverable: { true: 'cursor-pointer hover:-translate-y-0.5 hover:shadow-s2', false: '' },
    },
    defaultVariants: { variant: 'default', pad: 'md', hoverable: false },
  },
);

export interface CardProps
  extends React.HTMLAttributes<HTMLDivElement>,
    VariantProps<typeof card> {}

export const Card = React.forwardRef<HTMLDivElement, CardProps>(
  ({ className, variant, pad, hoverable, ...rest }, ref) => (
    <div ref={ref} className={cn(card({ variant, pad, hoverable }), className)} {...rest} />
  ),
);
Card.displayName = 'Card';
