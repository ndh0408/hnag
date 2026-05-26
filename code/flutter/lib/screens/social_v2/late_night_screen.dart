// Late Night Mode 🌙 — dark gradient bg, "tonight only" curated picks,
// + 24h delivery filter.
// Mirrors design/m-utility.jsx#Screen_LateNight.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../design/tokens.dart';
import '../../design/gradients.dart';
import '../../design/food_gradients.dart';
import '../../design/theme.dart';
import '../../widgets/ds/ds.dart';

class LateNightItem {
  final String id;
  final String name;
  final String? imageUrl;
  final String foodSlug;
  final int priceVnd;
  final String etaText;
  final String tag; // e.g. "Mở 24h" / "Đang mở" / "Còn 30p"
  const LateNightItem({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.foodSlug,
    required this.priceVnd,
    required this.etaText,
    this.tag = 'Mở 24h',
  });
}

class LateNightScreen extends StatelessWidget {
  final List<LateNightItem> items;
  final ValueChanged<LateNightItem>? onTap;
  final VoidCallback? onClose;
  final String? heroQuote;
  const LateNightScreen({
    super.key,
    required this.items,
    this.onTap,
    this.onClose,
    this.heroQuote,
  });

  @override
  Widget build(BuildContext context) {
    return HnagThemeScope(
      dark: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Night gradient bg
            const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: HnagGradients.night))),
            const Positioned.fill(child: AuroraBackground(opacity: 0.25)),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        HnagIconButton(
                          icon: 'chevL',
                          variant: IconBtnVariant.glass,
                          onPressed: onClose ?? () => Navigator.maybePop(context),
                        ),
                        const Spacer(),
                        const HnagBadge(label: '🌙 Khuya · 23:14', variant: BadgeVariant.glass),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          heroQuote ?? 'Đói khuya?\nHà tìm quán còn mở 🌙',
                          style: HnagType.d2.copyWith(color: Colors.white, fontFamily: HnagFonts.display, letterSpacing: -1.2),
                        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
                        const SizedBox(height: 8),
                        Text('5 quán quanh bạn còn mở · ưu tiên 24h',
                          style: HnagType.bodyLg.copyWith(color: Colors.white.withOpacity(0.7), fontFamily: HnagFonts.body),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final it = items[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _LateNightCard(item: it, onTap: onTap == null ? null : () => onTap!(it)),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LateNightCard extends StatelessWidget {
  final LateNightItem item;
  final VoidCallback? onTap;
  const _LateNightCard({required this.item, this.onTap});

  String _vnd(int v) => '${(v / 1000).round()}k';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
          borderRadius: BorderRadius.circular(HnagRadius.lg),
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(HnagRadius.md),
              child: SizedBox(
                width: 76, height: 76,
                child: HnagPhoto(foodSlug: item.foodSlug, imageUrl: item.imageUrl, aspectRatio: 1, radius: HnagRadius.md),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(item.name,
                        style: HnagType.h4.copyWith(color: Colors.white, fontFamily: HnagFonts.display),
                      )),
                      const HnagIcon('moon', color: Colors.white, size: 14),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(item.tag,
                    style: HnagType.bodySm.copyWith(color: Colors.white.withOpacity(0.7), fontFamily: HnagFonts.body),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(_vnd(item.priceVnd),
                        style: HnagType.label.copyWith(color: HnagColors.turmeric500, fontWeight: FontWeight.w700, fontFamily: HnagFonts.body),
                      ),
                      const Text(' · ', style: TextStyle(color: Colors.white54)),
                      Text(item.etaText,
                        style: HnagType.bodySm.copyWith(color: Colors.white.withOpacity(0.8), fontFamily: HnagFonts.body),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const HnagIcon('chevR', color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}
