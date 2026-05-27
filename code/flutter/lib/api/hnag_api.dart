import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/food_card.dart';
import 'auth_service.dart';
import 'api_exception.dart';
import 'resilient_client.dart';

/// HNAG API client — talks to api.tothanhthuy.cloud.
class HnagApi {
  static const String baseUrl = 'https://api.tothanhthuy.cloud';

  /// Resilient client used by `_fetchList` and any new method that opts in.
  /// Audit hnag-audit-2026-05 §5-Flutter: bare `http.get` had no retry, no
  /// circuit breaker, single timeout. Existing methods are migrated one at
  /// a time — they keep working until they're converted because the
  /// fallback path through raw http still exists.
  final ResilientClient _client = ResilientClient();

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

  /// Cancel an order in-flight (only valid before status='delivering').
  /// Broadcasts `order:update` to user room via the backend.
  Future<bool> cancelOrder(String orderId) async {
    try {
      final r = await AuthService.instance.authedRequest((h) => http.post(
            Uri.parse('$baseUrl/v1/orders/$orderId/status'),
            headers: {...h, 'Content-Type': 'application/json'},
            body: jsonEncode({'status': 'cancelled'}),
          ).timeout(const Duration(seconds: 10)));
      return r.statusCode == 200;
    } catch (_) { return false; }
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
  ///
  /// Throws `ApiException` (with friendly vi-VN message) on network /
  /// server failure — UI sites doing `_error = e.toString()` get a usable
  /// line. Returns true only on backend 2xx.
  Future<bool> sendPhoneOtp(String phone) async {
    final r = await _safePost(
      '/v1/auth/phone-otp/send',
      body: {'phone': phone},
      timeout: const Duration(seconds: 12),
    );
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return true;
  }

  Future<Map<String, dynamic>?> verifyPhoneOtp(String phone, String code) async {
    final r = await _safePost(
      '/v1/auth/phone-otp/verify',
      body: {'phone': phone, 'code': code},
      timeout: const Duration(seconds: 12),
    );
    if (r.statusCode == 401) return null; // wrong code — let caller branch
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return (jsonDecode(r.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
  }

  // ─── Apple SSO ───────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> signInWithApple({
    required String identityToken,
    String? authorizationCode,
    String? fullName,
    String? email,
  }) async {
    final r = await _safePost(
      '/v1/auth/apple',
      body: {
        'identityToken': identityToken,
        if (authorizationCode != null) 'authorizationCode': authorizationCode,
        if (fullName != null) 'fullName': fullName,
        if (email != null) 'email': email,
      },
      timeout: const Duration(seconds: 15),
    );
    if (r.statusCode != 200 && r.statusCode != 201) {
      throw ApiException.fromResponse(r);
    }
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
  Future<List<Map<String, dynamic>>> myGroups() async {
    try {
      final r = await AuthService.instance.authedRequest((h) =>
          http.get(Uri.parse('$baseUrl/v1/groups'), headers: h)
              .timeout(const Duration(seconds: 10)));
      if (r.statusCode != 200) return [];
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      return ((body['data'] as List?) ?? []).cast<Map<String, dynamic>>();
    } catch (_) { return []; }
  }

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

  /// Final result + winner for a poll. Polled lazily by the voting screen after
  /// `closes_at` or when the user taps "Xem kết quả".
  Future<Map<String, dynamic>?> pollResult(String groupId, String pollId) async {
    final r = await AuthService.instance.authedRequest((h) =>
        http.get(Uri.parse('$baseUrl/v1/groups/$groupId/polls/$pollId/result'), headers: h)
            .timeout(const Duration(seconds: 10)));
    if (r.statusCode != 200) return null;
    return (jsonDecode(r.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>?> joinGroup(String groupId, String inviteCode) async {
    final r = await AuthService.instance.authedRequest((h) => http.post(
          Uri.parse('$baseUrl/v1/groups/$groupId/members'),
          headers: {...h, 'Content-Type': 'application/json'},
          body: jsonEncode({'inviteCode': inviteCode}),
        ).timeout(const Duration(seconds: 10)));
    if (r.statusCode != 200 && r.statusCode != 201) return null;
    return (jsonDecode(r.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
  }

  // ─── Couple Mode ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> coupleMe() async {
    try {
      final r = await AuthService.instance.authedRequest((h) =>
          http.get(Uri.parse('$baseUrl/v1/couple/me'), headers: h)
              .timeout(const Duration(seconds: 10)));
      if (r.statusCode != 200) return null;
      return (jsonDecode(r.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
    } catch (_) { return null; }
  }

  Future<bool> coupleInvite(String phoneOrUsername) async {
    try {
      final r = await AuthService.instance.authedRequest((h) => http.post(
            Uri.parse('$baseUrl/v1/couple/invite'),
            headers: {...h, 'Content-Type': 'application/json'},
            body: jsonEncode({'phoneOrUsername': phoneOrUsername}),
          ).timeout(const Duration(seconds: 10)));
      return r.statusCode == 200 || r.statusCode == 201;
    } catch (_) { return false; }
  }

  // ─── Achievements / Badges (Profile Badges tab) ──────────────────────
  Future<List<Map<String, dynamic>>> myAchievements() async {
    try {
      final r = await AuthService.instance.authedRequest((h) =>
          http.get(Uri.parse('$baseUrl/v1/challenges/achievements/me'), headers: h)
              .timeout(const Duration(seconds: 10)));
      if (r.statusCode != 200) return [];
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      return ((body['data'] as List?) ?? []).cast<Map<String, dynamic>>();
    } catch (_) { return []; }
  }

  // ─── Restaurants serving a food (Quán bán tab) ───────────────────────
  Future<List<Map<String, dynamic>>> restaurantsServingFood(String foodId) async {
    final uri = Uri.parse('$baseUrl/v1/foods/$foodId/restaurants');
    return _fetchList(uri);
  }

  /// Reviews for a restaurant (Reviews tab on restaurant detail).
  Future<List<Map<String, dynamic>>> restaurantReviews(String restaurantId, {String sort = 'recent'}) async {
    final uri = Uri.parse('$baseUrl/v1/restaurants/$restaurantId/reviews?sort=$sort');
    return _fetchList(uri);
  }

  /// Reviews for a food id (Profile reviews + Food Detail Bài viết tab).
  /// Backend exposes via /v1/foods/:id/reviews if implemented; falls back to []
  /// if endpoint not present.
  Future<List<Map<String, dynamic>>> foodReviews(String foodId) async {
    try {
      final uri = Uri.parse('$baseUrl/v1/foods/$foodId/reviews');
      return await _fetchList(uri);
    } catch (_) {
      return const [];
    }
  }

  /// Write a food review (rating + content). Returns true on success.
  Future<bool> writeReview({required String foodId, required int rating, required String content}) async {
    try {
      final r = await AuthService.instance.authedRequest((h) => http.post(
            Uri.parse('$baseUrl/v1/foods/$foodId/reviews'),
            headers: {...h, 'Content-Type': 'application/json'},
            body: jsonEncode({'rating': rating, 'content': content}),
          ).timeout(const Duration(seconds: 12)));
      return r.statusCode == 200 || r.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  // ─── Comments ────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> commentsForPost(String postId, {int page = 1}) async {
    try {
      final r = await AuthService.instance.authedRequest((h) =>
          http.get(Uri.parse('$baseUrl/v1/posts/$postId/comments?page=$page'), headers: h)
              .timeout(const Duration(seconds: 10)));
      if (r.statusCode != 200) return [];
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      return ((body['data'] as List?) ?? []).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> commentOnPost(String postId, String content, {String? parentId}) async {
    try {
      final r = await AuthService.instance.authedRequest((h) => http.post(
            Uri.parse('$baseUrl/v1/posts/$postId/comment'),
            headers: {...h, 'Content-Type': 'application/json'},
            body: jsonEncode({'content': content, if (parentId != null) 'parentId': parentId}),
          ).timeout(const Duration(seconds: 10)));
      if (r.statusCode != 200 && r.statusCode != 201) return null;
      return (jsonDecode(r.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  /// POST JSON to the API; translate any transport-layer failure (DNS down,
  /// connection refused, timeout, SocketException) into a user-friendly
  /// `ApiException` so UIs doing `_error = e.toString()` get vi-VN copy.
  /// Returns the raw http.Response — callers decide how to map the status.
  ///
  /// Audit follow-up (2026-05-27 emulator test): the auth POSTs in this
  /// file previously bubbled `ClientException` raw to the screen.
  Future<http.Response> _safePost(
    String path, {
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 12),
    Map<String, String>? headers,
  }) async {
    try {
      return await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {'Content-Type': 'application/json', ...?headers},
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchList(Uri uri) async {
    // Resilient: 3 attempts, exp backoff + jitter, circuit-breaker per host.
    try {
      final r = await _client.get(uri);
      if (r.statusCode != 200) return [];
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final data = body['data'];
      if (data is List) return data.cast<Map<String, dynamic>>();
      return [];
    } on ResilientHttpError catch (e) {
      // Circuit-open is the one error we don't want to spam the user with
      // — it's by design. Other failures still degrade to empty list so
      // the UI shows an empty state rather than crashing.
      if (kDebugMode) debugPrint('HNAG_API _fetchList degraded: $e');
      return [];
    } catch (e) {
      if (kDebugMode) debugPrint('HNAG_API _fetchList error: $e');
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
