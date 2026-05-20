import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/food_card.dart';
import '../theme/app_theme.dart';
import 'mega_card.dart';
import 'compact_card.dart';

/// TikTok-Explore-style home feed.
/// Sections per docs/06-VISUAL-FEED.md §2.2.
class HomeFeed extends StatelessWidget {
  final FoodCard heroPick;
  final Map<String, List<FoodCard>> sections;
  final Future<void> Function() onRefresh;
  final void Function(FoodCard) onCardTap;

  const HomeFeed({
    super.key,
    required this.heroPick,
    required this.sections,
    required this.onRefresh,
    required this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: _ContextHeader(hour: hour),
      body: RefreshIndicator(
        color: AppColors.phoOrange,
        onRefresh: onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).padding.top + 80)),
            SliverToBoxAdapter(child: _StoriesStrip()),
            SliverToBoxAdapter(child: _AiHero(card: heroPick, onTap: () => onCardTap(heroPick))),
            for (final entry in sections.entries) ...[
              SliverToBoxAdapter(child: _SectionHeader(title: entry.key)),
              SliverToBoxAdapter(child: _HorizontalCarousel(cards: entry.value, onTap: onCardTap)),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }
}

class _ContextHeader extends StatelessWidget implements PreferredSizeWidget {
  final int hour;
  const _ContextHeader({required this.hour});
  @override
  Size get preferredSize => const Size.fromHeight(72);
  @override
  Widget build(BuildContext context) {
    final greet = _greeting(hour);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.75),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top,
            left: AppSpacing.x4,
            right: AppSpacing.x4,
            bottom: 8,
          ),
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    gradient: AppGradients.pho,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🍜', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(greet, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700)),
                      Text('HCM, Q1 · 28° mưa nhẹ',
                          style: AppTypography.caption.copyWith(color: Theme.of(context).hintColor)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.search_rounded, color: Color(0xFF555)),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.notifications_none_rounded, color: AppColors.phoOrange),
                  visualDensity: VisualDensity.compact,
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting(int h) {
    if (h < 6) return 'Đêm rồi, ăn nhẹ thôi nha 🌙';
    if (h < 11) return 'Chào sáng, đói chưa? ☀️';
    if (h < 14) return 'Trưa rồi, đói chưa nè? 🍜';
    if (h < 17) return 'Chiều mát, làm tô nha 🌤';
    if (h < 21) return 'Tối nay ăn gì? 🌆';
    return 'Khuya rồi, snack thôi 🌙';
  }
}

class _StoriesStrip extends StatelessWidget {
  static const _categories = [
    ('🍜', 'Phở', 'noodle'),
    ('🍚', 'Cơm', 'rice'),
    ('🥢', 'Bún', 'noodle'),
    ('🥖', 'Bánh mì', 'street'),
    ('🍢', 'Nướng', 'grill'),
    ('☕', 'Cà phê', 'drink'),
    ('🍰', 'Tráng miệng', 'dessert'),
    ('🍲', 'Lẩu', 'soup'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4, vertical: 4),
        itemCount: _categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          if (i == 0) return _myStory(context);
          final (emoji, label, _slug) = _categories[i - 1];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppGradients.pho,
                ),
                padding: const EdgeInsets.all(2.5),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).scaffoldBackgroundColor,
                    border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(emoji, style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(height: 4),
              Text(label, style: AppTypography.caption.copyWith(fontSize: 11)),
            ],
          );
        },
      ),
    );
  }

  Widget _myStory(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300, width: 2),
            color: AppColors.phoOrange.withOpacity(0.1),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.search_rounded, color: AppColors.phoOrange, size: 28),
        ),
        const SizedBox(height: 4),
        Text('Tất cả', style: AppTypography.caption.copyWith(fontSize: 11)),
      ],
    );
  }
}

class _AiHero extends StatelessWidget {
  final FoodCard card;
  final VoidCallback onTap;
  const _AiHero({required this.card, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.x4, AppSpacing.x3, AppSpacing.x4, AppSpacing.x2),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: MegaCard(card: card, onTap: onTap),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.x4, AppSpacing.x6, AppSpacing.x4, AppSpacing.x3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(width: 4, height: 22, decoration: BoxDecoration(
            gradient: AppGradients.pho,
            borderRadius: BorderRadius.circular(2),
          )),
          const SizedBox(width: 10),
          Text(title, style: AppTypography.headingSm.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          )),
          const Spacer(),
          Text('Xem tất cả  ›', style: AppTypography.caption.copyWith(
            color: AppColors.phoOrange,
            fontWeight: FontWeight.w600,
          )),
        ],
      ),
    );
  }
}

class _HorizontalCarousel extends StatelessWidget {
  final List<FoodCard> cards;
  final void Function(FoodCard) onTap;
  const _HorizontalCarousel({required this.cards, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 296,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.x3),
        itemBuilder: (_, i) => CompactCard(card: cards[i], onTap: () => onTap(cards[i])),
      ),
    );
  }
}
