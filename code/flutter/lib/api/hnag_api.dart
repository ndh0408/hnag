import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/food_card.dart';
import 'auth_service.dart';

/// HNAG API client — talks to api.tothanhthuy.cloud.
class HnagApi {
  static const String baseUrl = 'https://api.tothanhthuy.cloud';

  Future<List<Map<String, dynamic>>> trendingFoods({String period = 'week', String? city}) async {
    final uri = Uri.parse('$baseUrl/v1/foods/trending').replace(queryParameters: {
      'period': period,
      if (city != null) 'city': city,
    });
    return _fetchList(uri);
  }

  Future<List<Map<String, dynamic>>> listFoods({String? cuisine, String? category, String? q, int? maxPrice, int limit = 20}) async {
    final uri = Uri.parse('$baseUrl/v1/foods').replace(queryParameters: {
      if (cuisine != null) 'cuisine': cuisine,
      if (category != null) 'category': category,
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      if (maxPrice != null) 'maxPrice': maxPrice.toString(),
      'limit': limit.toString(),
    });
    return _fetchList(uri);
  }

  Future<List<Map<String, dynamic>>> searchFoods(String q) async {
    if (q.trim().isEmpty) return [];
    return listFoods(q: q, limit: 20);
  }

  Future<List<Map<String, dynamic>>> nearbyRestaurants({
    required double lat,
    required double lng,
    int radius = 3000,
    bool openNow = true,
  }) async {
    final uri = Uri.parse('$baseUrl/v1/restaurants/nearby').replace(queryParameters: {
      'lat': lat.toString(),
      'lng': lng.toString(),
      'radius': radius.toString(),
      'openNow': openNow.toString(),
    });
    return _fetchList(uri);
  }

