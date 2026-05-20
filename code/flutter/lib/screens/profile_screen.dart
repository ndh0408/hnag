import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../api/hnag_api.dart';

class UserProfile {
  final String id;
  final String displayName;
  final String username;
  final String? avatarUrl;
  final String? coverUrl;
  final String? bio;
  final int level;
  final String foodieClass;
  final int reviews;
  final int followers;
  final int following;
  final bool isPremium;
  final bool isVerified;
  final List<({String icon, String name})> badges;
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.username,
    this.avatarUrl,
    this.coverUrl,
    this.bio,
    required this.level,
    required this.foodieClass,
    required this.reviews,
    required this.followers,
    required this.following,
    this.isPremium = false,
    this.isVerified = false,
    this.badges = const [],
  });
}

class ProfileScreen extends StatelessWidget {
  final UserProfile profile;
  final bool isMe;
  final VoidCallback? onEdit;
  final VoidCallback? onFollow;
  final VoidCallback? onSettings;
  const ProfileScreen({super.key, required this.profile, this.isMe = false, this.onEdit, this.onFollow, this.onSettings});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DefaultTabController(
        length: 3,
        child: NestedScrollView(
          headerSliverBuilder: (_, __) => [
            SliverAppBar(
              expandedHeight: 240,
              pinned: true,
              backgroundColor: AppColors.phoOrange,
              foregroundColor: Colors.white,
              actions: [
                if (isMe)
                  IconButton(
                    icon: const Icon(Icons.share_outlined, color: Colors.white),
                    onPressed: () {},
                  ),
                if (isMe)
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: Colors.white),
                    onPressed: onSettings,
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(fit: StackFit.expand, children: [
                  profile.coverUrl != null
                      ? CachedNetworkImage(
                          imageUrl: profile.coverUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(decoration: const BoxDecoration(gradient: AppGradients.pho)),
                          errorWidget: (_, __, ___) => Container(decoration: const BoxDecoration(gradient: AppGradients.pho)),
                        )
                      : Container(decoration: const BoxDecoration(gradient: AppGradients.pho)),
                  // gradient overlay for legibility
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            SliverToBoxAdapter(child: _header(context)),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabsDelegate(
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: const TabBar(
                    labelColor: AppColors.phoOrange,
                    indicatorColor: AppColors.phoOrange,
                    tabs: [Tab(text: 'Posts'), Tab(text: 'Saved'), Tab(text: 'Stats')],
                  ),
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _postsEmpty(context),
              _SavedTab(),
              _StatsTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Transform.translate(
          offset: const Offset(0, -52),
          child: Container(
            width: 108, height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.phoOrange.withOpacity(0.15),
              border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 4),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: ClipOval(
              child: profile.avatarUrl != null
                  ? CachedNetworkImage(
                      imageUrl: profile.avatarUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: AppColors.phoOrange.withOpacity(0.15),
                        alignment: Alignment.center,
                        child: Text(profile.displayName.characters.first.toUpperCase(),
                            style: AppTypography.displayLg.copyWith(color: AppColors.phoOrange)),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.phoOrange.withOpacity(0.15),
                        alignment: Alignment.center,
                        child: Text(profile.displayName.characters.first.toUpperCase(),
                            style: AppTypography.displayLg.copyWith(color: AppColors.phoOrange)),
                      ),
                    )
                  : Container(
                      alignment: Alignment.center,
                      child: Text(profile.displayName.characters.first.toUpperCase(),
                          style: AppTypography.displayLg.copyWith(color: AppColors.phoOrange)),
                    ),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(profile.displayName, style: AppTypography.headingMd),
              const SizedBox(width: 6),
              if (profile.isVerified) const Icon(Icons.verified_rounded, color: AppColors.phoOrange, size: 20),
              if (profile.isPremium) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(gradient: AppGradients.premium, borderRadius: BorderRadius.circular(AppRadii.full)),
                  child: Text('+', style: AppTypography.labelSm.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              ],
            ]),
            const SizedBox(height: 2),
            Text('@${profile.username}', style: AppTypography.bodyMd.copyWith(color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text('${_classEmoji(profile.foodieClass)} ${_className(profile.foodieClass)} · Lv ${profile.level}',
                style: AppTypography.caption.copyWith(color: AppColors.phoOrange)),
            if (profile.bio != null) ...[
              const SizedBox(height: 12),
              Text(profile.bio!, style: AppTypography.bodyMd),
            ],
            const SizedBox(height: AppSpacing.x4),
            Row(children: [
              _statCol(profile.reviews, 'reviews'),
              _statCol(profile.followers, 'followers'),
              _statCol(profile.following, 'following'),
            ]),
            const SizedBox(height: AppSpacing.x4),
            Row(children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: isMe ? onEdit : onFollow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.phoOrange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.full)),
                  ),
                  child: Text(isMe ? 'Chỉnh sửa' : 'Theo dõi'),
                ),
              ),
              if (!isMe) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(minimumSize: const Size(44, 44), shape: const CircleBorder()),
                  child: const Icon(Icons.chat_bubble_outline),
                ),
              ],
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _statCol(int n, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_compact(n), style: AppTypography.headingSm),
        Text(label, style: AppTypography.caption.copyWith(color: Colors.grey.shade600)),
      ]),
    );
  }

  Widget _postsEmpty(BuildContext context) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('📸', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 12),
        Text('Chưa có bài viết', style: AppTypography.headingSm),
        const SizedBox(height: 4),
        Text('Chia sẻ món vừa ăn để bạn bè biết bạn đang ở đâu, ngon thế nào.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMd.copyWith(color: Colors.grey.shade600)),
      ]),
    ));
  }

  String _classEmoji(String c) => switch (c) {
        'tep' => '🦐', 'cua' => '🦀', 'muc' => '🦑', 'camap' => '🦈', 'rong' => '🐉', 'vua' => '👑', _ => '🍜'
      };
  String _className(String c) => switch (c) {
        'tep' => 'Tép', 'cua' => 'Cua', 'muc' => 'Mực', 'camap' => 'Cá Mập', 'rong' => 'Rồng', 'vua' => 'Vua Ẩm Thực', _ => 'Foodie'
      };
  String _compact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

