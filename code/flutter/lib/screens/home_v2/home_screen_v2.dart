// Home v2 — sticky header + weather context + stories rail + AI hero card
// + trending nearby horizontal + friends activity + TikTok grid.
// Mirrors design/m-home.jsx#Screen_Home.

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/gradients.dart';
import '../../design/food_gradients.dart';
import '../../design/theme.dart';
import '../../widgets/ds/ds.dart';
import 'food_card_large.dart';

class StoryItem {
  final String name;
  final String? avatarUrl;
  final String? mediaUrl;
  final String foodSlug;
  final VoidCallback? onTap;
  const StoryItem({required this.name, this.avatarUrl, this.mediaUrl, this.foodSlug = 'pho', this.onTap});
}

class HomeScreenV2 extends StatelessWidget {
  final String userName;
  final String? userAvatar;
  final FoodCardLargeData? heroSuggestion;
  final List<StoryItem> stories;
  final List<NearbyPlace> trending;
  final List<FriendActivity> friends;
  final List<TikTokVideo> tiktoks;
  final VoidCallback? onSearch;
  final VoidCallback? onNotifications;
  final VoidCallback? onRefresh;
  final VoidCallback? onHeroTap;

  const HomeScreenV2({
    super.key,
    required this.userName,
    this.userAvatar,
    this.heroSuggestion,
    this.stories = const [],
    this.trending = const [],
    this.friends = const [],
    this.tiktoks = const [],
    this.onSearch,
    this.onNotifications,
    this.onRefresh,
    this.onHeroTap,
  });

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Chào buổi sáng,';
    if (h < 14) return 'Chào buổi trưa,';
    if (h < 18) return 'Chào buổi chiều,';
    return 'Chào buổi tối,';
  }

  @override
  Widget build(BuildContext context) {
    return HnagThemeScope(
      dark: false,
      child: Builder(builder: (context) {
        final t = context.hnag;
        return Scaffold(
          backgroundColor: t.bg,
          body: SafeArea(
            child: Column(
              children: [
                // Sticky top greeting bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Row(
                    children: [
                      HnagAvatar(name: userName, imageUrl: userAvatar, size: 36),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_greeting(), style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),
                            Text('$userName 👋', style: HnagType.h4.copyWith(color: t.text, fontFamily: HnagFonts.display)),
                          ],
                        ),
                      ),
                      HnagIconButton(icon: 'search', variant: IconBtnVariant.soft, onPressed: onSearch),
                      const SizedBox(width: 6),
                      HnagIconButton(icon: 'bell', variant: IconBtnVariant.soft, onPressed: onNotifications, badge: 3),
                    ],
                  ),
                ),

                Expanded(
                  child: RefreshIndicator(
                    color: t.brand,
                    onRefresh: () async { onRefresh?.call(); },
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        const SizedBox(height: 4),
                        // Weather context
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _WeatherStrip(),
                        ),

                        // Stories rail
                        const SizedBox(height: 20),
                        _StoriesRail(stories: stories),

                        // Hero AI suggestion
                        if (heroSuggestion != null) ...[
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Hà gợi ý cho bạn',
                                            style: HnagType.h2.copyWith(color: t.text, fontFamily: HnagFonts.display),
                                          ),
                                          const SizedBox(height: 2),
                                          Text('Trưa nay, dựa trên thời tiết & vị giác',
                                            style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                                          ),
                                        ],
                                      ),
                                    ),
                                    HnagButton(
                                      label: 'Refresh',
                                      variant: BtnVariant.ghost,
                                      size: BtnSize.sm,
                                      iconTrailing: 'refresh',
                                      onPressed: onRefresh,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                FoodCardLarge(
                                  food: heroSuggestion!,
                                  showActions: true,
                                  onTap: onHeroTap,
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Trending nearby
                        if (trending.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _RailHeader(title: '🔥 Trending quanh bạn', actionLabel: 'Xem hết'),
                          const SizedBox(height: 12),
                          _TrendingHorizontalList(items: trending),
                        ],

                        // Friends activity
                        if (friends.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _RailHeader(title: '👯 Bạn bè đang ăn', actionLabel: 'Tất cả'),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: _FriendsCard(items: friends),
                          ),
                        ],

                        // TikTok grid
                        if (tiktoks.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text('📺 Món hot tuần',
                                    style: HnagType.h3.copyWith(color: t.text, fontFamily: HnagFonts.display),
                                  ),
                                ),
                                const HnagBadge(label: 'TikTok', icon: 'play'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: _TiktokGrid(items: tiktoks),
                          ),
                        ],
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// WEATHER STRIP
// ─────────────────────────────────────────────────────────────
class _WeatherStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    final h = DateTime.now().hour;
    final hourText = h < 11 ? 'Sáng' : h < 14 ? 'Trưa' : h < 18 ? 'Chiều' : 'Tối';
    return HnagCard(
      variant: CardVariant.soft,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: t.brand.withOpacity(0.18),
              borderRadius: BorderRadius.circular(HnagRadius.sm),
            ),
            child: Center(child: HnagIcon('cloud', size: 18, color: t.brand)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('28°C · Mưa nhẹ · $hourText nay',
                  style: HnagType.label.copyWith(color: t.text, fontFamily: HnagFonts.body),
                ),
                Text('Thời tiết hợp món nóng',
                  style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                ),
              ],
            ),
          ),
          HnagIcon('chevR', size: 16, color: t.textMuted),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STORIES RAIL
