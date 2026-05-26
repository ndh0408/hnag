// HnagPhoto — placeholder image box. In dev / design canvas it shows a striped
// gradient; in prod replace via CachedNetworkImage by passing `imageUrl`.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../design/tokens.dart';
import '../../design/food_gradients.dart';

class HnagPhoto extends StatelessWidget {
  final double? width;
  final double? height;
  final double aspectRatio;
  final String? imageUrl;
  final String? foodSlug; // picks a FoodGradients gradient
  final Gradient? gradient;
  final String? label;
  final Widget? overlay;
  final double radius;
  final BoxFit fit;

  const HnagPhoto({
    super.key,
    this.width,
    this.height,
    this.aspectRatio = 1,
    this.imageUrl,
    this.foodSlug,
    this.gradient,
    this.label,
    this.overlay,
    this.radius = HnagRadius.md,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    final g = gradient ?? (foodSlug != null ? FoodGradients.bySeed(foodSlug!) : null);

    Widget content;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      content = CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width, height: height, fit: fit,
        placeholder: (_, __) => DecoratedBox(
          decoration: BoxDecoration(gradient: g ?? LinearGradient(colors: [t.bgMuted, t.bgMuted])),
        ),
        errorWidget: (_, __, ___) => DecoratedBox(
          decoration: BoxDecoration(gradient: g ?? LinearGradient(colors: [t.bgMuted, t.bgMuted])),
        ),
      );
    } else {
      content = Container(
        decoration: BoxDecoration(
          gradient: g,
          color: g == null ? t.bgMuted : null,
        ),
        child: label == null
            ? null
            : Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(label!, style: HnagType.mono.copyWith(color: Colors.black.withOpacity(0.6))),
                ),
              ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height ?? (width != null ? width! / aspectRatio : null),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AspectRatio(aspectRatio: aspectRatio, child: content),
            if (overlay != null) overlay!,
          ],
        ),
      ),
    );
  }
}