class _SavedTab extends StatefulWidget {
  @override
  State<_SavedTab> createState() => _SavedTabState();
}

class _SavedTabState extends State<_SavedTab> {
  final _api = HnagApi();
  List<Map<String, dynamic>>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _api.mySaves();
    if (mounted) setState(() => _items = items);
  }

  @override
  Widget build(BuildContext context) {
    if (_items == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.phoOrange));
    }
    if (_items!.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🔖', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          Text('Chưa lưu món nào', style: AppTypography.headingSm),
          const SizedBox(height: 4),
          Text('Bookmark món bạn thích để xem lại sau nhé.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd.copyWith(color: Colors.grey.shade600)),
        ]),
      ));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
      itemCount: _items!.length,
      itemBuilder: (_, i) {
        final food = _items![i]['food'] as Map<String, dynamic>?;
        final img = food?['primary_image'] as String?;
        if (img == null || img.isEmpty) {
          return Container(color: Colors.grey.shade200, child: const Icon(Icons.restaurant));
        }
        return CachedNetworkImage(
          imageUrl: img, fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: Colors.grey.shade200),
          errorWidget: (_, __, ___) => Container(color: Colors.grey.shade200, child: const Icon(Icons.image, color: Colors.grey)),
        );
      },
    );
  }
}

class _StatsTab extends StatefulWidget {
  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  final _api = HnagApi();
  Map<String, dynamic>? _streak;
  int? _savedCount;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await _api.myStreak();
    final saves = await _api.mySaves();
    if (mounted) setState(() {
      _streak = s;
      _savedCount = saves.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_streak == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.phoOrange));
    }
    final daily = (_streak!['daily_decide'] as int?) ?? 0;
    final bestDaily = (_streak!['best_decide'] as int?) ?? 0;
    final cook = (_streak!['cook_streak'] as int?) ?? 0;
    final bestCook = (_streak!['best_cook'] as int?) ?? 0;
    return ListView(padding: const EdgeInsets.all(AppSpacing.x4), children: [
      _statTile('🔥 Streak quyết định', '$daily ngày',
          bestDaily > 0 ? 'Best: $bestDaily' : 'Mở app + chọn món để start streak'),
      _statTile('🍳 Streak nấu ăn', '$cook ngày',
          bestCook > 0 ? 'Best: $bestCook' : 'Đánh dấu "Đã nấu" sau khi hoàn thành'),
      _statTile('🥢 Món đã lưu', '${_savedCount ?? 0}', _savedCount == 0 ? 'Bookmark món bạn thích' : null),
    ]);
  }

  Widget _statTile(String label, String value, String? sub) => Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg), side: BorderSide(color: Colors.grey.shade200)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: Text(label, style: AppTypography.bodyLg)),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(value, style: AppTypography.headingSm.copyWith(color: AppColors.phoOrange)),
              if (sub != null) Text(sub, style: AppTypography.caption.copyWith(color: Colors.grey.shade600)),
            ]),
          ]),
        ),
      );
}

class _TabsDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _TabsDelegate({required this.child});
  @override double get minExtent => 48;
  @override double get maxExtent => 48;
  @override Widget build(_, __, ___) => child;
  @override bool shouldRebuild(covariant _) => false;
}
