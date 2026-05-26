// HnagChip — clickable / toggleable filter pill. Mirrors design `Chip`.

import 'package:flutter/material.dart';
import '../../design/tokens.dart';
import 'hnag_icon.dart';

enum ChipSize { sm, md, lg }

class HnagChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;
  final String? icon;
  final ChipSize size;

  const HnagChip({
    super.key,
    required this.label,
    this.active = false,
    this.onTap,
    this.icon,
    this.size = ChipSize.md,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    final s = switch (size) {
      ChipSize.sm => (h: 28.0, px: 10.0, text: HnagType.labelSm, iconSize: 13.0),
      ChipSize.md => (h: 34.0, px: 12.0, text: HnagType.label, iconSize: 15.0),
      ChipSize.lg => (h: 40.0, px: 14.0, text: HnagType.body, iconSize: 16.0),
    };
    final bg = active ? t.text : t.bgElev;
    final fg = active ? t.bg : t.text;
    final border = active ? t.text : t.border;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(HnagRadius.full),
        onTap: onTap,
        child: AnimatedContainer(
          duration: HnagMotion.fast,
          curve: HnagMotion.out,
          height: s.h,
          padding: EdgeInsets.symmetric(horizontal: s.px),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(HnagRadius.full),
            border: Border.all(color: border, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                HnagIcon(icon!, size: s.iconSize, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: s.text.copyWith(color: fg, fontWeight: active ? FontWeight.w600 : FontWeight.w500, fontFamily: HnagFonts.body),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
