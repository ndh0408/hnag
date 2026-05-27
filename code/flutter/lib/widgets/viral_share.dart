// Viral share helper.
//
// Audit production-killer §"viral loop": consumer apps with a friend
// involved retain 4-8× the user. The single most leverage'd action is
// "Hà gợi ý món X cho mình, bạn nghĩ sao?" — one tap, shares a
// branded card + deep link that re-opens HNAG on the friend's device
// (or the marketing landing page if HNAG isn't installed).
//
// Three viral templates:
//
//   - shareFood(foodId, title)              — "I'm trying X. Try it with me."
//   - sharePick(pick)                       — the one-tap hero's pick
//   - shareGroupVote(groupId, restaurantName) — invite to a live group vote
//
// Deep links match the AndroidManifest intent-filter from B7:
//   https://tothanhthuy.cloud/f/<foodId>     → opens app at FoodDetail
//   https://tothanhthuy.cloud/r/<restaurantId> → opens app at RestaurantDetail
//   https://tothanhthuy.cloud/g/<groupId>   → opens app at Group voting
//
// Each share fires `social:share` analytics so the funnel dashboard
// (sql/16_cohort_views.sql) can chart viral coefficient over time.

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../design/hnag_feedback.dart';
import '../observability/analytics.dart';

class ViralShare {
  ViralShare._();

  static const String _baseShareUrl = 'https://tothanhthuy.cloud';

  /// Generic share entry — used by all template helpers.
  static Future<void> _share(BuildContext context, {
    required String text,
    required String url,
    required String campaign,
    Map<String, dynamic>? properties,
  }) async {
    HnagFeedback.tapMedium();
    final fullText = '$text\n\n$url';
    try {
      // Attach a `?utm_source=…` so the marketing landing page can attribute
      // the install back to the share. Stable param order so two shares
      // of the same content produce the same URL (cache-friendly).
      final taggedUrl = '$url?utm_source=app&utm_medium=share&utm_campaign=$campaign';
      final box = context.findRenderObject() as RenderBox?;
      await Share.share(
        fullText.replaceFirst(url, taggedUrl),
        sharePositionOrigin:
            box != null ? box.localToGlobal(Offset.zero) & box.size : null,
        subject: text,
      );
      Analytics.track('social:share', {
        'campaign': campaign,
        ...?properties,
      });
    } catch (e) {
      Analytics.track('social:share_failed', {
        'campaign': campaign,
        'error': e.toString(),
      });
    }
  }

  /// "Hà chọn cho mình món <X>. Bạn thử cùng nhé?" → opens FoodDetail.
  static Future<void> shareFood(
    BuildContext context, {
    required String foodId,
    required String title,
    String? aiReason,
  }) async {
    final text = aiReason != null && aiReason.isNotEmpty
        ? '"$aiReason"\n— Hà gợi ý mình ăn $title hôm nay 🍜. Bạn thử cùng nhé?'
        : 'Hà gợi ý mình ăn $title hôm nay 🍜. Bạn thử cùng nhé?';
    await _share(
      context,
      text: text,
      url: '$_baseShareUrl/f/$foodId',
      campaign: 'food_pick',
      properties: {'foodId': foodId, 'has_reason': aiReason?.isNotEmpty == true},
    );
  }

  /// Share a specific restaurant — "Mình đang ở X, ngon!" or "Hãy thử quán này".
  static Future<void> shareRestaurant(
    BuildContext context, {
    required String restaurantId,
    required String restaurantName,
    String? note,
  }) async {
    final text = note != null && note.isNotEmpty
        ? '$note\n📍 $restaurantName — đáng thử nha!'
        : '📍 $restaurantName — quán này ngon, thử nhé!';
    await _share(
      context,
      text: text,
      url: '$_baseShareUrl/r/$restaurantId',
      campaign: 'restaurant_recommend',
      properties: {'restaurantId': restaurantId},
    );
  }

  /// Invite a friend to a live group vote — high-virality CTA because
  /// the friend has to install HNAG to participate.
  static Future<void> shareGroupVote(
    BuildContext context, {
    required String groupId,
    String? groupName,
  }) async {
    final name = groupName != null && groupName.isNotEmpty ? ' "$groupName"' : '';
    final text = 'Tụi mình đang vote ăn gì$name 🗳️. Tham gia chọn cùng nha!';
    await _share(
      context,
      text: text,
      url: '$_baseShareUrl/g/$groupId',
      campaign: 'group_vote_invite',
      properties: {'groupId': groupId},
    );
  }

  /// Generic "tell a friend about HNAG" — used from Settings → Refer.
  static Future<void> shareApp(BuildContext context) async {
    await _share(
      context,
      text:
          'App này quyết định bữa ăn giúp mình — đỡ phải "Hôm nay ăn gì?" mỗi ngày 😅.\nDùng thử với mình nhé:',
      url: _baseShareUrl,
      campaign: 'app_referral',
    );
  }
}
