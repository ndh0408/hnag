'use client';

import * as React from 'react';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/cn';

const chip = cva(
  [
    'inline-flex items-center gap-1.5 rounded-full border whitespace-nowrap',
    'transition-colors duration-150 ease-out font-medium',
    'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-500',
  ],
  {
    variants: {
      size: {
        sm: 'h-7 px-2.5 text-[12px]',
        md: 'h-9 px-3 text-[13px]',
        lg: 'h-10 px-3.5 text-[14px]',
      },
      active: {
        true:  'bg-text text-bg border-text font-semibold',
        false: 'bg-bgElev text-text border-borderc hover:bg-bgMuted',
      },
    },
    defaultVariants: { size: 'md', active: false },
  },
);

export interface ChipProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof chip> {}

export const Chip = React.forwardRef<HTMLButtonElement, ChipProps>(
  ({ className, size, active, ...rest }, ref) => (
    <button ref={ref} type="button" className={cn(chip({ size, active }), className)} {...rest} />
  ),
);
Chip.displayName = 'Chip';
