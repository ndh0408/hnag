// Icon registry — maps lucide-style names (used across design refs) to
// Material rounded icons. Single source so we can later swap to a real lucide
// font without touching call sites.

import 'package:flutter/material.dart';

class HnagIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;
  const HnagIcon(this.name, {super.key, this.size = 20, this.color});

  static IconData resolve(String name) => _map[name] ?? Icons.help_outline_rounded;

  @override
  Widget build(BuildContext context) {
    return Icon(resolve(name), size: size, color: color);
  }

  // ─── name → IconData mapping ───────────────────────────────────────────
  static const Map<String, IconData> _map = {
    // Core nav
    'home': Icons.home_rounded,
    'search': Icons.search_rounded,
    'sparkle': Icons.auto_awesome_rounded,
    'sparkles': Icons.auto_awesome_outlined,
    'play': Icons.play_arrow_rounded,
    'user': Icons.person_rounded,
    'users': Icons.group_rounded,
    'heart': Icons.favorite_rounded,
    'heartOutline': Icons.favorite_border_rounded,
    'bookmark': Icons.bookmark_rounded,
    'bookmarkOutline': Icons.bookmark_border_rounded,
    'star': Icons.star_rounded,
    'bell': Icons.notifications_rounded,
    'chat': Icons.chat_bubble_rounded,
    'share': Icons.share_rounded,
    'plus': Icons.add_rounded,
    'minus': Icons.remove_rounded,
    'check': Icons.check_rounded,
    'x': Icons.close_rounded,
    'chevR': Icons.chevron_right_rounded,
    'chevL': Icons.chevron_left_rounded,
    'chevD': Icons.keyboard_arrow_down_rounded,
    'chevU': Icons.keyboard_arrow_up_rounded,
    'arrowR': Icons.arrow_forward_rounded,
    'arrowL': Icons.arrow_back_rounded,
    'arrowU': Icons.arrow_upward_rounded,
    'arrowD': Icons.arrow_downward_rounded,
    'arrowUR': Icons.north_east_rounded,
    'menu': Icons.menu_rounded,
    'more': Icons.more_horiz_rounded,
    'moreV': Icons.more_vert_rounded,
    'settings': Icons.settings_rounded,

    // Food / shop
    'mic': Icons.mic_rounded,
    'micOff': Icons.mic_off_rounded,
    'cam': Icons.photo_camera_rounded,
    'map': Icons.map_rounded,
    'pin': Icons.location_on_rounded,
    'cart': Icons.shopping_cart_rounded,
    'clock': Icons.access_time_rounded,
    'fire': Icons.local_fire_department_rounded,
    'flame': Icons.local_fire_department_outlined,
    'book': Icons.menu_book_rounded,
    'cal': Icons.calendar_today_rounded,
    'chart': Icons.show_chart_rounded,
    'chartBar': Icons.bar_chart_rounded,
    'trend': Icons.trending_up_rounded,
    'eye': Icons.visibility_rounded,
    'eyeOff': Icons.visibility_off_rounded,
    'grid': Icons.grid_view_rounded,
    'list': Icons.list_rounded,
    'filter': Icons.tune_rounded,
    'bolt': Icons.bolt_rounded,
    'leaf': Icons.eco_rounded,
    'wallet': Icons.account_balance_wallet_rounded,
    'package': Icons.inventory_2_rounded,
    'crown': Icons.workspace_premium_rounded,
    'award': Icons.emoji_events_rounded,
    'target': Icons.adjust_rounded,
    'moon': Icons.dark_mode_rounded,
    'sun': Icons.wb_sunny_rounded,
    'cloud': Icons.cloud_rounded,
    'rain': Icons.cloud_rounded, // approx
    'lock': Icons.lock_rounded,
    'lockOpen': Icons.lock_open_rounded,
    'globe': Icons.public_rounded,
    'refresh': Icons.refresh_rounded,
    'download': Icons.download_rounded,
    'upload': Icons.upload_rounded,
    'logout': Icons.logout_rounded,
    'edit': Icons.edit_rounded,
    'trash': Icons.delete_rounded,
    'flag': Icons.flag_rounded,
    'info': Icons.info_outlined,
    'alert': Icons.warning_amber_rounded,
    'zap': Icons.bolt_rounded,
    'smile': Icons.sentiment_satisfied_rounded,
    'apple': Icons.apple,
    'headset': Icons.headset_mic_rounded,

    // Extras
    'google': Icons.g_mobiledata_rounded,
    'facebook': Icons.facebook_rounded,
    'email': Icons.email_rounded,
    'phone': Icons.phone_rounded,
    'wifi': Icons.wifi_rounded,
    'qr': Icons.qr_code_2_rounded,
    'voucher': Icons.confirmation_number_rounded,
    'gift': Icons.card_giftcard_rounded,
    'home2': Icons.home_outlined,
    'paint': Icons.palette_rounded,
    'dice': Icons.casino_rounded,
    'wheel': Icons.donut_large_rounded,
    'forkKnife': Icons.restaurant_rounded,
    'cup': Icons.local_cafe_rounded,
    'truck': Icons.local_shipping_rounded,
    'flashOn': Icons.flash_on_rounded,
    'flashOff': Icons.flash_off_rounded,
  };
}
