'use client';

import * as React from 'react';
import { cn } from '@/lib/cn';

export type AvatarStatus = 'online' | 'away' | 'busy' | 'offline';

interface AvatarProps {
  name: string;
  size?: number;
  src?: string;
  ring?: boolean;
  ringColor?: string;
  status?: AvatarStatus;
  className?: string;
}

const STATUS_COLOR: Record<AvatarStatus, string> = {
  online:  '#3DB374',
  away:    '#F4B942',
  busy:    '#E63946',
  offline: '#7A7468',
};

export function Avatar({ name, size = 40, src, ring, ringColor = '#FF6B2B', status, className }: AvatarProps) {
  const initial = (name?.[0] ?? '?').toUpperCase();
  const hue = (name ?? '').split('').reduce((a, c) => a + c.charCodeAt(0), 0) % 360;
  const bg = `linear-gradient(135deg, hsl(${hue} 70% 65%), hsl(${(hue + 40) % 360} 70% 55%))`;
  return (
    <div
      className={cn('relative inline-flex shrink-0', className)}
      style={{ width: size, height: size }}
    >
      <div
        className="size-full overflow-hidden rounded-full flex items-center justify-center text-white font-bold"
        style={{
          background: src ? '#000' : bg,
          fontSize: size * 0.4,
          border: ring ? `2px solid ${ringColor}` : undefined,
          boxShadow: ring ? '0 0 0 2px rgb(var(--bg))' : undefined,
        }}
      >
        {src ? <img src={src} alt={name} className="size-full object-cover" /> : initial}
      </div>
      {status && (
        <span
          className="absolute -bottom-0.5 -right-0.5 rounded-full border-2 border-bg"
          style={{ width: size * 0.32, height: size * 0.32, background: STATUS_COLOR[status] }}
        />
      )}
    </div>
  );
}

interface AvatarStackProps {
  names: string[];
  size?: number;
  max?: number;
  overlap?: number;
}

export function AvatarStack({ names, size = 28, max = 4, overlap = 8 }: AvatarStackProps) {
  const shown = names.slice(0, max);
  const extra = names.length - shown.length;
  return (
    <div className="inline-flex items-center">
      {shown.map((n, i) => (
        <div key={i} style={{ marginLeft: i === 0 ? 0 : -overlap, zIndex: shown.length - i }}>
          <Avatar name={n} size={size} ring ringColor="#FFFFFF" />
        </div>
      ))}
      {extra > 0 && (
        <span
          className="inline-flex items-center justify-center bg-bgElev border border-borderc rounded-full text-[12px] font-medium px-2 text-text"
          style={{ marginLeft: -overlap, height: size }}
        >
          +{extra}
        </span>
      )}
    </div>
  );
}
