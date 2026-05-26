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

class FoodDetailScreenV2 extends StatefulWidget {
  final FoodDetailDataV2 food;
  final VoidCallback? onCook;
  final VoidCallback? onOrder;
  final VoidCallback? onAddToCart;
  final VoidCallback? onSave;
  final VoidCallback? onShare;

  const FoodDetailScreenV2({
    super.key,
    required this.food,
    this.onCook,
    this.onOrder,
    this.onAddToCart,
    this.onSave,
    this.onShare,
  });

  @override
  State<FoodDetailScreenV2> createState() => _FoodDetailScreenV2State();
}

class _FoodDetailScreenV2State extends State<FoodDetailScreenV2> {
  String _tab = 'Công thức';
  bool _saved = false;

  String _formatPrice(int vnd) => '${(vnd / 1000).round()}k';

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
                                        const HnagIconButton(icon: 'more', variant: IconBtnVariant.glass),
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
                        else if (_tab == 'Quán bán') _placeholderTab(t, '🍽 Tab "Quán bán" — coming soon')
                        else _placeholderTab(t, '📝 Tab "Bài viết" — coming soon'),

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

  Widget _placeholderTab(SemanticTokens t, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 32, 20, 8),
    child: Center(
      child: Text(text,
        style: HnagType.bodyLg.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
      ),
    ),
  );
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
