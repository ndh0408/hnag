// Orders Kanban — Mới / Đang nấu / Đang giao / Hoàn thành columns.
// Mirrors design/w-owner2.jsx (Web_OwnerOrders).

'use client';

import * as React from 'react';
import { Package, Clock, Truck, Check, Filter, Search } from 'lucide-react';
import { Badge, Card, IconButton, SearchBar } from '@/components/ui';

type OrderStage = 'new' | 'cooking' | 'delivering' | 'done';

interface Order {
  id: string;
  customerName: string;
  items: { name: string; qty: number }[];
  totalK: number;
  stage: OrderStage;
  mins: number;
  isNew?: boolean;
}

const DEMO_ORDERS: Order[] = [
  { id: '#2847', customerName: 'Thảo Lê',  items: [{ name: 'Cơm gà Hải Nam', qty: 2 }], totalK: 90,  stage: 'new', mins: 2,  isNew: true },
  { id: '#2846', customerName: 'Minh T.',  items: [{ name: 'Phở bò', qty: 1 }],          totalK: 50,  stage: 'new', mins: 5,  isNew: true },
  { id: '#2845', customerName: 'Khoa N.',  items: [{ name: 'Combo gà', qty: 1 }],        totalK: 130, stage: 'cooking', mins: 12 },
  { id: '#2844', customerName: 'Linh H.',  items: [{ name: 'Trà đá', qty: 3 }, { name: 'Cơm tấm', qty: 1 }], totalK: 65, stage: 'cooking', mins: 18 },
  { id: '#2843', customerName: 'Hùng V.',  items: [{ name: 'Phở tái', qty: 1 }],         totalK: 55,  stage: 'delivering', mins: 25 },
  { id: '#2842', customerName: 'Diễm Q.',  items: [{ name: 'Bún chả', qty: 2 }],         totalK: 110, stage: 'done', mins: 45 },
  { id: '#2841', customerName: 'Tâm Ng.',  items: [{ name: 'Bò kho', qty: 1 }],          totalK: 70,  stage: 'done', mins: 52 },
];

const STAGES: { id: OrderStage; label: string; icon: React.ReactNode; color: string }[] = [
  { id: 'new',        label: 'Mới',          icon: <Package />,  color: 'text-brand-500 bg-brand-500/12' },
  { id: 'cooking',    label: 'Đang nấu',     icon: <Clock />,    color: 'text-turmeric-600 bg-turmeric-500/16' },
  { id: 'delivering', label: 'Đang giao',    icon: <Truck />,    color: 'text-info-500 bg-info-500/12' },
  { id: 'done',       label: 'Hoàn thành',   icon: <Check />,    color: 'text-basil-600 bg-basil-500/12' },
];

export default function OrdersPage() {
  const [orders, setOrders] = React.useState(DEMO_ORDERS);
  const [search, setSearch] = React.useState('');
  const [draggingId, setDraggingId] = React.useState<string | null>(null);

  const move = (id: string, stage: OrderStage) => {
    setOrders((all) => all.map((o) => (o.id === id ? { ...o, stage, isNew: false } : o)));
  };

  const filtered = orders.filter((o) =>
    search === '' ||
    o.id.toLowerCase().includes(search.toLowerCase()) ||
    o.customerName.toLowerCase().includes(search.toLowerCase()) ||
    o.items.some((it) => it.name.toLowerCase().includes(search.toLowerCase())),
  );

  return (
    <div className="min-h-screen bg-bgSunken">
      <div className="px-7 py-4 bg-bgRaised border-b border-divider">
        <div className="flex items-center gap-4">
          <div className="flex-1">
            <h1 className="font-display font-bold text-[22px] tracking-tight">Đơn hàng</h1>
            <p className="text-[13px] text-textMuted">Kéo thả giữa các cột để chuyển trạng thái</p>
          </div>
          <div className="w-64"><SearchBar placeholder="ID, khách, món..." value={search} onChange={(e) => setSearch(e.target.value)} voice={false} /></div>
          <IconButton variant="soft" label="Filter"><Filter /></IconButton>
        </div>
      </div>

      <div className="p-6">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 min-h-[70vh]">
          {STAGES.map((stage) => {
            const items = filtered.filter((o) => o.stage === stage.id);
            return (
              <div
                key={stage.id}
                onDragOver={(e) => e.preventDefault()}
                onDrop={() => { if (draggingId) move(draggingId, stage.id); setDraggingId(null); }}
                className="bg-bgElev border border-borderc rounded-[20px] p-4 flex flex-col"
              >
                <div className="flex items-center justify-between mb-3">
                  <div className="flex items-center gap-2">
                    <div className={`size-7 rounded-[10px] grid place-items-center ${stage.color} [&_svg]:size-4`}>
                      {stage.icon}
                    </div>
                    <span className="font-semibold text-[14px]">{stage.label}</span>
                  </div>
                  <Badge variant="soft">{items.length}</Badge>
                </div>
                <div className="flex-1 flex flex-col gap-2 overflow-y-auto max-h-[calc(100vh-280px)]">
                  {items.map((o) => (
                    <Card
                      key={o.id}
                      pad="sm"
                      hoverable
                      className="cursor-move"
                      draggable
                      onDragStart={() => setDraggingId(o.id)}
                      onDragEnd={() => setDraggingId(null)}
                    >
                      <div className="flex items-start justify-between">
                        <span className="font-mono text-[12px] font-semibold">{o.id}</span>
                        {o.isNew && <Badge variant="brand" size="sm">MỚI</Badge>}
                      </div>
                      <div className="text-[13px] font-medium mt-1">{o.customerName}</div>
                      <div className="text-[12px] text-textMuted mt-0.5">
                        {o.items.map((it) => `${it.name} ×${it.qty}`).join(' · ')}
                      </div>
                      <div className="flex items-center justify-between mt-2">
                        <span className="text-[12px] font-mono text-textMuted">{o.mins} phút trước</span>
                        <span className="text-[13px] font-bold text-brand-500">{o.totalK}k</span>
                      </div>
                    </Card>
                  ))}
                  {items.length === 0 && (
                    <div className="text-center text-[13px] text-textFaint italic py-6">— trống —</div>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
