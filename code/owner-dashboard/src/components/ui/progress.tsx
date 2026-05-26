'use client';

import * as React from 'react';
import { cn } from '@/lib/cn';

interface ProgressProps {
  value: number;
  max?: number;
  className?: string;
  color?: string;
  height?: number;
}

export function Progress({ value, max = 100, className, color, height = 6 }: ProgressProps) {
  const pct = Math.max(0, Math.min(100, (value / max) * 100));
  return (
    <div
      className={cn('w-full bg-bgMuted overflow-hidden', className)}
      style={{ height, borderRadius: height / 2 }}
    >
      <div
        className="h-full transition-[width] duration-300 ease-out"
        style={{
          width: `${pct}%`,
          background: color ?? 'rgb(var(--brand, 255 107 43))',
          backgroundColor: color ?? '#FF6B2B',
          borderRadius: height / 2,
        }}
      />
    </div>
  );
}

export function StatusDot({ status = 'online', size = 8 }: { status?: 'online' | 'away' | 'busy' | 'offline'; size?: number }) {
  const colors = { online: '#3DB374', away: '#F4B942', busy: '#E63946', offline: '#7A7468' };
  return (
    <span
      className="inline-block rounded-full"
      style={{ width: size, height: size, background: colors[status] }}
    />
  );
}
