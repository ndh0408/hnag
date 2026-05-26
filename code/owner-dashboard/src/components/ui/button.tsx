// HnagButton — TSX port of design/primitives.jsx#Btn.
// Variants and sizes 1:1 with the Flutter HnagButton.

'use client';

import * as React from 'react';
import { cva, type VariantProps } from 'class-variance-authority';
import { Slot } from '@radix-ui/react-slot';
import { cn } from '@/lib/cn';

const button = cva(
  [
    'inline-flex items-center justify-center gap-2',
    'whitespace-nowrap select-none cursor-pointer',
    'transition-[transform,box-shadow,background] duration-150 ease-out',
    'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-500 focus-visible:ring-offset-2',
    'active:scale-[0.97]',
    'disabled:opacity-50 disabled:pointer-events-none',
    'font-semibold',
  ],
  {
    variants: {
      size: {
        xs: 'h-7 px-2.5 text-[12px] rounded-[10px] gap-1.5',
        sm: 'h-[34px] px-3 text-[13px] rounded-[10px] gap-1.5',
        md: 'h-10 px-4 text-[13px] rounded-[14px] gap-1.5',
        lg: 'h-12 px-5 text-[16px] rounded-[14px] gap-2',
        xl: 'h-14 px-6 text-[17px] rounded-[20px] gap-2',
      },
      variant: {
        primary:   'bg-brand-500 text-white border border-brand-500 shadow-s2',
        gradient:  'bg-gradient-brand text-white border border-transparent shadow-glow',
        secondary: 'bg-bgElev text-text border border-borderc shadow-s1',
        ghost:     'bg-transparent text-text border border-transparent hover:bg-bgMuted',
        outline:   'bg-transparent text-text border border-borderStrong',
        soft:      'bg-brand-50 text-brand-600 border border-transparent dark:bg-brand-500/15 dark:text-brand-300',
        danger:    'bg-danger text-white border border-danger shadow-s2',
        success:   'bg-success text-white border border-success shadow-s2',
        glass:     'bg-glass text-text border border-borderc shadow-s2',
        dark:      'bg-neutral-900 text-white border border-neutral-800',
      },
      full: { true: 'w-full', false: '' },
    },
    defaultVariants: { size: 'md', variant: 'primary', full: false },
  },
);

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof button> {
  asChild?: boolean;
  iconLeading?: React.ReactNode;
  iconTrailing?: React.ReactNode;
  loading?: boolean;
}

export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, size, variant, full, iconLeading, iconTrailing, loading, asChild, children, disabled, ...rest }, ref) => {
    const Comp: any = asChild ? Slot : 'button';
    return (
      <Comp
        ref={ref}
        className={cn(button({ size, variant, full }), className)}
        disabled={disabled || loading}
        {...rest}
      >
        {loading ? (
          <span className="inline-block size-4 rounded-full border-2 border-current border-r-transparent animate-spin" />
        ) : (
          iconLeading
        )}
        {children}
        {iconTrailing}
      </Comp>
    );
  },
);
Button.displayName = 'Button';
