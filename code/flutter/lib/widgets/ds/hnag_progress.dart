// HnagProgress — horizontal progress bar.

import 'package:flutter/material.dart';
import '../../design/tokens.dart';

class HnagProgress extends StatelessWidget {
  final double value;
  final double max;
  final double height;
  final Color? color;

  const HnagProgress({
    super.key,
    required this.value,
    this.max = 100,
    this.height = 6,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    final pct = (value / max).clamp(0.0, 1.0);
    return Container(
      height: height,
      decoration: BoxDecoration(color: t.bgMuted, borderRadius: BorderRadius.circular(height / 2)),
      clipBehavior: Clip.hardEdge,
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedFractionallySizedBox(
          duration: HnagMotion.base,
          curve: HnagMotion.out,
          widthFactor: pct,
          child: Container(
            decoration: BoxDecoration(color: color ?? t.brand, borderRadius: BorderRadius.circular(height / 2)),
          ),
        ),
      ),
    );
  }
}

class HnagStatusDot extends StatelessWidget {
  final String status; // online | away | busy | offline
  final double size;
  const HnagStatusDot({super.key, this.status = 'online', this.size = 8});

  static const Map<String, Color> _colors = {
    'online': HnagColors.basil400,
    'away':   HnagColors.turmeric500,
    'busy':   HnagColors.chili500,
    'offline':HnagColors.neutral500,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: _colors[status] ?? HnagColors.basil400, shape: BoxShape.circle),
    );
  }
}

class HnagDivider extends StatelessWidget {
  final bool vertical;
  const HnagDivider({super.key, this.vertical = false});

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return vertical
        ? Container(width: 1, color: t.divider)
        : Container(height: 1, color: t.divider);
  }
}
