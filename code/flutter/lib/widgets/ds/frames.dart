// HnagAppBar + HnagMobileNav — mirrors design `AppBar` + `MobileNav`.
// PhoneFrame here is just for the showcase preview; real app uses the device's
// status bar / safe area.

import 'package:flutter/material.dart';
import '../../design/tokens.dart';
import '../../design/gradients.dart';
import 'hnag_icon.dart';

class HnagAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final bool large;
  final bool transparent;

  const HnagAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.large = false,
    this.transparent = false,
  });

  @override
  Size get preferredSize => Size.fromHeight(large ? 80 : 56);

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return Container(
      height: preferredSize.height,
      padding: EdgeInsets.fromLTRB(20, large ? 8 : 6, 20, large ? 14 : 10),
      decoration: BoxDecoration(
        color: transparent ? Colors.transparent : t.bg,
        border: transparent ? null : Border(bottom: BorderSide(color: t.divider)),
      ),
      child: Row(
        crossAxisAlignment: large ? CrossAxisAlignment.end : CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 10)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: (large ? HnagType.h1 : HnagType.h3).copyWith(
                    color: t.text, fontFamily: HnagFonts.display,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),
                ],
              ],
            ),
          ),
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            actions[i],
          ],
        ],
      ),
    );
  }
}

class HnagMobileNavItem {
  final String key;
  final String icon;
  final String label;
  const HnagMobileNavItem({required this.key, required this.icon, required this.label});
}

class HnagMobileNav extends StatelessWidget {
  final String active;
  final ValueChanged<String> onTap;
  final List<HnagMobileNavItem> items;
  final bool glass;
  final VoidCallback? onCenterTap;

  static const List<HnagMobileNavItem> defaultItems = [
    HnagMobileNavItem(key: 'home',    icon: 'home',    label: 'Trang chủ'),
    HnagMobileNavItem(key: 'explore', icon: 'search',  label: 'Khám phá'),
    HnagMobileNavItem(key: 'ai',      icon: 'sparkle', label: ''),
    HnagMobileNavItem(key: 'feed',    icon: 'play',    label: 'Feed'),
    HnagMobileNavItem(key: 'me',      icon: 'user',    label: 'Tôi'),
  ];

  const HnagMobileNav({
    super.key,
    required this.active,
    required this.onTap,
    this.items = defaultItems,
    this.glass = false,
    this.onCenterTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      decoration: BoxDecoration(
        color: glass ? t.bgGlass : t.bg,
        border: Border(top: BorderSide(color: glass ? t.border : Colors.transparent)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final it in items)
              if (it.key == 'ai')
                _FabCenter(onTap: onCenterTap ?? () => onTap(it.key))
              else
                Expanded(
                  child: _NavItem(
                    item: it,
                    active: active == it.key,
                    onTap: () => onTap(it.key),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final HnagMobileNavItem item;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({required this.item, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(HnagRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HnagIcon(item.icon, size: 22, color: active ? t.text : t.textFaint),
            const SizedBox(height: 3),
            if (item.label.isNotEmpty)
              Text(
                item.label,
                style: HnagType.micro.copyWith(
                  color: active ? t.text : t.textFaint,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  fontFamily: HnagFonts.body,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FabCenter extends StatelessWidget {
  final VoidCallback onTap;
  const _FabCenter({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return Transform.translate(
      offset: const Offset(0, -20),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            gradient: HnagGradients.brand,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [...t.glow, ...t.shadow3],
          ),
          child: const Center(child: HnagIcon('sparkle', size: 26, color: Colors.white)),
        ),
      ),
    );
  }
}

/// Decorative phone frame for showcase pages only — never wrap real screens.
class HnagPhoneFrame extends StatelessWidget {
  final Widget child;
  final bool dark;
  const HnagPhoneFrame({super.key, required this.child, this.dark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 390, height: 844,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(52),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 60, offset: Offset(0, 30), spreadRadius: -20),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(44),
        child: child,
      ),
    );
  }
}
