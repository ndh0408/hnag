// FoodDetail v2 — hero image + stats row + tags + AI reason + tabs +
// ingredients + recipe steps + sticky Cook/Order CTAs.
// Mirrors design/m-detail.jsx#Screen_FoodDetail.

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/gradients.dart';
import '../../design/theme.dart';
import '../../widgets/ds/ds.dart';

class FoodDetailDataV2 {
  final String id;
  final String name;
  final String? imageUrl;
  final String foodSlug;
  final double rating;
  final int reviewCount;
  final List<String> flavorTags;
  final String region;
  final int priceVnd;
  final int calories;
  final int prepTimeMin;
  final String macroLabel;
  final List<String> hashtags;
  final String aiReason;
  final List<({String name, String qty})> ingredients;
  final int servings;
  final List<({String index, String title, String description})> steps;
  final int totalSteps;
  final bool canCook;
  final bool canDeliver;

  const FoodDetailDataV2({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.foodSlug,
    required this.rating,
    required this.reviewCount,
    required this.flavorTags,
    required this.region,
    required this.priceVnd,
    required this.calories,
    required this.prepTimeMin,
    required this.macroLabel,
    required this.hashtags,
    required this.aiReason,
    required this.ingredients,
    this.servings = 4,
    required this.steps,
    required this.totalSteps,
    this.canCook = true,
    this.canDeliver = true,
  });
}

class FoodPostV2 {
  final String id;
  final String authorName;
  final String? authorAvatarUrl;
  final String caption;
  final String? mediaUrl;
  final int likeCount;
  final int commentCount;
  final DateTime? createdAt;
  const FoodPostV2({
    required this.id,
    required this.authorName,
    this.authorAvatarUrl,
    required this.caption,
    this.mediaUrl,
    this.likeCount = 0,
    this.commentCount = 0,
    this.createdAt,
  });
}

class RestaurantBriefForFood {
  final String id;
  final String name;
  final String? imageUrl;
  final double? rating;
  final int? distanceM;
  final int priceVnd;
  final String? address;
  const RestaurantBriefForFood({
    required this.id,
    required this.name,
    this.imageUrl,
    this.rating,
    this.distanceM,
    required this.priceVnd,
    this.address,
  });
}

class FoodDetailScreenV2 extends StatefulWidget {
  final FoodDetailDataV2 food;
  final VoidCallback? onCook;
  final VoidCallback? onOrder;
  final VoidCallback? onAddToCart;
  final VoidCallback? onSave;
  final VoidCallback? onShare;
  /// Real restaurants serving this food. When non-null, the "Quán bán" tab
  /// renders this list; otherwise shows an empty state.
  final List<RestaurantBriefForFood>? restaurantsServing;
  final void Function(RestaurantBriefForFood)? onTapRestaurant;
  /// Real posts about this food (Bài viết tab).
  final List<FoodPostV2>? posts;
  final void Function(FoodPostV2)? onTapPost;

  const FoodDetailScreenV2({
    super.key,
    required this.food,
    this.onCook,
    this.onOrder,
    this.onAddToCart,
    this.onSave,
    this.onShare,
    this.restaurantsServing,
    this.onTapRestaurant,
    this.posts,
    this.onTapPost,
  });

  @override
  State<FoodDetailScreenV2> createState() => _FoodDetailScreenV2State();
}

class _FoodDetailScreenV2State extends State<FoodDetailScreenV2> {
  String _tab = 'Công thức';
  bool _saved = false;

