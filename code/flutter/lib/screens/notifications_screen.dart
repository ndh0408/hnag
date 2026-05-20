import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HNotification {
  final String id;
  final String type;        // ai_suggest, social_like, order_status, streak, group_invite, system
  final String title;
  final String body;
  final String? imageUrl;
  final DateTime createdAt;
  final bool unread;
  const HNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.imageUrl,
    required this.createdAt,
    this.unread = true,
  });
}

class NotificationsScreen extends StatelessWidget {
  final List<HNotification> items;
  final Future<void> Function() onMarkAllRead;
  const NotificationsScreen({super.key, required this.items, required this.onMarkAllRead});

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByDay(items);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        elevation: 0,
        actions: [
          TextButton(onPressed: onMarkAllRead, child: const Text('Đánh dấu đã đọc')),
        ],
      ),
      body: items.isEmpty
          ? _empty()
          : ListView.builder(
              itemCount: grouped.length,
              itemBuilder: (_, i) {
                final entry = grouped.entries.elementAt(i);
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(entry.key,
                        style: AppTypography.labelSm.copyWith(color: Colors.grey.shade600, letterSpacing: 0.6)),
                  ),
                  ...entry.value.map((n) => _tile(context, n)),
                ]);
              },
            ),
    );
  }

  Widget _tile(BuildContext context, HNotification n) {
    return Container(
      color: n.unread ? AppColors.phoOrange.withOpacity(0.05) : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _bgFor(n.type).withOpacity(0.15),
          child: Text(_emojiFor(n.type), style: const TextStyle(fontSize: 18)),
        ),
        title: Text(n.title, style: AppTypography.bodyLg.copyWith(fontWeight: n.unread ? FontWeight.w600 : FontWeight.w400)),
        subtitle: Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Text(_relative(n.createdAt), style: AppTypography.caption.copyWith(color: Colors.grey.shade500)),
        onTap: () {},
      ),
    );
  }

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🔔', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('Chưa có thông báo', style: AppTypography.headingSm),
            Text('Hà sẽ ping khi có gì hay', style: AppTypography.bodyMd.copyWith(color: Colors.grey.shade600)),
          ]),
        ),
      );

  String _emojiFor(String t) => switch (t) {
        'ai_suggest' => '✨', 'social_like' => '❤️', 'social_comment' => '💬', 'social_follow' => '👤',
        'order_status' => '🛵', 'streak' => '🔥', 'group_invite' => '👥', 'poll' => '🗳', _ => '🔔'
      };
  Color _bgFor(String t) => switch (t) {
        'ai_suggest' => const Color(0xFFA855F7), 'streak' => AppColors.phoOrange,
        'social_like' => AppColors.danger, 'order_status' => AppColors.success, _ => AppColors.turmeric
      };
  String _relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${d.day}/${d.month}';
  }

  Map<String, List<HNotification>> _groupByDay(List<HNotification> ns) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final result = <String, List<HNotification>>{};
    for (final n in ns) {
      final d = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
      final key = d == today ? 'Hôm nay' : d == yesterday ? 'Hôm qua' : '${d.day}/${d.month}';
      result.putIfAbsent(key, () => []).add(n);
    }
    return result;
  }
}
