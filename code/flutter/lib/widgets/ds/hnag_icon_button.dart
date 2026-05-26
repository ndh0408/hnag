// HnagIconButton — circular icon-only button. Matches design `IconBtn`.

import 'package:flutter/material.dart';
import '../../design/tokens.dart';
import 'hnag_icon.dart';

enum IconBtnSize { xs, sm, md, lg }

enum IconBtnVariant { ghost, soft, outline, glass, primary }

class HnagIconButton extends StatelessWidget {
  final String icon;
  final IconBtnSize size;
  final IconBtnVariant variant;
  final VoidCallback? onPressed;
  final int? badge;
  final String? semanticsLabel;

  const HnagIconButton({
    super.key,
    required this.icon,
    this.size = IconBtnSize.md,
    this.variant = IconBtnVariant.ghost,
    this.onPressed,
    this.badge,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    final dim = const {IconBtnSize.xs: 28.0, IconBtnSize.sm: 34.0, IconBtnSize.md: 40.0, IconBtnSize.lg: 48.0}[size]!;
    final iconSize = const {IconBtnSize.xs: 14.0, IconBtnSize.sm: 16.0, IconBtnSize.md: 18.0, IconBtnSize.lg: 22.0}[size]!;

    final spec = switch (variant) {
      IconBtnVariant.ghost   => (bg: Colors.transparent, fg: t.text, border: Colors.transparent),
      IconBtnVariant.soft    => (bg: t.bgMuted, fg: t.text, border: Colors.transparent),
      IconBtnVariant.outline => (bg: t.bgElev, fg: t.text, border: t.border),
      IconBtnVariant.glass   => (bg: t.bgGlass, fg: t.text, border: t.border),
      IconBtnVariant.primary => (bg: t.brand, fg: t.brandFg, border: t.brand),
    };

    final btn = Semantics(
      button: true,
      label: semanticsLabel ?? icon,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Ink(
            decoration: BoxDecoration(
              color: spec.bg,
              shape: BoxShape.circle,
              border: Border.all(color: spec.border, width: 1),
            ),
            width: dim,
            height: dim,
            child: Center(child: HnagIcon(icon, size: iconSize, color: spec.fg)),
          ),
        ),
      ),
    );

    if (badge == null) return btn;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        btn,
        Positioned(
          top: -2, right: -2,
          child: Container(
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: t.danger,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: t.bg, width: 2),
            ),
            child: Center(
              child: Text(
                badge! > 99 ? '99+' : '$badge',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600, height: 1, fontFamily: HnagFonts.body),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
