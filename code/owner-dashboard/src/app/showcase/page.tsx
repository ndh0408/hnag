'use client';

// Hi-Fi Design System showcase — visit /_showcase to QA primitives.
// Light + dark toggle in the header. Mirrors the Flutter ShowcaseScreen.

import * as React from 'react';
import {
  Sparkle, Sparkles, Heart, Bookmark, Share2, Bell, MessageCircle, Camera,
  Search, Mic, MoreHorizontal, ChevronRight, Moon, Sun, Lock, LogOut, Mail,
  Trash2, Check, AlertTriangle, Flame, Crown, Leaf, Eye, Menu, ArrowUpRight,
} from 'lucide-react';
import {
  Button, IconButton, Card, Badge, Chip, Avatar, AvatarStack, Input,
  SearchBar, Switch, Slider, Tabs, Progress, StatusDot, Photo, ListItem,
  FOOD_GRADIENT_KEYS,
} from '@/components/ui';

export default function ShowcasePage() {
  const [dark, setDark] = React.useState(false);

  React.useEffect(() => {
    document.documentElement.classList.toggle('dark', dark);
    return () => document.documentElement.classList.remove('dark');
  }, [dark]);

  return (
    <div className={dark ? 'dark' : ''}>
      <div className="min-h-screen bg-bg text-text">
        <header className="sticky top-0 z-20 bg-bg/80 backdrop-blur border-b border-divider">
          <div className="max-w-5xl mx-auto px-6 h-16 flex items-center justify-between">
            <div>
              <h1 className="text-[22px] font-bold font-display tracking-tight">🎨 Hi-Fi Design</h1>
              <p className="text-[13px] text-textMuted">{dark ? 'Dark mode' : 'Light mode'} · /_showcase</p>
            </div>
            <IconButton
              variant="soft"
              onClick={() => setDark((v) => !v)}
              label="Toggle theme"
            >
              {dark ? <Sun /> : <Moon />}
            </IconButton>
          </div>
        </header>

        <main className="max-w-5xl mx-auto px-6 py-10 space-y-12">
          <Section title="Colors" subtitle="Brand ramp + warm neutrals + semantic accents">
            <ColorRamps />
          </Section>

          <Section title="Typography" subtitle="Urbanist display + Inter body">
            <TypeScale />
          </Section>

          <Section title="Buttons" subtitle="5 sizes · 10 variants">
            <div className="flex flex-wrap gap-2.5">
              <Button variant="primary">Primary</Button>
              <Button variant="gradient" iconLeading={<Sparkle className="size-4" />}>Gradient</Button>
              <Button variant="secondary">Secondary</Button>
              <Button variant="ghost">Ghost</Button>
              <Button variant="outline">Outline</Button>
              <Button variant="soft" iconLeading={<Heart className="size-4" />}>Soft</Button>
              <Button variant="danger" iconLeading={<Trash2 className="size-4" />}>Danger</Button>
              <Button variant="success" iconLeading={<Check className="size-4" />}>Success</Button>
              <Button variant="glass">Glass</Button>
              <Button variant="dark">Dark</Button>
            </div>
            <div className="flex flex-wrap gap-2.5 mt-3 items-center">
              <Button size="xs" variant="outline">xs</Button>
              <Button size="sm" variant="outline">sm</Button>
              <Button size="md" variant="outline">md</Button>
              <Button size="lg" variant="outline">lg</Button>
              <Button size="xl" variant="outline">xl</Button>
              <Button loading variant="primary">Loading...</Button>
            </div>
          </Section>

          <Section title="Icon Buttons" subtitle="Circular, with optional badge">
            <div className="flex flex-wrap gap-2.5 items-center">
              <IconButton variant="ghost"><Heart /></IconButton>
              <IconButton variant="soft"><Bookmark /></IconButton>
              <IconButton variant="outline"><Share2 /></IconButton>
              <IconButton variant="primary"><Sparkle /></IconButton>
              <IconButton variant="soft" badge={3}><Bell /></IconButton>
              <IconButton variant="outline" badge={12}><MessageCircle /></IconButton>
              <IconButton size="xs" variant="soft"><Camera /></IconButton>
              <IconButton size="sm" variant="soft"><Camera /></IconButton>
              <IconButton size="md" variant="soft"><Camera /></IconButton>
              <IconButton size="lg" variant="soft"><Camera /></IconButton>
            </div>
          </Section>

          <Section title="Cards" subtitle="10 variants">
            <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
              {[
                ['default', 'Default'],
                ['raised', 'Raised'],
                ['elevated', 'Elevated'],
                ['glass', 'Glass'],
                ['flat', 'Flat'],
                ['outline', 'Outline'],
                ['dashed', 'Dashed'],
                ['gradient', 'Gradient'],
                ['dark', 'Dark'],
                ['soft', 'Soft'],
              ].map(([v, name]) => (
                <Card key={v} variant={v as any}>
                  <div className="h-20 flex flex-col justify-between">
                    <div className="font-display font-semibold text-[16px]">{name}</div>
                    <div className="text-[11px] font-mono opacity-70">variant=&quot;{v}&quot;</div>
                  </div>
                </Card>
              ))}
            </div>
          </Section>

          <Section title="Badges" subtitle="Pill labels — 3 sizes · 10 variants">
            <div className="flex flex-wrap gap-2">
              <Badge>Default</Badge>
              <Badge variant="brand">Brand</Badge>
              <Badge variant="soft">Soft</Badge>
              <Badge variant="outline">Outline</Badge>
              <Badge variant="success"><Check className="size-3" /> Success</Badge>
              <Badge variant="warning"><AlertTriangle className="size-3" /> Warning</Badge>
              <Badge variant="danger"><Flame className="size-3" /> Danger</Badge>
              <Badge variant="ai"><Sparkle className="size-3" /> AI</Badge>
              <Badge variant="gradient"><Crown className="size-3" /> Gradient</Badge>
              <Badge variant="dot">NEW</Badge>
              <Badge size="sm">sm</Badge>
              <Badge size="md">md</Badge>
              <Badge size="lg">lg</Badge>
            </div>
          </Section>

          <Section title="Chips" subtitle="Filter pills, active inverts">
            <ChipDemo />
          </Section>

          <Section title="Avatars" subtitle="HSL gradient hash + status dot + stack">
            <div className="flex flex-wrap items-center gap-3">
              <Avatar name="Nguyễn An" size={32} />
              <Avatar name="Bích" size={40} />
              <Avatar name="Cường" size={48} status="online" />
              <Avatar name="Diễm" size={56} ring />
              <Avatar name="Em" size={64} status="busy" />
              <Avatar name="Foo" size={72} ring status="away" />
              <AvatarStack names={['Hà', 'Mai', 'Lan', 'Khoa', 'Phương', 'Tâm']} size={36} />
            </div>
          </Section>

          <Section title="Inputs">
            <div className="grid gap-3 max-w-md">
              <Input leading={<Mail />} placeholder="Email của bạn" />
              <SearchBar placeholder="Tìm món, quán..." />
              <Input leading={<Lock />} type="password" placeholder="Mật khẩu" />
              <Input leading={<Mail />} placeholder="Sai email" error="Email không hợp lệ" />
            </div>
          </Section>

          <Section title="Switch + Slider">
            <ToggleSliderDemo />
          </Section>

          <Section title="Tabs">
            <TabsDemo />
          </Section>

          <Section title="Progress">
            <div className="space-y-2 max-w-md">
              <Progress value={25} />
              <Progress value={60} />
              <Progress value={92} />
              <div className="flex gap-2 pt-2">
                <StatusDot status="online" />
                <StatusDot status="away" />
                <StatusDot status="busy" />
                <StatusDot status="offline" />
              </div>
            </div>
          </Section>

          <Section title="Photo placeholders" subtitle="16 food gradient stand-ins">
            <div className="grid grid-cols-4 md:grid-cols-8 gap-3">
              {FOOD_GRADIENT_KEYS.map((slug) => (
                <div key={slug} className="text-center">
                  <Photo foodSlug={slug} aspect="1" />
                  <div className="font-mono text-[11px] text-textMuted mt-1">{slug}</div>
                </div>
              ))}
            </div>
          </Section>

          <Section title="List items">
            <Card pad="none" className="overflow-hidden max-w-md">
              <ListItem
                leading={<Bell />}
                title="Thông báo"
                subtitle="Đẩy + email"
                trailing={<Switch checked />}
              />
              <div className="h-px bg-divider mx-3.5" />
              <ListItem
                leading={<Lock />}
                title="Quyền riêng tư"
                trailing={<ChevronRight className="size-[18px] text-textMuted" />}
                onClick={() => {}}
              />
              <div className="h-px bg-divider mx-3.5" />
              <ListItem
                leading={<LogOut />}
                title="Đăng xuất"
                danger
                onClick={() => {}}
              />
            </Card>
          </Section>

          <Section title="Aurora background" subtitle="Decorative mesh used behind splash + premium">
            <div className="relative overflow-hidden rounded-[20px] h-44 bg-neutral-950 bg-gradient-aurora flex items-center justify-center">
              <h2 className="text-white font-display font-bold text-[28px]">Aurora background</h2>
            </div>
          </Section>
        </main>
      </div>
    </div>
  );
}

