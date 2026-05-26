'use client';

import * as React from 'react';
import { cn } from '@/lib/cn';

interface SliderProps {
  value: number;
  min?: number;
  max?: number;
  step?: number;
  onChange?: (v: number) => void;
  label?: string;
  leading?: React.ReactNode;
  trailing?: React.ReactNode;
}

export function Slider({ value, min = 0, max = 100, step = 1, onChange, label, leading, trailing }: SliderProps) {
  const pct = ((value - min) / (max - min)) * 100;
  return (
    <div className="w-full">
      {label && <div className="text-[12px] text-textMuted mb-1.5">{label}</div>}
      <div className="flex items-center gap-2.5">
        {leading && <span className="text-[14px] text-text">{leading}</span>}
        <div className="relative flex-1 h-6">
          <div className="absolute top-[10px] left-0 right-0 h-1 bg-bgMuted rounded-full" />
          <div
            className="absolute top-[10px] left-0 h-1 bg-brand-500 rounded-full"
            style={{ width: `${pct}%` }}
          />
          <input
            type="range"
            value={value}
            min={min}
            max={max}
            step={step}
            onChange={(e) => onChange?.(Number(e.target.value))}
            className={cn(
              'absolute inset-0 size-full appearance-none bg-transparent cursor-pointer',
              '[&::-webkit-slider-thumb]:appearance-none',
              '[&::-webkit-slider-thumb]:size-5 [&::-webkit-slider-thumb]:rounded-full',
              '[&::-webkit-slider-thumb]:bg-white [&::-webkit-slider-thumb]:border-2 [&::-webkit-slider-thumb]:border-brand-500',
              '[&::-webkit-slider-thumb]:shadow-s2',
              '[&::-moz-range-thumb]:size-5 [&::-moz-range-thumb]:rounded-full',
              '[&::-moz-range-thumb]:bg-white [&::-moz-range-thumb]:border-2 [&::-moz-range-thumb]:border-brand-500',
              '[&::-moz-range-thumb]:shadow-s2',
            )}
          />
        </div>
        {trailing && <span className="text-[14px] text-text tabular-nums">{trailing}</span>}
      </div>
    </div>
  );
}
