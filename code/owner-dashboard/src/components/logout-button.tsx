'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { LogOut } from 'lucide-react';

export function LogoutButton() {
  const r = useRouter();
  const [busy, setBusy] = useState(false);

  async function logout() {
    setBusy(true);
    try {
      // Clears the httpOnly auth cookies server-side.
      await fetch('/api/auth/logout', { method: 'POST' });
    } finally {
      r.push('/login');
      r.refresh();
    }
  }

  return (
    <button
      onClick={logout}
      disabled={busy}
      title="Đăng xuất"
      className="p-2 rounded-full hover:bg-muted text-muted-foreground disabled:opacity-50"
    >
      <LogOut size={18} />
    </button>
  );
}
