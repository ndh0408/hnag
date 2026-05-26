// HnagCard — flexible card matching design `Card` primitive.
// Variants: default, raised, elevated, glass, flat, outline, dashed, gradient, dark, soft.

import 'package:flutter/material.dart';
import '../../design/tokens.dart';
import '../../design/gradients.dart';

enum CardVariant { def, raised, elevated, glass, flat, outline, dashed, gradient, dark, soft }

class HnagCard extends StatelessWidget {
  final CardVariant variant;
  final EdgeInsetsGeometry padding;
  final Widget? child;
  final VoidCallback? onTap;
  final double radius;
  final double? width;
  final double? height;

  const HnagCard({
    super.key,
    this.variant = CardVariant.def,
    this.padding = const EdgeInsets.all(HnagSpacing.s4),
    this.child,
    this.onTap,
    this.radius = HnagRadius.lg,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    final spec = switch (variant) {
      CardVariant.def      => (bg: t.bgElev, border: t.border, dashed: false, shadow: t.shadow1, gradient: null, fg: t.text),
      CardVariant.raised   => (bg: t.bgRaised, border: t.border, dashed: false, shadow: t.shadow2, gradient: null, fg: t.text),
      CardVariant.elevated => (bg: t.bgElev, border: t.border, dashed: false, shadow: t.shadow3, gradient: null, fg: t.text),
      CardVariant.glass    => (bg: t.bgGlass, border: t.border, dashed: false, shadow: t.shadow2, gradient: null, fg: t.text),
      CardVariant.flat     => (bg: t.bgMuted, border: Colors.transparent, dashed: false, shadow: const <BoxShadow>[], gradient: null, fg: t.text),
      CardVariant.outline  => (bg: Colors.transparent, border: t.border, dashed: false, shadow: const <BoxShadow>[], gradient: null, fg: t.text),
      CardVariant.dashed   => (bg: Colors.transparent, border: t.borderStrong, dashed: true, shadow: const <BoxShadow>[], gradient: null, fg: t.text),
      CardVariant.gradient => (bg: t.brand, border: Colors.transparent, dashed: false, shadow: t.glow, gradient: HnagGradients.brand, fg: Colors.white),
      CardVariant.dark     => (bg: HnagColors.neutral900, border: HnagColors.neutral800, dashed: false, shadow: t.shadow3, gradient: null, fg: Colors.white),
      CardVariant.soft     => (bg: t.brandSoft, border: HnagColors.brand500.withOpacity(0.18), dashed: false, shadow: const <BoxShadow>[], gradient: null, fg: t.text),
    };

    final body = AnimatedContainer(
      duration: HnagMotion.fast,
      curve: HnagMotion.out,
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: spec.gradient,
        color: spec.gradient == null ? spec.bg : null,
        borderRadius: BorderRadius.circular(radius),
        border: spec.dashed
            ? null
            : Border.all(color: spec.border, width: 1),
        boxShadow: spec.shadow,
      ),
      child: spec.dashed
          ? _DashedBorder(
              radius: radius,
              color: spec.border,
              child: Padding(padding: padding, child: DefaultTextStyle.merge(style: TextStyle(color: spec.fg), child: child ?? const SizedBox.shrink())),
            )
          : Padding(padding: padding, child: DefaultTextStyle.merge(style: TextStyle(color: spec.fg), child: child ?? const SizedBox.shrink())),
    );

    if (onTap == null) return body;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: body,
      ),
    );
  }
}

class _DashedBorder extends StatelessWidget {
  final double radius;
  final Color color;
  final Widget child;
  const _DashedBorder({required this.radius, required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedPainter(radius: radius, color: color),
      child: child,
    );
  }
}

class _DashedPainter extends CustomPainter {
  final double radius;
  final Color color;
  _DashedPainter({required this.radius, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final rect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rect);
    const dash = 6.0, gap = 4.0;
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        final next = (dist + dash).clamp(0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(dist, next), paint);
        dist += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPainter old) => old.radius != radius || old.color != color;
}