// ─── helpers ──────────────────────────────────────────────────────────────

function Section({ title, subtitle, children }: { title: string; subtitle?: string; children: React.ReactNode }) {
  return (
    <section>
      <h2 className="text-[22px] font-display font-bold tracking-tight mb-1">{title}</h2>
      {subtitle && <p className="text-[13px] text-textMuted mb-4">{subtitle}</p>}
      {children}
    </section>
  );
}

function Swatch({ label, hex, color }: { label: string; hex: string; color: string }) {
  return (
    <div className="text-left">
      <div className="w-20 h-14 rounded-[10px] border border-borderc" style={{ background: color }} />
      <div className="text-[12px] font-medium mt-1">{label}</div>
      <div className="font-mono text-[11px] text-textMuted">{hex}</div>
    </div>
  );
}

function ColorRamps() {
  const brand = [
    ['50', '#FFF4ED'], ['100', '#FFE6D5'], ['200', '#FFC9A8'], ['300', '#FFA170'],
    ['400', '#FF8043'], ['500', '#FF6B2B'], ['600', '#F04E0B'], ['700', '#C73C08'],
    ['800', '#9F310F'], ['900', '#7F2A10'],
  ];
  const neutrals = [
    ['25', '#FBFAF7'], ['50', '#F7F5F1'], ['100', '#EFECE5'], ['200', '#E2DED5'],
    ['300', '#C9C3B6'], ['400', '#A39C8E'], ['500', '#7A7468'], ['600', '#5A554B'],
    ['700', '#3F3A33'], ['900', '#14120F'],
  ];
  const semantic = [
    ['chili', '#E63946'], ['turmeric', '#F4B942'], ['basil', '#2D8B5C'],
    ['ai', '#A855F7'], ['info', '#4A6FA5'],
  ];
  return (
    <div className="space-y-6 overflow-x-auto">
      <Ramp label="Brand" items={brand} />
      <Ramp label="Neutrals" items={neutrals} />
      <Ramp label="Semantic" items={semantic} />
    </div>
  );
}