// ─────────────────────────────────────────────────────────────
class _StoriesRail extends StatelessWidget {
  final List<StoryItem> stories;
  const _StoriesRail({required this.stories});

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return SizedBox(
      height: 90,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          Column(
            children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: t.borderStrong, width: 2),
                ),
                child: Center(child: HnagIcon('plus', size: 22, color: t.textMuted)),
              ),
              const SizedBox(height: 6),
              Text('Thêm', style: HnagType.micro.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),
            ],
          ),
          const SizedBox(width: 12),
          for (final s in stories) ...[
            _Story(item: s),
            const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }
}

class _Story extends StatelessWidget {
  final StoryItem item;
  const _Story({required this.item});

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    final content = Column(
      children: [
        Container(
          width: 60, height: 60,
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: HnagGradients.brand,
          ),
          child: Container(
            decoration: BoxDecoration(color: t.bg, shape: BoxShape.circle),
            padding: const EdgeInsets.all(2),
            child: ClipOval(
              child: item.mediaUrl != null && item.mediaUrl!.isNotEmpty
                  ? HnagPhoto(imageUrl: item.mediaUrl, foodSlug: item.foodSlug, aspectRatio: 1, radius: 999)
                  : item.avatarUrl != null && item.avatarUrl!.isNotEmpty
                      ? HnagPhoto(imageUrl: item.avatarUrl, foodSlug: item.foodSlug, aspectRatio: 1, radius: 999)
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: FoodGradients.bySlug(item.foodSlug),
                            shape: BoxShape.circle,
                          ),
                        ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text('@${item.name}',
          style: HnagType.micro.copyWith(color: t.text, fontFamily: HnagFonts.body),
        ),
      ],
    );
    if (item.onTap == null) return content;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: item.onTap, child: content);
  }
}

// ─────────────────────────────────────────────────────────────
// RAIL HEADER
// ─────────────────────────────────────────────────────────────
class _RailHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback? onAction;
  const _RailHeader({required this.title, required this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: HnagType.h3.copyWith(color: t.text, fontFamily: HnagFonts.display)),
          ),
          HnagButton(
            label: actionLabel,
            variant: BtnVariant.ghost,
            size: BtnSize.sm,
            iconTrailing: 'chevR',
            onPressed: onAction,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TRENDING NEARBY
// ─────────────────────────────────────────────────────────────
class NearbyPlace {
  final String id;
  final String name;
  final String rating;
  final String price;
  final String distance;
  final String foodSlug;
  final String? imageUrl;
  final bool hot;
  final VoidCallback? onTap;
  const NearbyPlace({
    required this.id,
    required this.name,
    required this.rating,
    required this.price,
    required this.distance,
    required this.foodSlug,
    this.imageUrl,
    this.hot = false,
    this.onTap,
  });
}

class _TrendingHorizontalList extends StatelessWidget {
  final List<NearbyPlace> items;
  const _TrendingHorizontalList({required this.items});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _TrendingCard(place: items[i]),
      ),
    );
  }
}

