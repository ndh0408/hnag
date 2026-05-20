const orders = [
  { id: '1', time: '13:42', items: '3× Phở bò tái', total: 165000, partner: 'GrabFood', status: 'preparing' },
  { id: '2', time: '13:38', items: '1× Phở gà',      total: 50000,  partner: 'Pickup',   status: 'confirmed' },
  { id: '3', time: '13:32', items: '2× Phở đặc biệt', total: 130000, partner: 'ShopeeFood', status: 'delivering' },
];

export function OrdersLive() {
  return (
    <div className="bg-white rounded-lg border p-5">
      <div className="flex items-center justify-between mb-4">
        <h2 className="font-semibold">Đơn hàng live</h2>
        <div className="flex items-center gap-1 text-xs">
          <span className="w-2 h-2 bg-success rounded-full animate-pulse" />
          Real-time
        </div>
      </div>
      <div className="space-y-3">
        {orders.map(o => (
          <div key={o.id} className="flex items-center justify-between py-2 border-b last:border-0">
            <div>
              <p className="font-medium text-sm">{o.items}</p>
              <p className="text-xs text-muted-foreground">{o.time} · {o.partner}</p>
            </div>
            <div className="text-right">
              <p className="font-bold text-primary">{(o.total / 1000).toLocaleString()}k₫</p>
              <p className="text-xs text-muted-foreground">{o.status}</p>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
