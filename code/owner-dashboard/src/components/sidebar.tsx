'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { LayoutDashboard, ShoppingBag, Star, MenuSquare, Image, Megaphone, BarChart3, Users, Settings } from 'lucide-react';
import clsx from 'clsx';

const nav = [
  { href: '/dashboard',           label: 'Dashboard',  icon: LayoutDashboard },
  { href: '/dashboard/orders',    label: 'Orders',     icon: ShoppingBag },
  { href: '/dashboard/reviews',   label: 'Reviews',    icon: Star },
  { href: '/dashboard/menu',      label: 'Menu',       icon: MenuSquare },
  { href: '/dashboard/photos',    label: 'Photos',     icon: Image },
  { href: '/dashboard/boost',     label: 'Boost & Ads',icon: Megaphone },
  { href: '/dashboard/analytics', label: 'Analytics',  icon: BarChart3 },
  { href: '/dashboard/team',      label: 'Team',       icon: Users },
  { href: '/dashboard/settings',  label: 'Settings',   icon: Settings },
];

export function Sidebar() {
  const path = usePathname();
  return (
    <aside className="w-60 bg-white border-r flex flex-col">
      <div className="h-16 flex items-center px-6 border-b">
        <span className="text-2xl">🍜</span>
        <span className="ml-2 font-bold">HNAG</span>
        <span className="ml-1 text-xs px-1.5 py-0.5 bg-primary/15 text-primary rounded">OWNER</span>
      </div>
      <nav className="flex-1 p-3 space-y-1">
        {nav.map(({ href, label, icon: Icon }) => {
          const active = path === href || (href !== '/dashboard' && path.startsWith(href));
          return (
            <Link key={href} href={href} className={clsx(
              'flex items-center gap-3 px-3 py-2 rounded-md text-sm transition-colors',
              active ? 'bg-primary/10 text-primary font-medium' : 'text-foreground/70 hover:bg-muted',
            )}>
              <Icon size={18} />
              {label}
            </Link>
          );
        })}
      </nav>
    </aside>
  );
}