  String _formatPrice(int vnd) => '${(vnd / 1000).round()}k';

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final t = sheetCtx.hnag;
        Widget row(String icon, String label, VoidCallback onTap) => ListTile(
          leading: HnagIcon(icon, size: 22, color: t.text),
          title: Text(label, style: HnagType.bodyLg.copyWith(color: t.text, fontFamily: HnagFonts.body)),
          onTap: () { Navigator.pop(sheetCtx); onTap(); },
        );
        return Container(
          decoration: BoxDecoration(
            color: t.bgRaised,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 12, top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: t.divider, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 8),
              row('share', 'Chia sẻ món', () => widget.onShare?.call()),
              row('bookmark', 'Lưu vào sưu tập', () => widget.onSave?.call()),
              row('flag', 'Báo cáo nội dung', () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Đã nhận báo cáo. HNAG sẽ xem trong 24h.'),
                ));
              }),
              row('info', 'Về món này', () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('${widget.food.name} · ${widget.food.region} · ${widget.food.calories}cal'),
                ));
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return HnagThemeScope(
      dark: false,
      child: Builder(builder: (context) {
        final t = context.hnag;
        return Scaffold(
          backgroundColor: t.bg,
          body: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 320,
                      pinned: false,
                      stretch: true,
                      backgroundColor: Colors.transparent,
                      automaticallyImplyLeading: false,
                      flexibleSpace: FlexibleSpaceBar(
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            HnagPhoto(
                              imageUrl: widget.food.imageUrl,
                              foodSlug: widget.food.foodSlug,
                              aspectRatio: 4 / 3.2,
                              radius: 0,
                            ),
                            // Top gradient for status bar legibility
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
                            // Top action row
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
                                        const SizedBox(width: 8),
                                        HnagIconButton(icon: 'more', variant: IconBtnVariant.glass, onPressed: () => _showMoreMenu(context)),
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
                        // Header
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
                                        Text(widget.food.name,
                                          style: HnagType.d3.copyWith(color: t.text, fontFamily: HnagFonts.display),
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            HnagIcon('star', size: 14, color: HnagColors.turmeric500),
                                            Text('${widget.food.rating}',
                                              style: HnagType.bodySm.copyWith(color: t.text, fontWeight: FontWeight.w700, fontFamily: HnagFonts.body),
                                            ),
                                            Text('(${widget.food.reviewCount})',
                                              style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                                            ),
                                            Text('·', style: HnagType.bodySm.copyWith(color: t.textMuted)),
                                            for (final tag in widget.food.flavorTags) ...[
                                              Text(tag, style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),
                                              Text('·', style: HnagType.bodySm.copyWith(color: t.textMuted)),
                                            ],
                                            Text(widget.food.region, style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(_formatPrice(widget.food.priceVnd),
                                    style: HnagType.d3.copyWith(color: t.brand, fontFamily: HnagFonts.display),
                                  ),
                                ],
                              ),

                              // Stats row
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(child: _StatChip(icon: 'flame', label: '${widget.food.calories} cal', sub: 'năng lượng')),
                                  const SizedBox(width: 8),
                                  Expanded(child: _StatChip(icon: 'clock', label: '${widget.food.prepTimeMin} phút', sub: 'thời gian')),
                                  const SizedBox(width: 8),
                                  Expanded(child: _StatChip(icon: 'leaf', label: widget.food.macroLabel, sub: 'macro')),
                                ],
                              ),

                              // Hashtag chips
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 6, runSpacing: 6,
                                children: [
                                  for (final h in widget.food.hashtags)
                                    HnagBadge(label: h, size: BadgeSize.sm),
                                ],
                              ),

                              // AI reason
                              const SizedBox(height: 14),
                              HnagCard(
                                variant: CardVariant.soft,
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 28, height: 28,
                                      decoration: const BoxDecoration(gradient: HnagGradients.ai, shape: BoxShape.circle),
                                      child: const Center(child: HnagIcon('sparkle', size: 14, color: Colors.white)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        '"${widget.food.aiReason}" — Hà',
                                        style: HnagType.bodySm.copyWith(color: t.text, fontStyle: FontStyle.italic, fontFamily: HnagFonts.body),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: HnagTabs(
                            tabs: const ['Công thức', 'Quán bán', 'Bài viết'],
                            active: _tab,
                            onChanged: (v) => setState(() => _tab = v),
                          ),
                        ),

                        if (_tab == 'Công thức') ..._buildRecipe(t)
                        else if (_tab == 'Quán bán') _buildRestaurants(t)
                        else _buildPosts(t),

                        const SizedBox(height: 32),
                      ]),
                    ),
                  ],
                ),
              ),

              // Sticky CTA
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                  color: t.bg.withOpacity(0.95),
                  border: Border(top: BorderSide(color: t.divider)),
                ),
                child: Row(
                  children: [
                    if (widget.food.canCook) ...[
                      Expanded(
                        child: HnagButton(
                          label: 'Cook now',
                          iconLeading: 'flame',
                          variant: BtnVariant.secondary,
                          size: BtnSize.lg,
                          fullWidth: true,
                          onPressed: widget.onCook,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (widget.food.canDeliver)
                      Expanded(
                        child: HnagButton(
                          label: 'Đặt giao ${_formatPrice(widget.food.priceVnd)}',
                          iconLeading: 'package',
                          variant: BtnVariant.primary,
                          size: BtnSize.lg,
                          fullWidth: true,
                          onPressed: widget.onOrder ?? widget.onAddToCart,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  List<Widget> _buildRecipe(SemanticTokens t) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Nguyên liệu',
                  style: HnagType.h4.copyWith(color: t.text, fontFamily: HnagFonts.display),
                )),
                HnagBadge(label: '${widget.food.servings} người', size: BadgeSize.sm),
              ],
            ),
            const SizedBox(height: 10),
            HnagCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < widget.food.ingredients.length; i++) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Container(width: 6, height: 6,
                            decoration: BoxDecoration(color: t.brand, shape: BoxShape.circle)),
                          const SizedBox(width: 12),
                          Expanded(child: Text(widget.food.ingredients[i].name,
                            style: HnagType.body.copyWith(color: t.text, fontFamily: HnagFonts.body),
                          )),
                          Text(widget.food.ingredients[i].qty,
                            style: HnagType.mono.copyWith(color: t.textMuted),
                          ),
                        ],
                      ),
                    ),
                    if (i < widget.food.ingredients.length - 1) const HnagDivider(),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            HnagCard(
              variant: CardVariant.soft,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  HnagIcon('cart', size: 20, color: t.brand),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mua qua BachhoaXANH',
                          style: HnagType.label.copyWith(color: t.text, fontWeight: FontWeight.w600, fontFamily: HnagFonts.body),
                        ),
                        const SizedBox(height: 1),
                        Text('Giao 30 phút · ~85k',
                          style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                        ),
                      ],
                    ),
                  ),
                  const HnagButton(label: 'Đặt', size: BtnSize.sm),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Text('Cách làm', style: HnagType.h4.copyWith(color: t.text, fontFamily: HnagFonts.display)),
            const SizedBox(height: 10),
            HnagCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < widget.food.steps.length; i++) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(color: t.bgMuted, borderRadius: BorderRadius.circular(HnagRadius.sm)),
                            alignment: Alignment.center,
                            child: Text(widget.food.steps[i].index,
                              style: HnagType.label.copyWith(color: t.brand, fontWeight: FontWeight.w700, fontFamily: HnagFonts.body),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.food.steps[i].title,
                                  style: HnagType.label.copyWith(color: t.text, fontWeight: FontWeight.w600, fontFamily: HnagFonts.body),
                                ),
                                const SizedBox(height: 2),
                                Text(widget.food.steps[i].description,
                                  style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (i < widget.food.steps.length - 1) const HnagDivider(),
                  ],
                ],
              ),
            ),
            if (widget.food.steps.length < widget.food.totalSteps)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('+ ${widget.food.totalSteps - widget.food.steps.length} bước nữa',
                  textAlign: TextAlign.center,
                  style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                ),
              ),
          ],
        ),
      ),
    ];
  }

  Widget _buildRestaurants(SemanticTokens t) {
    final list = widget.restaurantsServing;
    if (list == null || list.isEmpty) return _placeholderTab(t, 'Quán bán');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        children: [
          for (final r in list) ...[
            HnagCard(
              padding: EdgeInsets.zero,
              onTap: widget.onTapRestaurant == null ? null : () => widget.onTapRestaurant!(r),
              child: Row(
                children: [
                  HnagPhoto(width: 88, height: 88, imageUrl: r.imageUrl, foodSlug: widget.food.foodSlug, radius: HnagRadius.md),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: HnagType.label.copyWith(color: t.text, fontWeight: FontWeight.w700, fontFamily: HnagFonts.body),
                          ),
                          const SizedBox(height: 2),
                          if (r.address != null && r.address!.isNotEmpty)
                            Text(r.address!,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                            ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (r.rating != null) ...[
                                const HnagIcon('star', size: 14, color: HnagColors.turmeric500),
                                const SizedBox(width: 2),
                                Text(r.rating!.toStringAsFixed(1),
                                  style: HnagType.bodySm.copyWith(color: t.text, fontFamily: HnagFonts.body),
                                ),
                                const SizedBox(width: 10),
                              ],
                              if (r.distanceM != null) ...[
                                HnagIcon('pin', size: 14, color: t.textMuted),
                                const SizedBox(width: 2),
                                Text(r.distanceM! < 1000 ? '${r.distanceM}m' : '${(r.distanceM! / 1000).toStringAsFixed(1)}km',
                                  style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                                ),
                                const SizedBox(width: 10),
                              ],
                              Text('${(r.priceVnd / 1000).round()}k',
                                style: HnagType.bodySm.copyWith(color: t.brand, fontWeight: FontWeight.w700, fontFamily: HnagFonts.body),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: HnagIcon('chevR', size: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildPosts(SemanticTokens t) {
    final posts = widget.posts;
    if (posts == null) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator()));
    }
    if (posts.isEmpty) return _placeholderTab(t, 'Bài viết');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(children: [
        for (final p in posts) ...[
          HnagCard(
            padding: EdgeInsets.zero,
            onTap: widget.onTapPost == null ? null : () => widget.onTapPost!(p),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (p.mediaUrl != null && p.mediaUrl!.isNotEmpty)
                  HnagPhoto(imageUrl: p.mediaUrl, aspectRatio: 16 / 10, foodSlug: widget.food.foodSlug, radius: HnagRadius.md),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        HnagAvatar(name: p.authorName, imageUrl: p.authorAvatarUrl, size: 32),
                        const SizedBox(width: 8),
                        Text(p.authorName,
                          style: HnagType.label.copyWith(color: t.text, fontWeight: FontWeight.w600, fontFamily: HnagFonts.body),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Text(p.caption,
                        maxLines: 3, overflow: TextOverflow.ellipsis,
                        style: HnagType.body.copyWith(color: t.text, fontFamily: HnagFonts.body),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        HnagIcon('heart', size: 14, color: t.textMuted),
                        const SizedBox(width: 4),
                        Text('${p.likeCount}', style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),
                        const SizedBox(width: 12),
                        HnagIcon('chat', size: 14, color: t.textMuted),
                        const SizedBox(width: 4),
                        Text('${p.commentCount}', style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ]),
    );
  }

  Widget _placeholderTab(SemanticTokens t, String text) {
    // Graceful empty state instead of "coming soon" copy.
    final isShop = text.contains('Quán');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isShop ? '🍽️' : '📝', style: HnagType.d3),
            const SizedBox(height: 8),
            Text(isShop ? 'Chưa có quán phục vụ món này' : 'Chưa có bài viết',
              textAlign: TextAlign.center,
              style: HnagType.h4.copyWith(color: t.text, fontFamily: HnagFonts.display),
            ),
            const SizedBox(height: 4),
            Text(isShop ? 'Thử tìm món gần bạn hơn nha' : 'Hãy là người đầu tiên đăng bài',
              textAlign: TextAlign.center,
              style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String icon;
  final String label;
  final String sub;
  const _StatChip({required this.icon, required this.label, required this.sub});

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: t.bgMuted, borderRadius: BorderRadius.circular(HnagRadius.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HnagIcon(icon, size: 18, color: t.brand),
          const SizedBox(height: 4),
          Text(label, style: HnagType.label.copyWith(color: t.text, fontWeight: FontWeight.w600, fontFamily: HnagFonts.body)),
          Text(sub, style: HnagType.micro.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),
        ],
      ),
    );
  }
}
