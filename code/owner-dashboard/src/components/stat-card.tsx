import clsx from 'clsx';
import { TrendingUp, TrendingDown, Package, Wallet, Eye, Star, type LucideIcon } from 'lucide-react';

const ICON_MAP: Record<string, LucideIcon> = {
  package: Package, wallet: Wallet, eye: Eye, star: Star,
};

const COLOR_MAP: Record<string, { bg: string; fg: string; numFg: string }> = {
  brand: { bg: 'bg-brand-500/12',    fg: 'text-brand-500',    numFg: 'text-brand-500' },
  basil: { bg: 'bg-basil-500/12',    fg: 'text-basil-600',    numFg: 'text-basil-600' },
  info:  { bg: 'bg-info-500/12',     fg: 'text-info-500',     numFg: 'text-info-500' },
  warn:  { bg: 'bg-turmeric-500/16', fg: 'text-turmeric-600', numFg: 'text-turmeric-600' },
};

export function StatCard({
  label, value, delta, deltaPositive = false, icon = 'package', color = 'brand', sub,
}: {
  label: string;
  value: string;
  delta?: string;
  deltaPositive?: boolean;
  icon?: 'package' | 'wallet' | 'eye' | 'star';
  color?: 'brand' | 'basil' | 'info' | 'warn';
  sub?: string;
}) {
  const Icon = ICON_MAP[icon] ?? Package;
  const c = COLOR_MAP[color];
  return (
    <div className="bg-bgRaised rounded-[20px] border border-borderc p-5 shadow-s1">
      <div className="flex items-start justify-between">
        <div>
          <p className="text-[13px] text-textMuted">{label}</p>
          <div className="flex items-baseline gap-1 mt-1.5">
            <span className={clsx('font-display font-extrabold text-[36px] leading-none tracking-[-0.02em]', c.numFg)}>{value}</span>
            {sub && <span className={clsx('font-display font-bold text-[18px]', c.numFg)}>{sub}</span>}
          </div>
        </div>
        <div className={clsx('size-9 rounded-[10px] grid place-items-center', c.bg, c.fg)}>
          <Icon size={18} />
        </div>
      </div>
      {delta && (
        <div className={clsx('text-[12px] mt-2 flex items-center gap-1.5 font-mono',
          deltaPositive ? 'text-basil-600 dark:text-basil-400' : 'text-chili-600 dark:text-chili-400')}>
          {deltaPositive ? <TrendingUp size={12} /> : <TrendingDown size={12} />}
          {delta}
        </div>
      )}
    </div>
  );
}
