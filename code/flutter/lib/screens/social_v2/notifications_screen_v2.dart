// Notifications v2 — grouped by today/yesterday/older with type-based icons.
// Mirrors design/m-premium.jsx Notifications section.

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/theme.dart';
import '../../widgets/ds/ds.dart';

class NotificationItem {
  final String id;
  final String type; // ai_suggest | social_like | streak | order | promo
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;
  final String? thumbnailSlug;
  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
    this.thumbnailSlug,
  });
}

class NotificationsScreenV2 extends StatelessWidget {
  final List<NotificationItem> items;
  final VoidCallback? onMarkAllRead;
  final ValueChanged<NotificationItem>? onTap;

  const NotificationsScreenV2({
    super.key,
    required this.items,
    this.onMarkAllRead,
    this.onTap,
  });

  static const _iconByType = {
    'ai_suggest':  ('sparkle', Color(0xFFA855F7)),
    'social_like': ('heart',   Color(0xFFE63946)),
    'streak':      ('flame',   Color(0xFFFF6B2B)),
    'order':       ('package', Color(0xFF2D8B5C)),
    'promo':       ('flag',    Color(0xFFF4B942)),
  };

  Map<String, List<NotificationItem>> _grouped() {
    final now = DateTime.now();
    final today = <NotificationItem>[];
    final yesterday = <NotificationItem>[];
    final older = <NotificationItem>[];
    for (final n in items) {
      final d = now.difference(n.createdAt).inDays;
      if (d == 0) today.add(n);
      else if (d == 1) yesterday.add(n);
      else older.add(n);
    }
    return {
      'Hôm nay': today,
      'Hôm qua': yesterday,
      'Cũ hơn': older,
    }..removeWhere((_, v) => v.isEmpty);
  }

  String _relTime(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 1) return 'vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes}p';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays} ngày';
    return '${(diff.inDays / 7).floor()}t';
  }

  @override
  Widget build(BuildContext context) {
    return HnagThemeScope(
      dark: false,
      child: Builder(builder: (context) {
        final t = context.hnag;
        final groups = _grouped();
        final unread = items.where((n) => !n.read).length;

        if (items.isEmpty) {
          return Scaffold(
            backgroundColor: t.bg,
            appBar: HnagAppBar(
              title: 'Thông báo',
              leading: HnagIconButton(icon: 'chevL', onPressed: () => Navigator.maybePop(context)),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔔', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 12),
                    Text('Chưa có thông báo',
                      style: HnagType.h2.copyWith(color: t.text, fontFamily: HnagFonts.display),
                    ),
                    const SizedBox(height: 4),
                    Text('Hà sẽ ping bạn khi có gợi ý mới',
                      textAlign: TextAlign.center,
                      style: HnagType.bodyLg.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: t.bg,
          appBar: HnagAppBar(
            title: 'Thông báo',
            subtitle: unread > 0 ? '$unread chưa đọc' : 'Đã đọc hết',
            leading: HnagIconButton(icon: 'chevL', onPressed: () => Navigator.maybePop(context)),
            actions: [
              if (unread > 0)
                HnagButton(
                  label: 'Đọc hết',
                  variant: BtnVariant.ghost,
                  size: BtnSize.sm,
                  onPressed: onMarkAllRead,
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              for (final entry in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                  child: Text(entry.key.toUpperCase(),
                    style: HnagType.caps.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                  ),
                ),
                HnagCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < entry.value.length; i++) ...[
                        _NotifTile(item: entry.value[i], onTap: onTap == null ? null : () => onTap!(entry.value[i]), relTime: _relTime(entry.value[i].createdAt)),
                        if (i < entry.value.length - 1) const HnagDivider(),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback? onTap;
  final String relTime;
  const _NotifTile({required this.item, required this.relTime, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    final spec = NotificationsScreenV2._iconByType[item.type] ?? ('bell' as String, t.brand as Color);
    final iconName = spec.$1 as String;
    final iconColor = spec.$2 as Color;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(HnagRadius.sm),
                ),
                child: Center(child: HnagIcon(iconName, color: iconColor)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                      style: HnagType.label.copyWith(
                        color: t.text,
                        fontWeight: item.read ? FontWeight.w500 : FontWeight.w700,
                        fontFamily: HnagFonts.body,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(item.body,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(relTime,
                    style: HnagType.mono.copyWith(color: t.textFaint, fontSize: 10),
                  ),
                  const SizedBox(height: 6),
                  if (!item.read) Container(width: 8, height: 8, decoration: BoxDecoration(color: t.brand, shape: BoxShape.circle)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
