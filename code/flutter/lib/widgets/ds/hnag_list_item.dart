// HnagListItem — settings-style row with icon/leading + title + sub + trailing.

import 'package:flutter/material.dart';
import '../../design/tokens.dart';
import 'hnag_icon.dart';

class HnagListItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? leadingIcon;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;
  final EdgeInsetsGeometry padding;

  const HnagListItem({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.leading,
    this.trailing,
    this.onTap,
    this.danger = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    final titleColor = danger ? t.danger : t.text;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(HnagRadius.md),
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Row(
            children: [
              if (leadingIcon != null)
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: t.bgMuted, borderRadius: BorderRadius.circular(HnagRadius.sm)),
                  child: Center(child: HnagIcon(leadingIcon!, size: 18, color: danger ? t.danger : t.textMuted)),
                )
              else if (leading != null) leading!,
              if (leadingIcon != null || leading != null) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: HnagType.body.copyWith(color: titleColor, fontWeight: FontWeight.w500, fontFamily: HnagFonts.body)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
