import clsx from 'clsx';
import { TrendingUp, TrendingDown } from 'lucide-react';

export function StatCard({
  label, value, delta, deltaPositive = false,
}: {
  label: string; value: string; delta?: string; deltaPositive?: boolean;
}) {
  return (
    <div className="bg-white rounded-lg border p-5">
      <p className="text-sm text-muted-foreground">{label}</p>
      <p className="text-2xl font-bold mt-1">{value}</p>
      {delta && (
        <div className={clsx('text-xs mt-2 flex items-center gap-1',
          deltaPositive ? 'text-success' : 'text-danger')}>
          {deltaPositive ? <TrendingUp size={12} /> : <TrendingDown size={12} />}
          {delta} so với hôm qua
        </div>
      )}
    </div>
  );
}
