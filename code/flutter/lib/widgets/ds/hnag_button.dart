// HnagButton — mirrors design `Btn` (primitives.jsx)
// Sizes: xs/sm/md/lg/xl. Variants: primary, gradient, secondary, ghost,
// outline, soft, danger, success, glass, dark.

import 'package:flutter/material.dart';
import '../../design/tokens.dart';
import '../../design/gradients.dart';
import 'hnag_icon.dart';

enum BtnSize { xs, sm, md, lg, xl }

enum BtnVariant {
  primary,
  gradient,
  secondary,
  ghost,
  outline,
  soft,
  danger,
  success,
  glass,
  dark,
}

class HnagButton extends StatefulWidget {
  final String label;
  final BtnSize size;
  final BtnVariant variant;
  final String? iconLeading;
  final String? iconTrailing;
  final bool fullWidth;
  final VoidCallback? onPressed;
  final bool loading;

  const HnagButton({
    super.key,
    required this.label,
    this.size = BtnSize.md,
    this.variant = BtnVariant.primary,
    this.iconLeading,
    this.iconTrailing,
    this.fullWidth = false,
    this.onPressed,
    this.loading = false,
  });

  @override
  State<HnagButton> createState() => _HnagButtonState();
}

class _HnagButtonState extends State<HnagButton> {
  bool _pressed = false;

  ({double h, double px, TextStyle text, double gap, double iconSize, double r}) _sizeSpec() {
    switch (widget.size) {
      case BtnSize.xs: return (h: 28, px: 10, text: HnagType.labelSm.copyWith(fontWeight: FontWeight.w600), gap: 5,  iconSize: 14, r: HnagRadius.sm);
      case BtnSize.sm: return (h: 34, px: 12, text: HnagType.label.copyWith(fontWeight: FontWeight.w600),   gap: 6,  iconSize: 16, r: HnagRadius.sm);
      case BtnSize.md: return (h: 40, px: 16, text: HnagType.label.copyWith(fontWeight: FontWeight.w600),   gap: 7,  iconSize: 16, r: HnagRadius.md);
      case BtnSize.lg: return (h: 48, px: 20, text: HnagType.bodyLg.copyWith(fontWeight: FontWeight.w600),  gap: 8,  iconSize: 18, r: HnagRadius.md);
      case BtnSize.xl: return (h: 56, px: 24, text: const TextStyle(fontSize: 17, height: 1, fontWeight: FontWeight.w600), gap: 8, iconSize: 20, r: HnagRadius.lg);
    }
  }

  ({Color bg, Color? bgGradientStart, Color fg, Color border, List<BoxShadow> shadow, Gradient? gradient}) _variantSpec(SemanticTokens t) {
    switch (widget.variant) {
      case BtnVariant.primary:
        return (bg: t.brand, bgGradientStart: null, fg: t.brandFg, border: t.brand, shadow: t.shadow2, gradient: null);
      case BtnVariant.gradient:
        return (bg: t.brand, bgGradientStart: null, fg: Colors.white, border: Colors.transparent, shadow: t.glow, gradient: HnagGradients.brand);
      case BtnVariant.secondary:
        return (bg: t.bgElev, bgGradientStart: null, fg: t.text, border: t.border, shadow: t.shadow1, gradient: null);
      case BtnVariant.ghost:
        return (bg: Colors.transparent, bgGradientStart: null, fg: t.text, border: Colors.transparent, shadow: const [], gradient: null);
      case BtnVariant.outline:
        return (bg: Colors.transparent, bgGradientStart: null, fg: t.text, border: t.borderStrong, shadow: const [], gradient: null);
      case BtnVariant.soft:
        return (bg: t.brandSoft, bgGradientStart: null, fg: t.brand, border: Colors.transparent, shadow: const [], gradient: null);
      case BtnVariant.danger:
        return (bg: t.danger, bgGradientStart: null, fg: Colors.white, border: t.danger, shadow: t.shadow2, gradient: null);
      case BtnVariant.success:
        return (bg: t.success, bgGradientStart: null, fg: Colors.white, border: t.success, shadow: t.shadow2, gradient: null);
      case BtnVariant.glass:
        return (bg: t.bgGlass, bgGradientStart: null, fg: t.text, border: t.border, shadow: t.shadow2, gradient: null);
      case BtnVariant.dark:
        return (bg: HnagColors.neutral900, bgGradientStart: null, fg: Colors.white, border: HnagColors.neutral800, shadow: const [], gradient: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    final s = _sizeSpec();
    final v = _variantSpec(t);
    final disabled = widget.onPressed == null || widget.loading;

    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (widget.loading)
          SizedBox(
            width: s.iconSize, height: s.iconSize,
            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(v.fg)),
          )
        else if (widget.iconLeading != null)
          HnagIcon(widget.iconLeading!, size: s.iconSize, color: v.fg),
        if ((widget.iconLeading != null || widget.loading) && widget.label.isNotEmpty)
          SizedBox(width: s.gap),
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: s.text.copyWith(color: v.fg, fontFamily: HnagFonts.body),
          ),
        ),
        if (widget.iconTrailing != null) ...[
          SizedBox(width: s.gap),
          HnagIcon(widget.iconTrailing!, size: s.iconSize, color: v.fg),
        ],
      ],
    );

    final decoration = BoxDecoration(
      gradient: v.gradient,
      color: v.gradient == null ? v.bg : null,
      borderRadius: BorderRadius.circular(s.r),
      border: Border.all(color: v.border, width: 1),
      boxShadow: disabled ? const [] : v.shadow,
    );

    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: disabled ? null : widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: HnagMotion.fast,
          curve: HnagMotion.out,
          child: AnimatedContainer(
            duration: HnagMotion.fast,
            curve: HnagMotion.out,
            height: s.h,
            width: widget.fullWidth ? double.infinity : null,
            padding: EdgeInsets.symmetric(horizontal: s.px),
            decoration: decoration,
            alignment: Alignment.center,
            child: content,
          ),
        ),
      ),
    );
  }
}