function Ramp({ label, items }: { label: string; items: string[][] }) {
  return (
    <div className="flex items-end gap-2">
      <div className="w-20 text-[13px] font-medium text-textMuted">{label}</div>
      {items.map(([k, v]) => (
        <Swatch key={k} label={k} hex={v} color={v} />
      ))}
    </div>
  );
}

function TypeScale() {
  const rows: [string, string][] = [
    ['d1',     'text-[56px] leading-[1.05] font-extrabold tracking-[-0.025em] font-display'],
    ['d2',     'text-[42px] leading-[1.08] font-extrabold tracking-[-0.024em] font-display'],
    ['d3',     'text-[32px] leading-[1.12] font-bold tracking-[-0.022em] font-display'],
    ['h1',     'text-[26px] leading-[1.18] font-bold tracking-[-0.02em] font-display'],
    ['h2',     'text-[22px] leading-[1.22] font-bold tracking-[-0.018em] font-display'],
    ['h3',     'text-[18px] leading-[1.28] font-semibold tracking-[-0.014em] font-display'],
    ['h4',     'text-[16px] leading-[1.32] font-semibold tracking-[-0.012em] font-display'],
    ['bodyLg', 'text-[16px] leading-[1.5]'],
    ['body',   'text-[14px] leading-[1.5]'],
    ['bodySm', 'text-[13px] leading-[1.5]'],
    ['label',  'text-[13px] leading-[1.3] font-medium'],
    ['caps',   'text-[11px] font-semibold uppercase tracking-[0.08em]'],
    ['numLg',  'text-[32px] font-bold tabular-nums font-display'],
  ];
  return (
    <div className="divide-y divide-divider">
      {rows.map(([k, cls]) => (
        <div key={k} className="py-2 flex items-baseline gap-4">
          <div className="w-16 font-mono text-[11px] text-textMuted">{k}</div>
          <div className={cls}>Hôm nay ăn gì? Hà gợi ý cho bạn</div>
        </div>
      ))}
    </div>
  );
}

function ChipDemo() {
  const opts = ['Phở', 'Bún', 'Cơm', 'Lẩu', 'Chay', 'Cay'];
  const [active, setActive] = React.useState('Phở');
  return (
    <div className="flex flex-wrap gap-2">
      {opts.map((o) => (
        <Chip key={o} active={active === o} onClick={() => setActive(o)}>{o}</Chip>
      ))}
      <Chip><Leaf className="size-4" /> Có icon</Chip>
    </div>
  );
}

function ToggleSliderDemo() {
  const [on, setOn] = React.useState(true);
  const [budget, setBudget] = React.useState(80);
  return (
    <div className="space-y-3 max-w-md">
      <div className="flex items-center justify-between">
        <span className="text-[14px]">Thông báo</span>
        <Switch checked={on} onChange={setOn} />
      </div>
      <Slider
        value={budget}
        min={20} max={500}
        label="Ngân sách"
        leading="20k"
        trailing={`${Math.round(budget)}k`}
        onChange={setBudget}
      />
    </div>
  );
}

function TabsDemo() {
  const [u, setU] = React.useState('Khám phá');
  const [s, setS] = React.useState('Sáng');
  return (
    <div className="space-y-4">
      <Tabs
        tabs={['Khám phá', 'Trending', 'Bạn bè', 'Tôi']}
        active={u}
        onChange={setU}
      />
      <Tabs
        variant="segmented"
        tabs={['Sáng', 'Trưa', 'Tối']}
        active={s}
        onChange={setS}
      />
    </div>
  );
}
