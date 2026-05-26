// FoodCardLarge — reusable big card for AI suggestion + Card Stack.
// Mirrors design/m-home.jsx#FoodCardLarge.

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/gradients.dart';
import '../../widgets/ds/ds.dart';

class FoodCardLargeData {
  final String id;
  final String name;
  final String? imageUrl;
  final String foodSlug; // for gradient fallback
  final String price;
  final String calories;
  final String time;
  final String rating;
  final String kind;       // 'cook' | 'order' | 'pin'
  final String kindLabel;  // "Giao tận nơi" / "Tự nấu" / "Đi ăn · 200m"
  final String reason;

  const FoodCardLargeData({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.foodSlug,
    required this.price,
    required this.calories,
    required this.time,
    required this.rating,
    required this.kind,
    required this.kindLabel,
    required this.reason,
  });
}

class FoodCardLarge extends StatelessWidget {
  final FoodCardLargeData food;
  final bool showActions;
  final VoidCallback? onCook;
  final VoidCallback? onOrder;
  final VoidCallback? onDine;
  final VoidCallback? onTap;

  const FoodCardLarge({
    super.key,
    required this.food,
    this.showActions = false,
    this.onCook,
    this.onOrder,
    this.onDine,
    this.onTap,
  });

  String _kindIcon() => switch (food.kind) {
    'cook'  => 'flame',
    'order' => 'package',
    _       => 'pin',
  };

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return HnagCard(
      variant: CardVariant.elevated,
      padding: EdgeInsets.zero,
      radius: HnagRadius.xl,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              children: [
                Positioned.fill(
                  child: HnagPhoto(
                    imageUrl: food.imageUrl,
                    foodSlug: food.foodSlug,
                    aspectRatio: 4 / 3,
                    radius: HnagRadius.xl,
                  ),
                ),
                // Top badges
                Positioned(
                  top: 12, left: 12, right: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      HnagBadge(label: food.kindLabel, icon: _kindIcon(), variant: BadgeVariant.glass),
                      HnagBadge(label: food.rating, icon: 'star', variant: BadgeVariant.glass),
                    ],
                  ),
                ),
                // Bottom gradient
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
                          stops: const [0.6, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                // Bottom text
                Positioned(
                  left: 14, right: 14, bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(food.name,
                        style: HnagType.h1.copyWith(
                          color: Colors.white, fontFamily: HnagFonts.display,
                          shadows: const [Shadow(color: Color(0x4D000000), offset: Offset(0, 2), blurRadius: 12)],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(food.price, style: HnagType.label.copyWith(color: Colors.white, fontFamily: HnagFonts.body)),
                          _dot(),
                          Text(food.calories, style: HnagType.label.copyWith(color: Colors.white.withOpacity(0.9), fontFamily: HnagFonts.body)),
                          _dot(),
                          Text(food.time, style: HnagType.label.copyWith(color: Colors.white.withOpacity(0.9), fontFamily: HnagFonts.body)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // AI reason
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: const BoxDecoration(gradient: HnagGradients.ai, shape: BoxShape.circle),
                      child: const Center(child: HnagIcon('sparkle', size: 14, color: Colors.white)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: HnagType.bodySm.copyWith(color: t.text, fontFamily: HnagFonts.body),
                          children: [
                            TextSpan(text: '"${food.reason}"', style: const TextStyle(fontStyle: FontStyle.italic)),
                            TextSpan(text: ' — Hà', style: TextStyle(color: t.textMuted)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (showActions) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: HnagButton(label: 'Nấu', iconLeading: 'flame', variant: BtnVariant.secondary, size: BtnSize.sm, onPressed: onCook)),
                      const SizedBox(width: 6),
                      Expanded(child: HnagButton(label: 'Giao', iconLeading: 'package', variant: BtnVariant.secondary, size: BtnSize.sm, onPressed: onOrder)),
                      const SizedBox(width: 6),
                      Expanded(child: HnagButton(label: 'Đi ăn', iconLeading: 'pin', variant: BtnVariant.primary, size: BtnSize.sm, onPressed: onDine)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 6),
    child: SizedBox(
      width: 3, height: 3,
      child: DecoratedBox(decoration: BoxDecoration(color: Color(0x99FFFFFF), shape: BoxShape.circle)),
    ),
  );
}
