// RestaurantDetail v2 — hero + meta + 3 quick info chips + 3-action row +
// tabs (Menu/Reviews/Ảnh/Map) + menu category chips + menu items list.
// Mirrors design/m-detail.jsx#Screen_RestaurantDetail.

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/theme.dart';
import '../../widgets/ds/ds.dart';

class RestaurantDetailDataV2 {
  final String id;
  final String name;
  final String? imageUrl;
  final String foodSlug;
  final double rating;
  final int reviewCount;
  final String priceRange;
  final bool openNow;
  final String distance;
  final String hoursLabel;
  final String closingNote;
  final String crowdLabel;
  final String crowdLevel;
  final bool verified;
  final List<MenuCategoryV2> menu;

  const RestaurantDetailDataV2({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.foodSlug,
    required this.rating,
    required this.reviewCount,
    required this.priceRange,
    required this.openNow,
    required this.distance,
    required this.hoursLabel,
    required this.closingNote,
    required this.crowdLabel,
    required this.crowdLevel,
    this.verified = false,
    this.menu = const [],
  });
}

class MenuCategoryV2 {
  final String name;
  final List<MenuItemV2> items;
  const MenuCategoryV2({required this.name, required this.items});
}

class MenuItemV2 {
  final String id;
  final String name;
  final String description;
  final int priceVnd;
  final String foodSlug;
  final String? imageUrl;
  final String? tag;
  const MenuItemV2({
    required this.id,
    required this.name,
    required this.description,
    required this.priceVnd,
    required this.foodSlug,
    this.imageUrl,
    this.tag,
  });
}

class RestaurantDetailScreenV2 extends StatefulWidget {
  final RestaurantDetailDataV2 restaurant;
  final VoidCallback? onCall;
  final VoidCallback? onDirections;
  final VoidCallback? onBook;
  final ValueChanged<MenuItemV2>? onAddItem;
  final VoidCallback? onSave;
  final VoidCallback? onShare;

  const RestaurantDetailScreenV2({
    super.key,
    required this.restaurant,
    this.onCall,
    this.onDirections,
    this.onBook,
    this.onAddItem,
    this.onSave,
    this.onShare,
  });

  @override
  State<RestaurantDetailScreenV2> createState() => _RestaurantDetailScreenV2State();
}

class _RestaurantDetailScreenV2State extends State<RestaurantDetailScreenV2> {
  String _tab = 'Menu';
  String _category = 'Tất cả';
  bool _saved = false;

  String _vnd(int v) => '${(v / 1000).round()}k';

