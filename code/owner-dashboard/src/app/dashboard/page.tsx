import { Sidebar } from '@/components/sidebar';
import { StatCard } from '@/components/stat-card';
import { OrdersLive } from '@/components/orders-live';
import { ReviewsRecent } from '@/components/reviews-recent';
import { LiveControl } from '@/components/live-control';
import { LogoutButton } from '@/components/logout-button';
import { backendJSON } from '@/lib/api';
import { Bell, ChevronDown } from 'lucide-react';

// This page reads the httpOnly auth cookie server-side, so it must be dynamic.
export const dynamic = 'force-dynamic';

type MetricsOverview = {
  ordersToday?: number;
  revenueToday?: number;
  rating?: number;
  profileViews?: number;
};

function fmtVnd(n?: number): string | null {
  if (typeof n !== 'number') return null;
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M ₫`;
  if (n >= 1_000) return `${Math.round(n / 1_000)}k ₫`;
  return `${n} ₫`;
}

export default async function DashboardPage() {
  // REAL CALL: proves the cookie-authenticated proxy pattern end-to-end.
  // Reads `hnag_at` (httpOnly) server-side and sends Authorization: Bearer.
  // Returns null on any failure so the dashboard still renders with fallbacks.
  const metrics = await backendJSON<MetricsOverview>('/v1/owner/metrics/overview');

  const ordersToday = metrics?.ordersToday != null ? String(metrics.ordersToday) : '—';
  const revenueToday = fmtVnd(metrics?.revenueToday) ?? '—';
  const rating = metrics?.rating != null ? metrics.rating.toFixed(1) : '—';
  const profileViews =
    metrics?.profileViews != null ? metrics.profileViews.toLocaleString('vi-VN') : '—';

  return (
    <div className="flex min-h-screen bg-muted/20">
      <Sidebar />
      <div className="flex-1 flex flex-col">
        <header className="h-16 border-b bg-white flex items-center justify-between px-6">
          <div className="flex items-center gap-2">
            <span className="text-lg font-semibold">🍜 Phở Lý Quốc Sư</span>
            <ChevronDown size={16} className="text-muted-foreground" />
          </div>
          <div className="flex items-center gap-4">
            <button className="relative p-2 rounded-full hover:bg-muted">
              <Bell size={18} />
              <span className="absolute top-1 right-1 w-2 h-2 bg-danger rounded-full" />
            </button>
            <div className="w-9 h-9 rounded-full bg-primary/15 flex items-center justify-center font-semibold">H</div>
            <LogoutButton />
          </div>
        </header>

        <main className="flex-1 p-6 space-y-6">
          <div>
            <h1 className="text-3xl font-bold">Hôm nay</h1>
            <p className="text-muted-foreground">Cập nhật {new Date().toLocaleDateString('vi-VN')}</p>
          </div>

          {/* Live status quick control */}
          {/* TODO: wire to backend (PATCH /v1/owner/restaurants/:id/live) */}
          <LiveControl />

          {/* Stats grid — fed by the cookie-authenticated metrics overview call.
              Values fall back to "—" when the backend is unreachable or the
              endpoint isn't deployed yet. Deltas are still placeholder.
              TODO: have the backend return period-over-period deltas. */}
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            <StatCard label="Đơn hôm nay"   value={ordersToday}  delta="+12%" deltaPositive />
            <StatCard label="Doanh thu"     value={revenueToday} delta="+8%"  deltaPositive />
            <StatCard label="Rating"        value={rating}       delta="+0.1" deltaPositive />
            <StatCard label="Views profile" value={profileViews} delta="-3%" />
          </div>

          {/* Live orders + reviews */}
          {/* TODO: wire to backend (GET /v1/owner/orders/live, GET /v1/owner/reviews) */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <OrdersLive />
            <ReviewsRecent />
          </div>
        </main>
      </div>
    </div>
  );
}
