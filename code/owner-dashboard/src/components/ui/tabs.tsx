'use client';

import * as React from 'react';
import { cn } from '@/lib/cn';

interface TabsProps {
  tabs: string[];
  active: string;
  onChange?: (tab: string) => void;
  variant?: 'underline' | 'segmented';
  className?: string;
}

export function Tabs({ tabs, active, onChange, variant = 'underline', className }: TabsProps) {
  if (variant === 'segmented') {
    return (
      <div className={cn('inline-flex p-1 gap-0.5 bg-bgMuted rounded-[14px]', className)}>
        {tabs.map((t) => (
          <button
            key={t}
            type="button"
            onClick={() => onChange?.(t)}
            className={cn(
              'px-3.5 py-1.5 rounded-[10px] text-[12px] transition-all duration-150',
              t === active
                ? 'bg-bgElev shadow-s1 font-semibold text-text'
                : 'font-medium text-textMuted hover:text-text',
            )}
          >
            {t}
          </button>
        ))}
      </div>
    );
  }
  return (
    <div className={cn('flex gap-6 border-b border-divider', className)}>
      {tabs.map((t) => (
        <button
          key={t}
          type="button"
          onClick={() => onChange?.(t)}
          className={cn(
            'py-3 text-[13px] font-semibold border-b-2 -mb-px transition-colors',
            t === active
              ? 'text-text border-brand-500'
              : 'text-textMuted border-transparent hover:text-text',
          )}
        >
          {t}
        </button>
      ))}
    </div>
  );
}