  @override
  Widget build(BuildContext context) {
    return HnagThemeScope(
      dark: false,
      child: Builder(builder: (context) {
        final t = context.hnag;
        final r = widget.restaurant;
        final categories = ['Tất cả', ...r.menu.map((c) => c.name)];
        final visibleItems = _category == 'Tất cả'
            ? r.menu.expand((c) => c.items).toList()
            : (r.menu.firstWhere((c) => c.name == _category, orElse: () => const MenuCategoryV2(name: '', items: [])).items);

        return Scaffold(
          backgroundColor: t.bg,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 280,
                pinned: false,
                stretch: true,
                backgroundColor: Colors.transparent,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      HnagPhoto(
                        imageUrl: r.imageUrl,
                        foodSlug: r.foodSlug,
                        aspectRatio: 5 / 3,
                        radius: 0,
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter, end: Alignment.center,
                                colors: [Colors.black.withOpacity(0.35), Colors.transparent],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              HnagIconButton(
                                icon: 'chevL',
                                variant: IconBtnVariant.glass,
                                onPressed: () => Navigator.maybePop(context),
                              ),
                              Row(
                                children: [
                                  HnagIconButton(
                                    icon: _saved ? 'heart' : 'heartOutline',
                                    variant: IconBtnVariant.glass,
                                    onPressed: () {
                                      setState(() => _saved = !_saved);
                                      widget.onSave?.call();
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  HnagIconButton(icon: 'share', variant: IconBtnVariant.glass, onPressed: widget.onShare),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
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
                                  Text(r.name, style: HnagType.d3.copyWith(color: t.text, fontFamily: HnagFonts.display)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text('⭐ ${r.rating} (${r.reviewCount})',
                                        style: HnagType.bodySm.copyWith(color: t.text, fontWeight: FontWeight.w600, fontFamily: HnagFonts.body),
                                      ),
                                      Text(' · ${r.priceRange} · ',
                                        style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                                      ),
                                      Container(width: 6, height: 6,
                                        decoration: BoxDecoration(color: r.openNow ? t.success : t.danger, shape: BoxShape.circle)),
                                      const SizedBox(width: 4),
                                      Text(r.openNow ? 'Đang mở' : 'Đóng cửa',
                                        style: HnagType.bodySm.copyWith(color: r.openNow ? t.success : t.danger, fontWeight: FontWeight.w600, fontFamily: HnagFonts.body),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (r.verified) const HnagBadge(label: 'verified', icon: 'check', variant: BadgeVariant.success),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Info chips
                        Row(
                          children: [
                            Expanded(child: _InfoCard(icon: 'pin', primary: r.distance, sub: 'tới quán')),
                            const SizedBox(width: 6),
                            Expanded(child: _InfoCard(icon: 'clock', primary: r.hoursLabel, sub: r.closingNote)),
                            const SizedBox(width: 6),
                            Expanded(child: _InfoCard(icon: 'users', primary: r.crowdLevel, sub: r.crowdLabel)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Actions
                        Row(
                          children: [
                            Expanded(child: HnagButton(label: 'Chỉ đường', iconLeading: 'map', variant: BtnVariant.secondary, size: BtnSize.md, fullWidth: true, onPressed: widget.onDirections)),
                            const SizedBox(width: 8),
                            Expanded(child: HnagButton(label: 'Gọi', iconLeading: 'phone', variant: BtnVariant.secondary, size: BtnSize.md, fullWidth: true, onPressed: widget.onCall)),
                            const SizedBox(width: 8),
                            Expanded(child: HnagButton(label: 'Đặt bàn', iconLeading: 'cal', variant: BtnVariant.primary, size: BtnSize.md, fullWidth: true, onPressed: widget.onBook)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: HnagTabs(
                      tabs: const ['Menu', 'Reviews', 'Ảnh', 'Map'],
                      active: _tab,
                      onChanged: (v) => setState(() => _tab = v),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_tab == 'Menu') ..._buildMenu(t, categories, visibleItems)
                  else _placeholder(t, _tab),
                  const SizedBox(height: 32),
                ]),
              ),
            ],
          ),
        );
      }),
    );
  }

  List<Widget> _buildMenu(SemanticTokens t, List<String> categories, List<MenuItemV2> items) {
    return [
      SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => HnagChip(
            label: categories[i],
            active: _category == categories[i],
            onTap: () => setState(() => _category = categories[i]),
          ),
        ),
      ),
      const SizedBox(height: 6),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            for (final item in items) ...[
              HnagCard(
                padding: EdgeInsets.zero,
                onTap: widget.onAddItem == null ? null : () => widget.onAddItem!(item),
                child: Row(
                  children: [
                    HnagPhoto(width: 80, height: 80, foodSlug: item.foodSlug, imageUrl: item.imageUrl, radius: HnagRadius.md),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(item.name,
                                  style: HnagType.label.copyWith(color: t.text, fontWeight: FontWeight.w600, fontFamily: HnagFonts.body),
                                )),
                                if (item.tag != null) HnagBadge(label: item.tag!, size: BadgeSize.sm, variant: BadgeVariant.brand),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(item.description,
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                            ),
                            const SizedBox(height: 4),
                            Text(_vnd(item.priceVnd),
                              style: HnagType.label.copyWith(color: t.brand, fontWeight: FontWeight.w700, fontFamily: HnagFonts.body),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: HnagIconButton(
                        icon: 'plus',
                        variant: IconBtnVariant.primary,
                        size: IconBtnSize.sm,
                        onPressed: widget.onAddItem == null ? null : () => widget.onAddItem!(item),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    ];
  }

  Widget _placeholder(SemanticTokens t, String tab) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
    child: Center(
      child: Text('Tab "$tab" — coming soon',
        style: HnagType.bodyLg.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
      ),
    ),
  );
}

class _InfoCard extends StatelessWidget {
  final String icon;
  final String primary;
  final String sub;
  const _InfoCard({required this.icon, required this.primary, required this.sub});

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return HnagCard(
      variant: CardVariant.outline,
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          HnagIcon(icon, size: 18, color: t.brand),
          const SizedBox(height: 4),
          Text(primary, style: HnagType.labelSm.copyWith(color: t.text, fontWeight: FontWeight.w600, fontFamily: HnagFonts.body)),
          Text(sub, textAlign: TextAlign.center, style: HnagType.micro.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),
        ],
      ),
    );
  }
}
