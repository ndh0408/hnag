'use client';
import { useState } from 'react';
import clsx from 'clsx';

const states = [
  { id: 'empty',  label: 'Trống',     color: 'bg-success'  },
  { id: 'normal', label: 'Vừa',       color: 'bg-warning'  },
  { id: 'busy',   label: 'Đông',      color: 'bg-orange-500' },
  { id: 'full',   label: 'Cực đông',  color: 'bg-danger'   },
];

export function LiveControl() {
  const [current, setCurrent] = useState('normal');
  const [wait, setWait] = useState(5);

  async function update(id: string) {
    setCurrent(id);
    // call PATCH /owner/restaurants/:id/live
  }

  return (
    <div className="bg-white rounded-lg border p-5">
      <div className="flex items-center justify-between mb-3">
        <h2 className="font-semibold">Trạng thái live</h2>
        <span className="text-xs text-muted-foreground">Real-time tới khách</span>
      </div>
      <div className="grid grid-cols-4 gap-2">
        {states.map(s => (
          <button
            key={s.id}
            onClick={() => update(s.id)}
            className={clsx(
              'py-3 rounded-lg text-sm font-medium border-2 transition',
              current === s.id ? 'border-primary bg-primary/5' : 'border-transparent hover:bg-muted',
            )}
          >
            <div className={clsx('w-2 h-2 rounded-full mx-auto mb-1', s.color)} />
            {s.label}
          </button>
        ))}
      </div>
      <div className="flex items-center gap-3 mt-4">
        <label className="text-sm">Wait time:</label>
        <input
          type="number"
          value={wait}
          onChange={e => setWait(parseInt(e.target.value) || 0)}
          className="w-20 border rounded-md px-3 py-1.5 text-sm"
        />
        <span className="text-sm text-muted-foreground">phút</span>
        <button className="ml-auto px-3 py-1.5 text-sm bg-primary text-white rounded-md">Cập nhật</button>
      </div>
    </div>
  );
}