  Future<Map<String, dynamic>?> foodDetail(String id) async {
    try {
      final r = await http.get(Uri.parse('$baseUrl/v1/foods/$id')).timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return null;
      return (jsonDecode(r.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('HNAG_API foodDetail error: $e');
      return null;
    }
  }

  /// Smart context-aware AI suggestion (no auth needed).
  Future<List<Map<String, dynamic>>> aiSuggest({int? hour, int? budgetMax, int limit = 8}) async {
    final uri = Uri.parse('$baseUrl/v1/ai/suggest-public').replace(queryParameters: {
      if (hour != null) 'hour': hour.toString(),
      if (budgetMax != null) 'budget': budgetMax.toString(),
      'limit': limit.toString(),
    });
    return _fetchList(uri);
  }

  /// Mood-based suggestion. Returns (theme, foods).
  Future<({String theme, List<Map<String, dynamic>> foods})> aiMoodSuggest(String mood) async {
    try {
      final r = await http.get(Uri.parse('$baseUrl/v1/ai/mood-suggest?mood=$mood')).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return (theme: '', foods: <Map<String, dynamic>>[]);
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      if (data == null) return (theme: '', foods: <Map<String, dynamic>>[]);
      return (
        theme: (data['theme'] as String?) ?? '',
        foods: ((data['foods'] as List?) ?? []).cast<Map<String, dynamic>>(),
      );
    } catch (_) {
      return (theme: '', foods: <Map<String, dynamic>>[]);
    }
  }

  /// Random foods for the wheel.
  Future<List<Map<String, dynamic>>> aiRandom({int n = 8}) async {
    return _fetchList(Uri.parse('$baseUrl/v1/ai/random?n=$n'));
  }

  /// Get recipes that can be made from the user's fridge ingredients.
  Future<List<Map<String, dynamic>>> aiFridgeRecipes(List<String> ingredients, {int timeMin = 60}) async {
    try {
      final r = await http.post(
        Uri.parse('$baseUrl/v1/ai/fridge-recipes'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'ingredients': ingredients, 'timeMin': timeMin}),
      ).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return [];
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      return ((data?['recipes'] as List?) ?? []).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // ─── Authenticated endpoints ─────────────────────────────────────────

  Future<Map<String, dynamic>?> me() async {
    final r = await AuthService.instance.authedRequest((h) =>
        http.get(Uri.parse('$baseUrl/v1/users/me'), headers: h).timeout(const Duration(seconds: 12)));
    if (r.statusCode != 200) return null;
    return (jsonDecode(r.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
  }

  Future<bool> updatePreferences(Map<String, dynamic> prefs) async {
    final r = await AuthService.instance.authedRequest((h) => http.patch(
          Uri.parse('$baseUrl/v1/users/me'),
          headers: {...h, 'Content-Type': 'application/json'},
          body: jsonEncode({'preferences': prefs}),
        ).timeout(const Duration(seconds: 10)));
    return r.statusCode == 200;
  }

  Future<List<Map<String, dynamic>>> mySaves() async {
    final r = await AuthService.instance.authedRequest((h) =>
        http.get(Uri.parse('$baseUrl/v1/users/me/saves'), headers: h).timeout(const Duration(seconds: 12)));
    if (r.statusCode != 200) return [];
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    final items = ((body['data'] as Map<String, dynamic>?)?['items'] as List?) ?? [];
    return items.cast<Map<String, dynamic>>();
  }

  Future<bool> addSave(String foodId) async {
    final r = await AuthService.instance.authedRequest((h) =>
        http.post(Uri.parse('$baseUrl/v1/users/me/saves/$foodId'), headers: h).timeout(const Duration(seconds: 10)));
    return r.statusCode == 200 || r.statusCode == 201;
  }

  Future<bool> removeSave(String foodId) async {
    final r = await AuthService.instance.authedRequest((h) =>
        http.delete(Uri.parse('$baseUrl/v1/users/me/saves/$foodId'), headers: h).timeout(const Duration(seconds: 10)));
    return r.statusCode == 200;
  }

  Future<Map<String, dynamic>?> myStreak() async {
    final r = await AuthService.instance.authedRequest((h) =>
        http.get(Uri.parse('$baseUrl/v1/users/me/streak'), headers: h).timeout(const Duration(seconds: 10)));
    if (r.statusCode != 200) return null;
    return (jsonDecode(r.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>?> bumpDecide() async {
    final r = await AuthService.instance.authedRequest((h) =>
        http.post(Uri.parse('$baseUrl/v1/users/me/streak/decide'), headers: h).timeout(const Duration(seconds: 10)));
    if (r.statusCode != 200) return null;
    return (jsonDecode(r.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
  }

  // ─── Restaurants serving a dish ──────────────────────────────────────
  Future<List<Map<String, dynamic>>> restaurantsServing(String foodId) async {
    return _fetchList(Uri.parse('$baseUrl/v1/foods/$foodId/restaurants'));
  }

  /// Full restaurant detail including menu_items[] and live (open/wait).
  Future<Map<String, dynamic>?> restaurantDetail(String id) async {
    try {
      final r = await http.get(Uri.parse('$baseUrl/v1/restaurants/$id'))
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return null;
      return (jsonDecode(r.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
    } catch (_) { return null; }
  }

  Future<List<Map<String, dynamic>>> restaurantMenu(String id) async {
    return _fetchList(Uri.parse('$baseUrl/v1/restaurants/$id/menu'));
  }

  // ─── Meal plan ───────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> currentMealPlan() async {
    final r = await AuthService.instance.authedRequest((h) =>
        http.get(Uri.parse('$baseUrl/v1/meal-plan'), headers: h).timeout(const Duration(seconds: 12)));
    if (r.statusCode != 200) return null;
    return (jsonDecode(r.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>?> generateMealPlan({int budgetPerDay = 150000}) async {
    final r = await AuthService.instance.authedRequest((h) => http.post(
          Uri.parse('$baseUrl/v1/meal-plan/generate'),
          headers: {...h, 'Content-Type': 'application/json'},
          body: jsonEncode({'budgetPerDay': budgetPerDay}),
        ).timeout(const Duration(seconds: 20)));
    if (r.statusCode != 200) return null;
    return (jsonDecode(r.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
  }

  // ─── Subscription ────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> subscriptionStatus() async {
    final r = await AuthService.instance.authedRequest((h) =>
        http.get(Uri.parse('$baseUrl/v1/subscription/me'), headers: h).timeout(const Duration(seconds: 10)));
    if (r.statusCode != 200) return null;
    return (jsonDecode(r.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>?> redeemPromo(String code) async {
    final r = await AuthService.instance.authedRequest((h) => http.post(
          Uri.parse('$baseUrl/v1/subscription/promo'),
          headers: {...h, 'Content-Type': 'application/json'},
          body: jsonEncode({'code': code}),
        ).timeout(const Duration(seconds: 10)));
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200 && r.statusCode != 201) {
      throw Exception((body['error']?['message'] as String?) ?? 'Mã không hợp lệ');
    }
    return body['data'] as Map<String, dynamic>?;
  }

  // ─── Social: Posts + Feed + Stories ─────────────────────────────────
  /// Feed posts. tab: 'for_you' | 'following' | 'nearby' | 'trending'
  Future<List<Map<String, dynamic>>> feedPosts({String tab = 'for_you', int page = 1}) async {
    try {
      final r = await AuthService.instance.authedRequest((h) =>
          http.get(Uri.parse('$baseUrl/v1/feed?tab=$tab&page=$page'), headers: h)
              .timeout(const Duration(seconds: 12)));
      if (r.statusCode != 200) return [];
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      return ((body['data'] as List?) ?? []).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Friends activity = following-feed (posts from people you follow)
  Future<List<Map<String, dynamic>>> friendsActivity({int page = 1}) =>
      feedPosts(tab: 'following', page: page);

  /// Stories from followed users.
  Future<List<Map<String, dynamic>>> storiesFeed() async {
    try {
      final r = await AuthService.instance.authedRequest((h) =>
          http.get(Uri.parse('$baseUrl/v1/stories/feed'), headers: h)
              .timeout(const Duration(seconds: 10)));
      if (r.statusCode != 200) return [];
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      return ((body['data'] as List?) ?? []).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<bool> likePost(String postId, {required bool like}) async {
    final r = await AuthService.instance.authedRequest((h) => like
        ? http.post(Uri.parse('$baseUrl/v1/posts/$postId/like'), headers: h)
            .timeout(const Duration(seconds: 8))
        : http.delete(Uri.parse('$baseUrl/v1/posts/$postId/like'), headers: h)
            .timeout(const Duration(seconds: 8)));
    return r.statusCode == 200 || r.statusCode == 201;
  }

  // ─── Orders ──────────────────────────────────────────────────────────
  /// Create an order intent — backend returns a partner deep-link
  /// (Grab/Shopee/BeFood) that the app should `launchUrlString` to.
  Future<Map<String, dynamic>?> createOrderIntent({
    required String foodId,
    String? restaurantId,
    String? preferredPartner,
  }) async {
    final r = await AuthService.instance.authedRequest((h) => http.post(
          Uri.parse('$baseUrl/v1/orders/intent'),
          headers: {...h, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'foodId': foodId,
            if (restaurantId != null) 'restaurantId': restaurantId,
            if (preferredPartner != null) 'preferredPartner': preferredPartner,
          }),
        ).timeout(const Duration(seconds: 15)));
    if (r.statusCode != 200 && r.statusCode != 201) return null;
    return (jsonDecode(r.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
  }

  Future<List<Map<String, dynamic>>> myOrders({int page = 1}) async {
    try {
      final r = await AuthService.instance.authedRequest((h) =>
          http.get(Uri.parse('$baseUrl/v1/orders?page=$page'), headers: h)
              .timeout(const Duration(seconds: 10)));
      if (r.statusCode != 200) return [];
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      return ((body['data'] as List?) ?? []).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // ─── AI feedback (learn from swipes / orders / cooks) ──────────────────
  /// Records user behavior on an AI suggestion. action ∈ view/save/skip/cook/
  /// order/dine/rate. Backend updates personalization weights.
  Future<bool> aiFeedback({
    required String sessionId,
    required String foodId,
    required String action,
    int? rating,
    String? reason,
  }) async {
    try {
      final r = await AuthService.instance.authedRequest((h) => http.post(
            Uri.parse('$baseUrl/v1/ai/feedback'),
            headers: {...h, 'Content-Type': 'application/json'},
            body: jsonEncode({
              'sessionId': sessionId,
              'foodId': foodId,
              'action': action,
              if (rating != null) 'rating': rating,
              if (reason != null) 'reason': reason,
            }),
          ).timeout(const Duration(seconds: 8)));
      return r.statusCode == 200;
    } catch (_) { return false; }
  }

  // ─── Phone OTP ───────────────────────────────────────────────────────
  /// Send 6-digit OTP to a Vietnamese phone number (E.164 or 0-prefixed).
  /// Backend hashes + rate-limits per memory; never returns the code.
  Future<bool> sendPhoneOtp(String phone) async {
    try {
      final r = await http.post(
        Uri.parse('$baseUrl/v1/auth/phone-otp/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      ).timeout(const Duration(seconds: 12));
      return r.statusCode == 200;
    } catch (_) { return false; }
  }

  Future<Map<String, dynamic>?> verifyPhoneOtp(String phone, String code) async {
    final r = await http.post(
      Uri.parse('$baseUrl/v1/auth/phone-otp/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'code': code}),
    ).timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) return null;
    return (jsonDecode(r.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
  }

  // ─── Apple SSO ───────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> signInWithApple({
    required String identityToken,
    String? authorizationCode,
    String? fullName,
    String? email,
  }) async {
    final r = await http.post(
      Uri.parse('$baseUrl/v1/auth/apple'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'identityToken': identityToken,
        if (authorizationCode != null) 'authorizationCode': authorizationCode,
        if (fullName != null) 'fullName': fullName,
        if (email != null) 'email': email,
      }),
    ).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200 && r.statusCode != 201) return null;
    return (jsonDecode(r.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>?> startCheckout(String plan, String provider) async {
    final r = await AuthService.instance.authedRequest((h) => http.post(
          Uri.parse('$baseUrl/v1/subscription/checkout'),
          headers: {...h, 'Content-Type': 'application/json'},
          body: jsonEncode({'plan': plan, 'provider': provider}),
        ).timeout(const Duration(seconds: 12)));
    if (r.statusCode != 200 && r.statusCode != 201) return null;
    return (jsonDecode(r.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
  }

  // ─── Groups ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> createGroup(String name) async {
    final r = await AuthService.instance.authedRequest((h) => http.post(
          Uri.parse('$baseUrl/v1/groups'),
          headers: {...h, 'Content-Type': 'application/json'},
          body: jsonEncode({'name': name}),
        ).timeout(const Duration(seconds: 10)));
    if (r.statusCode != 200 && r.statusCode != 201) return null;
    return (jsonDecode(r.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>?> createPoll(String groupId, List<String> foodIds, {int closesInMinutes = 10}) async {
    final r = await AuthService.instance.authedRequest((h) => http.post(
          Uri.parse('$baseUrl/v1/groups/$groupId/polls'),
          headers: {...h, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'options': [for (final id in foodIds) {'foodId': id}],
            'closesInMinutes': closesInMinutes,
          }),
        ).timeout(const Duration(seconds: 10)));
    if (r.statusCode != 200 && r.statusCode != 201) return null;
    return (jsonDecode(r.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
  }

  Future<List<int>?> votePoll(String groupId, String pollId, int optionIdx) async {
    final r = await AuthService.instance.authedRequest((h) => http.post(
          Uri.parse('$baseUrl/v1/groups/$groupId/polls/$pollId/vote'),
          headers: {...h, 'Content-Type': 'application/json'},
          body: jsonEncode({'optionIdx': optionIdx}),
        ).timeout(const Duration(seconds: 10)));
    if (r.statusCode != 200) return null;
    final data = (jsonDecode(r.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
    return ((data?['tally'] as List?) ?? []).cast<int>();
  }

  Future<List<Map<String, dynamic>>> _fetchList(Uri uri) async {
    try {
      debugPrint('HNAG_API GET $uri');
      final r = await http.get(uri).timeout(const Duration(seconds: 20));
      debugPrint('HNAG_API ${r.statusCode} ${r.body.length} bytes');
      if (r.statusCode != 200) return [];
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final data = body['data'];
      if (data is List) return data.cast<Map<String, dynamic>>();
      return [];
    } catch (e) {
      debugPrint('HNAG_API error: $e');
      return [];
    }
  }
}

/// Convert backend food JSON → FoodCard.
extension FoodCardFromApi on FoodCard {
  static FoodCard fromApiJson(Map<String, dynamic> j, {Map<String, dynamic>? restaurant, int? distanceM, int? deliveryMin}) {
    final priceVnd = _asInt(j['avg_price_vnd']) ?? 50000;
    final priceK = (priceVnd / 1000).round();
    final rating = _asDouble(j['rating_avg']) ?? 4.5;
    final ratingCount = _asInt(j['rating_count']) ?? 100;
    final image = (j['primary_image'] as String?) ?? 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800';
    final tags = <String>[];
    for (final t in [j['flavor_tags'], j['mood_tags'], j['vibe_tags']]) {
      if (t is List) tags.addAll(t.cast<String>().take(3));
    }

    final trending = _asDouble(j['trending_score']) ?? 0;
    final badges = <CardBadge>[];
    if (trending > 70) {
      badges.add(const CardBadge(type: 'trending', text: '🔥 Trending', icon: ''));
    }

    return FoodCard(
      cardId: j['id'] as String,
      foodId: j['id'] as String,
      title: j['name_vi'] as String,
      subtitle: restaurant?['name'] as String?,
      media: CardMedia(poster: image),
      badges: badges,
      price: CardPrice(amount: priceVnd, display: '${priceK}k ₫'),
      rating: CardRating(avg: rating, count: ratingCount, verified: true),
      distance: CardDistance(
        meters: distanceM ?? 800,
        display: distanceM != null ? (distanceM < 1000 ? '${distanceM}m' : '${(distanceM / 1000).toStringAsFixed(1)}km') : '~800m',
        deliveryMin: deliveryMin ?? 12,
      ),
      calories: _asInt(j['avg_calories']),
      tags: tags.take(3).toList(),
      liveStatus: const CardLiveStatus(isOpen: true, crowdedness: 0.6, waitMinutes: 5),
      aiReason: _reasonFor(j),
      actions: const CardActions(cookEnabled: true, orderPrimary: 'grabfood', orderDeeplink: '', dineEnabled: true),
    );
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static String _reasonFor(Map<String, dynamic> j) {
    // Prefer backend-provided _ai_reason if present
    final fromApi = j['_ai_reason'] as String?;
    if (fromApi != null && fromApi.isNotEmpty) return fromApi;

    final tags = (j['mood_tags'] as List?)?.cast<String>() ?? [];
    if (tags.contains('comfort')) return '${j["name_vi"]} ấm bụng — lựa chọn an toàn';
    if (tags.contains('vui')) return 'Món vui vẻ cho buổi gặp gỡ';
    if (tags.contains('latenight')) return 'Khuya thèm gì? Có ngay ${j["name_vi"]}';
    final cat = (j['category'] as String?) ?? '';
    if (cat == 'drink') return 'Mát lạnh, đúng vibe Sài Gòn';
    if (cat == 'dessert') return 'Ngọt nhẹ kết bữa hoàn hảo';
    return 'Hà thấy món này hợp với bạn lúc này';
  }
}
