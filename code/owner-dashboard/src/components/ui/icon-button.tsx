'use client';

import * as React from 'react';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/cn';

const iconBtn = cva(
  [
    'relative inline-flex items-center justify-center rounded-full',
    'transition-colors duration-150 ease-out',
    'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-500',
    'active:scale-95',
    'disabled:opacity-50 disabled:pointer-events-none',
  ],
  {
    variants: {
      size: {
        xs: 'size-7  [&_svg]:size-3.5',
        sm: 'size-[34px] [&_svg]:size-4',
        md: 'size-10 [&_svg]:size-[18px]',
        lg: 'size-12 [&_svg]:size-[22px]',
      },
      variant: {
        ghost:   'bg-transparent text-text hover:bg-bgMuted border border-transparent',
        soft:    'bg-bgMuted text-text border border-transparent',
        outline: 'bg-bgElev text-text border border-borderc',
        glass:   'bg-glass text-text border border-borderc',
        primary: 'bg-brand-500 text-white border border-brand-500',
      },
    },
    defaultVariants: { size: 'md', variant: 'ghost' },
  },
);

export interface IconButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof iconBtn> {
  badge?: number | string;
  label?: string;
}

export const IconButton = React.forwardRef<HTMLButtonElement, IconButtonProps>(
  ({ className, size, variant, badge, label, children, ...rest }, ref) => (
    <button
      ref={ref}
      aria-label={label}
      className={cn(iconBtn({ size, variant }), className)}
      {...rest}
    >
      {children}
      {badge != null && (
        <span className="absolute -top-0.5 -right-0.5 min-w-[16px] h-4 px-1 text-[10px] font-semibold rounded-full bg-danger text-white inline-flex items-center justify-center border-2 border-bg">
          {badge}
        </span>
      )}
    </button>
  ),
);
IconButton.displayName = 'IconButton';
