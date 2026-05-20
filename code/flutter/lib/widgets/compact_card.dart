import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/food_card.dart';
import '../theme/app_theme.dart';

/// Vertical compact card (9:16) used in horizontal carousels of the home feed.
class CompactCard extends StatelessWidget {
  final FoodCard card;
  final VoidCallback? onTap;

  const CompactCard({super.key, required this.card, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: SizedBox(
          width: 168, // ~9:16 at 300 tall
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: card.media.poster,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: const Color(0xFF222226)),
                errorWidget: (_, __, ___) => Container(color: const Color(0xFF222226)),
              ),
              // Bottom gradient
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 28, 10, 10),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0xCC000000)],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(card.title, style: AppTypography.bodyMd.copyWith(color: Colors.white, fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(children: [
                        Text(card.price.display, style: AppTypography.caption.copyWith(color: Colors.white)),
                        const SizedBox(width: 6),
                        const Text('·', style: TextStyle(color: Colors.white54)),
                        const SizedBox(width: 6),
                        Text(card.distance.display, style: AppTypography.caption.copyWith(color: Colors.white70)),
                        const Spacer(),
                        const Icon(Icons.star_rounded, size: 12, color: AppColors.turmeric),
                        const SizedBox(width: 2),
                        Text(card.rating.avg.toStringAsFixed(1), style: AppTypography.caption.copyWith(color: Colors.white)),
                      ]),
                    ],
                  ),
                ),
              ),
              // Top badge (first one, if exists)
              if (card.badges.isNotEmpty)
                Positioned(
                  top: 10, left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.phoOrange,
                      borderRadius: BorderRadius.circular(AppRadii.full),
                    ),
                    child: Text(card.badges.first.icon, style: const TextStyle(fontSize: 11)),
                  ),
                ),
              // Live status dot
              if (card.liveStatus?.isOpen ?? false)
                Positioned(
                  top: 10, right: 10,
                  child: Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: AppColors.success.withOpacity(0.5), blurRadius: 8)],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
