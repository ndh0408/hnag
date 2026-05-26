// HnagTabs — two variants: underline + segmented.

import 'package:flutter/material.dart';
import '../../design/tokens.dart';

enum TabsVariant { underline, segmented }

class HnagTabs extends StatelessWidget {
  final List<String> tabs;
  final String active;
  final ValueChanged<String>? onChanged;
  final TabsVariant variant;

  const HnagTabs({
    super.key,
    required this.tabs,
    required this.active,
    this.onChanged,
    this.variant = TabsVariant.underline,
  });

  @override
  Widget build(BuildContext context) {
    if (variant == TabsVariant.segmented) return _segmented(context);
    return _underline(context);
  }

  Widget _underline(BuildContext context) {
    final t = context.hnag;
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.divider))),
      child: Row(
        children: [
          for (final tab in tabs) ...[
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onChanged == null ? null : () => onChanged!(tab),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  margin: const EdgeInsets.only(right: 24),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: tab == active ? t.brand : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                  child: Text(
                    tab,
                    style: HnagType.label.copyWith(
                      color: tab == active ? t.text : t.textMuted,
                      fontWeight: FontWeight.w600,
                      fontFamily: HnagFonts.body,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _segmented(BuildContext context) {
    final t = context.hnag;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: t.bgMuted, borderRadius: BorderRadius.circular(HnagRadius.md)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final tab in tabs)
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(HnagRadius.sm),
                onTap: onChanged == null ? null : () => onChanged!(tab),
                child: AnimatedContainer(
                  duration: HnagMotion.fast,
                  curve: HnagMotion.out,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: tab == active ? t.bgElev : Colors.transparent,
                    borderRadius: BorderRadius.circular(HnagRadius.sm),
                    boxShadow: tab == active ? t.shadow1 : const [],
                  ),
                  child: Text(
                    tab,
                    style: HnagType.labelSm.copyWith(
                      color: tab == active ? t.text : t.textMuted,
                      fontWeight: tab == active ? FontWeight.w600 : FontWeight.w500,
                      fontFamily: HnagFonts.body,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