class _TrendingCard extends StatelessWidget {
  final NearbyPlace place;
  const _TrendingCard({required this.place});

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return HnagCard(
      width: 168,
      padding: EdgeInsets.zero,
      onTap: place.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              children: [
                Positioned.fill(child: HnagPhoto(foodSlug: place.foodSlug, imageUrl: place.imageUrl, radius: HnagRadius.sm)),
                if (place.hot)
                  Positioned(
                    top: 8, left: 8,
                    child: const HnagBadge(label: 'HOT', icon: 'flame', variant: BadgeVariant.brand),
                  ),
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), shape: BoxShape.circle),
                    child: Center(child: HnagIcon('heart', size: 16, color: t.text)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: HnagType.label.copyWith(color: t.text, fontWeight: FontWeight.w600, fontFamily: HnagFonts.body),
                ),
                const SizedBox(height: 3),
                Text('⭐ ${place.rating} · ${place.distance}',
                  style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                ),
                const SizedBox(height: 4),
                Text(place.price,
                  style: HnagType.label.copyWith(color: t.brand, fontFamily: HnagFonts.body),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FRIENDS
// ─────────────────────────────────────────────────────────────
class FriendActivity {
  final String name;
  final String text;
  final String time;
  final String? avatarUrl;
  final String emoji;
  final bool cooking;
  final VoidCallback? onTap;
  const FriendActivity({
    required this.name,
    required this.text,
    required this.time,
    this.avatarUrl,
    this.emoji = '🍜',
    this.cooking = false,
    this.onTap,
  });
}

class _FriendsCard extends StatelessWidget {
  final List<FriendActivity> items;
  const _FriendsCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return HnagCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: HnagDivider()),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: items[i].onTap,
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      HnagAvatar(name: items[i].name, imageUrl: items[i].avatarUrl, size: 40),
                      if (items[i].cooking)
                        Positioned(
                          right: -2, bottom: -2,
                          child: Container(
                            width: 18, height: 18,
                            decoration: BoxDecoration(
                              color: t.warning,
                              shape: BoxShape.circle,
                              border: Border.all(color: t.bg, width: 2),
                            ),
                            alignment: Alignment.center,
                            child: Text(items[i].emoji, style: const TextStyle(fontSize: 10)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(items[i].name,
                          style: HnagType.label.copyWith(color: t.text, fontWeight: FontWeight.w600, fontFamily: HnagFonts.body),
                        ),
                        const SizedBox(height: 2),
                        Text('${items[i].text} · ${items[i].time}',
                          style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                        ),
                      ],
                    ),
                  ),
                  HnagIconButton(icon: 'chat', variant: IconBtnVariant.soft, size: IconBtnSize.sm, onPressed: items[i].onTap),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TIKTOK
// ─────────────────────────────────────────────────────────────
class TikTokVideo {
  final String name;
  final String views;
  final String foodSlug;
  final String? videoUrl;
  final VoidCallback? onTap;
  const TikTokVideo({required this.name, required this.views, required this.foodSlug, this.videoUrl, this.onTap});
}

class _TiktokGrid extends StatelessWidget {
  final List<TikTokVideo> items;
  const _TiktokGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 9 / 16,
      ),
      itemBuilder: (_, i) {
        final v = items[i];
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: v.onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(HnagRadius.md),
            child: Stack(
              fit: StackFit.expand,
              children: [
                HnagPhoto(foodSlug: v.foodSlug, aspectRatio: 9 / 16),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  top: 8, left: 8,
                  child: HnagBadge(label: v.views, icon: 'play', variant: BadgeVariant.glass),
                ),
                Positioned(
                  left: 10, right: 10, bottom: 10,
                  child: Text(v.name,
                    style: HnagType.label.copyWith(color: Colors.white, fontFamily: HnagFonts.body),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
