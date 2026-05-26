'use client';

import * as React from 'react';
import { cn } from '@/lib/cn';

export interface InputProps extends Omit<React.InputHTMLAttributes<HTMLInputElement>, 'size'> {
  leading?: React.ReactNode;
  trailing?: React.ReactNode;
  inputSize?: 'sm' | 'md';
  error?: string;
}

export const Input = React.forwardRef<HTMLInputElement, InputProps>(
  ({ className, leading, trailing, inputSize = 'md', error, ...rest }, ref) => {
    const h = inputSize === 'md' ? 'h-11' : 'h-9';
    const text = inputSize === 'md' ? 'text-[16px]' : 'text-[14px]';
    return (
      <div className="w-full">
        <div
          className={cn(
            'flex items-center gap-2.5 px-3.5 bg-bgElev rounded-[14px]',
            'border',
            error ? 'border-danger' : 'border-borderc',
            'focus-within:ring-2 focus-within:ring-brand-500/40 focus-within:border-brand-500',
            h,
            className,
          )}
        >
          {leading && <span className="text-textMuted [&_svg]:size-[18px]">{leading}</span>}
          <input
            ref={ref}
            className={cn(
              'flex-1 bg-transparent outline-none placeholder:text-textMuted text-text',
              text,
            )}
            {...rest}
          />
          {trailing}
        </div>
        {error && <p className="mt-1 text-[13px] text-danger">{error}</p>}
      </div>
    );
  },
);
Input.displayName = 'Input';
