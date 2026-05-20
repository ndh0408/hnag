'use client';
import { Star } from 'lucide-react';

const reviews = [
  { id: '1', user: 'Mai L.',  avatar: 'M', rating: 5, content: 'Ngon xuất sắc! Nước dùng đậm đà, sẽ quay lại.' },
  { id: '2', user: 'Khoa Đ.', avatar: 'K', rating: 3, content: 'Hơi mặn nhưng overall ổn.' },
  { id: '3', user: 'Thảo L.', avatar: 'T', rating: 5, content: 'Best phở Hà Nội!' },
];

export function ReviewsRecent() {
  return (
    <div className="bg-white rounded-lg border p-5">
      <div className="flex items-center justify-between mb-4">
        <h2 className="font-semibold">Review gần đây</h2>
        <a href="/dashboard/reviews" className="text-sm text-primary hover:underline">Xem tất cả</a>
      </div>
      <div className="space-y-3">
        {reviews.map(r => (
          <div key={r.id} className="flex gap-3 py-2 border-b last:border-0">
            <div className="w-9 h-9 rounded-full bg-primary/15 flex items-center justify-center font-medium text-sm">{r.avatar}</div>
            <div className="flex-1">
              <div className="flex items-center gap-2">
                <span className="font-medium text-sm">{r.user}</span>
                <div className="flex items-center gap-0.5 text-warning">
                  {Array.from({ length: r.rating }, (_, i) => <Star key={i} size={12} fill="currentColor" />)}
                </div>
              </div>
              <p className="text-sm mt-1">{r.content}</p>
              <button className="text-xs text-primary hover:underline mt-1">Trả lời</button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
