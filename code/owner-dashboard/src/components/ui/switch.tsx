'use client';

import * as React from 'react';
import { cn } from '@/lib/cn';

interface SwitchProps {
  checked: boolean;
  onChange?: (v: boolean) => void;
  disabled?: boolean;
  className?: string;
  label?: string;
}

export function Switch({ checked, onChange, disabled, className, label }: SwitchProps) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      aria-label={label}
      disabled={disabled}
      onClick={() => onChange?.(!checked)}
      className={cn(
        'relative w-11 h-[26px] shrink-0 rounded-full transition-colors duration-150 ease-out',
        checked ? 'bg-brand-500' : 'bg-bgMuted',
        disabled && 'opacity-50 pointer-events-none',
        className,
      )}
    >
      <span
        className={cn(
          'absolute top-0.5 size-[22px] rounded-full bg-white shadow transition-[left] duration-150 ease-out',
          checked ? 'left-[20px]' : 'left-0.5',
        )}
      />
    </button>
  );
}
