'use client';

import * as React from 'react';
import { cn } from '@/lib/cn';

interface ListItemProps {
  title: string;
  subtitle?: string;
  leading?: React.ReactNode;
  trailing?: React.ReactNode;
  onClick?: () => void;
  danger?: boolean;
  className?: string;
}

export function ListItem({ title, subtitle, leading, trailing, onClick, danger, className }: ListItemProps) {
  const Comp: any = onClick ? 'button' : 'div';
  return (
    <Comp
      onClick={onClick}
      type={onClick ? 'button' : undefined}
      className={cn(
        'w-full flex items-center gap-3 px-3.5 py-3 rounded-[14px] text-left',
        onClick && 'hover:bg-bgMuted transition-colors duration-150',
        className,
      )}
    >
      {leading && (
        <div className="size-9 shrink-0 rounded-[10px] bg-bgMuted flex items-center justify-center text-textMuted [&_svg]:size-[18px]">
          {leading}
        </div>
      )}
      <div className="flex-1 min-w-0">
        <div className={cn('text-[14px] font-medium', danger ? 'text-danger' : 'text-text')}>
          {title}
        </div>
        {subtitle && <div className="text-[13px] text-textMuted mt-0.5">{subtitle}</div>}
      </div>
      {trailing}
    </Comp>
  );
}
