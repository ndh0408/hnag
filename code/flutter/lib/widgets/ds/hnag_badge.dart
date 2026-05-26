// HnagBadge — small inline pill, mirrors design `Badge`.

import 'package:flutter/material.dart';
import '../../design/tokens.dart';
import '../../design/gradients.dart';
import 'hnag_icon.dart';

enum BadgeSize { sm, md, lg }
enum BadgeVariant { def, brand, soft, outline, success, warning, danger, ai, gradient, glass, dot }

class HnagBadge extends StatelessWidget {
  final String label;
  final BadgeSize size;
  final BadgeVariant variant;
  final String? icon;

  const HnagBadge({
    super.key,
    required this.label,
    this.size = BadgeSize.md,
    this.variant = BadgeVariant.def,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    final s = switch (size) {
      BadgeSize.sm => (h: 20.0, px: 8.0, text: HnagType.micro, gap: 4.0, iconSize: 11.0),
      BadgeSize.md => (h: 24.0, px: 10.0, text: HnagType.labelSm, gap: 5.0, iconSize: 12.0),
      BadgeSize.lg => (h: 28.0, px: 12.0, text: HnagType.label, gap: 6.0, iconSize: 14.0),
    };

    final spec = switch (variant) {
      BadgeVariant.def     => (bg: t.bgMuted, fg: t.text, border: Colors.transparent, gradient: null as Gradient?),
      BadgeVariant.brand   => (bg: t.brand, fg: Colors.white, border: Colors.transparent, gradient: null as Gradient?),
      BadgeVariant.soft    => (bg: t.brandSoft, fg: t.brand, border: Colors.transparent, gradient: null as Gradient?),
      BadgeVariant.outline => (bg: Colors.transparent, fg: t.text, border: t.border, gradient: null as Gradient?),
      BadgeVariant.success => (bg: HnagColors.basil500.withOpacity(0.12), fg: t.success, border: Colors.transparent, gradient: null as Gradient?),
      BadgeVariant.warning => (bg: HnagColors.turmeric500.withOpacity(0.16), fg: HnagColors.turmeric600, border: Colors.transparent, gradient: null as Gradient?),
      BadgeVariant.danger  => (bg: HnagColors.chili500.withOpacity(0.12), fg: t.danger, border: Colors.transparent, gradient: null as Gradient?),
      BadgeVariant.ai      => (bg: HnagColors.ai500.withOpacity(0.12), fg: t.ai, border: Colors.transparent, gradient: null as Gradient?),
      BadgeVariant.gradient=> (bg: t.brand, fg: Colors.white, border: Colors.transparent, gradient: HnagGradients.brand as Gradient?),
      BadgeVariant.glass   => (bg: Colors.white.withOpacity(0.18), fg: Colors.white, border: Colors.white.withOpacity(0.25), gradient: null as Gradient?),
      BadgeVariant.dot     => (bg: Colors.transparent, fg: t.text, border: Colors.transparent, gradient: null as Gradient?),
    };

    return Container(
      height: s.h,
      padding: EdgeInsets.symmetric(horizontal: s.px),
      decoration: BoxDecoration(
        color: spec.gradient == null ? spec.bg : null,
        gradient: spec.gradient,
        borderRadius: BorderRadius.circular(HnagRadius.full),
        border: Border.all(color: spec.border, width: spec.border == Colors.transparent ? 0 : 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (variant == BadgeVariant.dot) ...[
            Container(width: 6, height: 6, decoration: BoxDecoration(color: t.brand, shape: BoxShape.circle)),
            SizedBox(width: s.gap),
          ] else if (icon != null) ...[
            HnagIcon(icon!, size: s.iconSize, color: spec.fg),
            SizedBox(width: s.gap),
          ],
          Text(
            label,
            style: s.text.copyWith(color: spec.fg, fontFamily: HnagFonts.body),
          ),
        ],
      ),
    );
  }
}
