'use client';
import { Sidebar } from '@/components/sidebar';
import { StatCard } from '@/components/stat-card';
import { OrdersLive } from '@/components/orders-live';
import { ReviewsRecent } from '@/components/reviews-recent';
import { LiveControl } from '@/components/live-control';
import { Bell, ChevronDown } from 'lucide-react';

export default function DashboardPage() {
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
          </div>
        </header>

        <main className="flex-1 p-6 space-y-6">
          <div>
            <h1 className="text-3xl font-bold">Hôm nay</h1>
            <p className="text-muted-foreground">Cập nhật {new Date().toLocaleDateString('vi-VN')}</p>
          </div>

          {/* Live status quick control */}
          <LiveControl />

          {/* Stats grid */}
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            <StatCard label="Đơn hôm nay"     value="47"        delta="+12%" deltaPositive />
            <StatCard label="Doanh thu"         value="2.4M ₫"    delta="+8%"  deltaPositive />
            <StatCard label="Rating"            value="4.7"       delta="+0.1" deltaPositive />
            <StatCard label="Views profile"     value="1,247"     delta="-3%" />
          </div>

          {/* Live orders + reviews */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <OrdersLive />
            <ReviewsRecent />
          </div>
        </main>
      </div>
    </div>
  );
}
