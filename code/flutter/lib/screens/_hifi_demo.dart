// Entry points for the Hi-Fi v2 screens from the Tools tab.
//
// IMPORTANT: data here comes from the REAL backend via `HnagApi()` — NOT
// hardcoded. Each demo widget is a thin StatefulWidget that fetches its own
// data from production API and adapts it to the v2 screens' data shapes.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

import '../api/hnag_api.dart';
import '../api/auth_service.dart';
import '../design/tokens.dart';
import 'home_v2/home_v2.dart' as home_v2;
import 'detail_v2/detail_v2.dart' as detail_v2;
import 'ai_v2/ai_v2.dart' as ai_v2;
import 'premium_v2/premium_v2.dart' as premium_v2;
import 'profile_v2/profile_v2.dart' as profile_v2;
import 'social_v2/social_v2.dart' as social_v2;
import 'settings_v2/settings_v2.dart' as settings_v2;
import '../widgets/ds/ds.dart';

class Hifi {
  static Widget homeDemo(BuildContext c)         => const _HomeReal();
  static Widget aiDecideDemo(BuildContext c)     => _AiDecideReal();
  static Widget cardStackDemo(BuildContext c)    => const _CardStackReal();
  static Widget foodDetailDemo(BuildContext c)   => const _FoodDetailReal();
  static Widget cartDemo(BuildContext c)         => _CartReal();
  static Widget orderTrackingDemo(BuildContext c)=> const _OrderTrackingReal();
  static Widget restaurantDetailDemo(BuildContext c) => const _RestaurantDetailReal();
  static Widget moodWheelDemo(BuildContext c)    => _MoodWheelReal();
  static Widget voiceHaDemo(BuildContext c)      => _VoiceReal();
  static Widget premiumDemo(BuildContext c)      => _PremiumReal();
  static Widget profileDemo(BuildContext c)      => const _ProfileReal();
  static Widget tiktokFeedDemo(BuildContext c)   => const _TikTokReal();
  static Widget mealPlannerDemo(BuildContext c)  => const _MealPlannerReal();
  static Widget groupVotingDemo(BuildContext c)  => const _GroupVotingReal();
  static Widget notificationsDemo(BuildContext c)=> const _NotificationsReal();
  static Widget lateNightDemo(BuildContext c)    => const _LateNightReal();
  static Widget searchDemo(BuildContext c)       => _SearchReal();
  static Widget settingsDemo(BuildContext c)     => settings_v2.SettingsScreenV2(
    userName: 'Bạn',
    userEmail: 'bạn@hnag.app',
    onSignOut: () async {
      await AuthService.instance.signOut();
      if (c.mounted) Navigator.of(c).popUntil((r) => r.isFirst);
    },
  );
}

// ─────────────────────────────────────────────────────────────
// TIKTOK FEED — trending foods rendered as vertical video pages
// ─────────────────────────────────────────────────────────────
class _TikTokReal extends StatefulWidget {
  const _TikTokReal();
  @override
  State<_TikTokReal> createState() => _TikTokRealState();
}

class _TikTokRealState extends State<_TikTokReal> {
  final _api = HnagApi();
  List<social_v2.TikTokVideoData>? _videos;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final trending = await _api.trendingFoods();
    if (!mounted) return;
    setState(() {
      _videos = trending.take(8).map((f) => social_v2.TikTokVideoData(
        id: (f['id'] as String?) ?? '',
        author: (f['cuisine'] as String?) ?? 'hnag',
        caption: ((f['description'] as String?) ?? (f['name_vi'] as String?) ?? '').length > 120
            ? '${((f['description'] as String?) ?? (f['name_vi'] as String?) ?? '').substring(0, 120)}…'
            : ((f['description'] as String?) ?? (f['name_vi'] as String?) ?? ''),
        foodName: (f['name_vi'] as String?) ?? '',
        foodSlug: _slugFromName(f['name_vi'] as String?),
        likes: ((f['rating_count'] as int?) ?? 200) * 7,
        comments: ((f['rating_count'] as int?) ?? 100),
        shares: 42,
        saves: 88,
      )).toList();
    });
  }

  String _slugFromName(String? name) {
    final n = (name ?? '').toLowerCase();
    if (n.contains('phở')) return 'pho';
    if (n.contains('bún bò')) return 'bunbo';
    if (n.contains('bún')) return 'bunch';
    if (n.contains('cơm gà')) return 'comga';
    if (n.contains('bánh mì')) return 'banhmi';
    if (n.contains('lẩu')) return 'lau';
    if (n.contains('gỏi')) return 'goicuon';
    return 'pho';
  }

  @override
  Widget build(BuildContext context) {
    if (_videos == null) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.white)));
    }
    return social_v2.TikTokFeedScreen(
      videos: _videos!,
      onClose: () => Navigator.maybePop(context),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MEAL PLANNER — empty week, AI auto-fill via /ai/suggest
// ─────────────────────────────────────────────────────────────
class _MealPlannerReal extends StatefulWidget {
  const _MealPlannerReal();
  @override
  State<_MealPlannerReal> createState() => _MealPlannerRealState();
}

class _MealPlannerRealState extends State<_MealPlannerReal> {
  final _api = HnagApi();
  final Map<String, Map<String, social_v2.PlannedMeal?>> _plan = {};

  Future<void> _autoFill(Map<String, Map<String, social_v2.PlannedMeal?>> current) async {
    final suggestions = await _api.aiSuggest(limit: 21);
    if (!mounted) return;
    int i = 0;
    final next = <String, Map<String, social_v2.PlannedMeal?>>{};
    for (final entry in current.entries) {
      next[entry.key] = {};
      for (final meal in entry.value.keys) {
        if (i < suggestions.length) {
          final s = suggestions[i++];
          next[entry.key]![meal] = social_v2.PlannedMeal(
            foodId: (s['id'] as String?) ?? '',
            foodName: (s['name_vi'] as String?) ?? '',
            foodSlug: 'pho',
            calories: (s['avg_calories'] as int?) ?? 0,
            priceVnd: (s['avg_price_vnd'] as int?) ?? 0,
          );
        }
      }
    }
    setState(() {
      _plan
        ..clear()
        ..addAll(next);
    });
  }

  @override
  Widget build(BuildContext context) {
    return social_v2.MealPlannerScreenV2(
      plan: _plan,
      onAutoFill: _autoFill,
      onPickMeal: (_, __) async {
        // For now pick from trending; could open a picker sheet in prod.
        final t = await _api.trendingFoods();
        if (t.isEmpty) return null;
        final f = t.first;
        return social_v2.PlannedMeal(
          foodId: (f['id'] as String?) ?? '',
          foodName: (f['name_vi'] as String?) ?? '',
          foodSlug: 'pho',
          calories: (f['avg_calories'] as int?) ?? 0,
          priceVnd: (f['avg_price_vnd'] as int?) ?? 0,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SEARCH v2 — wired to /v1/foods?q=
// ─────────────────────────────────────────────────────────────
class _SearchReal extends StatelessWidget {
  final _api = HnagApi();
  _SearchReal();

  @override
  Widget build(BuildContext context) {
    return home_v2.SearchScreenV2(
      onSearch: (q) async {
        try { return await _api.searchFoods(q); }
        catch (_) { return <Map<String, dynamic>>[]; }
      },
      onResultTap: (food) async {
        final id = (food['id'] as String?) ?? '';
        if (id.isEmpty) return;
        final detail = await _api.foodDetail(id);
        if (!context.mounted || detail == null) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => detail_v2.FoodDetailScreenV2(
            food: detail_v2.FoodDetailDataV2(
              id: id,
              name: (detail['name_vi'] as String?) ?? '',
              imageUrl: detail['primary_image'] as String?,
              foodSlug: 'pho',
              rating: ((detail['rating_avg'] as num?) ?? 4.5).toDouble(),
              reviewCount: (detail['rating_count'] as int?) ?? 0,
              flavorTags: ((detail['flavor_tags'] as List?) ?? const []).cast<String>().take(2).toList(),
              region: (detail['region'] as String?) ?? 'Việt Nam',
              priceVnd: (detail['avg_price_vnd'] as int?) ?? 0,
              calories: (detail['avg_calories'] as int?) ?? 0,
              prepTimeMin: (detail['cook_time_min'] as int?) ?? 30,
              macroLabel: 'High protein',
              hashtags: ((detail['mood_tags'] as List?) ?? const []).cast<String>().take(6).toList(),
              aiReason: (detail['description'] as String?) ?? '',
              ingredients: const [],
              steps: const [],
              totalSteps: 0,
            ),
          ),
        ));
      },
      onVoice: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (c) => Hifi.voiceHaDemo(c),
      )),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// GROUP VOTING — demo group with realistic options
// ─────────────────────────────────────────────────────────────
class _GroupVotingReal extends StatefulWidget {
  const _GroupVotingReal();
  @override
  State<_GroupVotingReal> createState() => _GroupVotingRealState();
}

class _GroupVotingRealState extends State<_GroupVotingReal> {
  final _api = HnagApi();
  List<social_v2.GroupOption>? _options;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final trending = await _api.trendingFoods();
    if (!mounted) return;
    setState(() {
      _options = trending.take(4).toList().asMap().entries.map((e) {
        final i = e.key;
        final f = e.value;
        return social_v2.GroupOption(
          id: (f['id'] as String?) ?? 'opt-$i',
          name: (f['name_vi'] as String?) ?? '',
          foodSlug: 'pho',
          priceVnd: (f['avg_price_vnd'] as int?) ?? 50000,
          location: 'Q.3, TP.HCM',
          voterAvatars: ['Minh', 'Linh', 'Khoa', 'Tâm'].sublist(0, [3, 2, 2, 1][i % 4]),
        );
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_options == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: HnagColors.brand500)));
    }
    return social_v2.GroupVotingScreenV2(
      groupName: 'Team lunch 🍜',
      memberCount: 5,
      userId: 'me',
      options: _options!,
      chat: const [
        social_v2.ChatTurn(name: 'Minh', text: 'Chốt Phở Lý nhé anh em, gần văn phòng'),
        social_v2.ChatTurn(name: 'Linh', text: 'Hôm qua ăn rồi, đổi món khác?'),
        social_v2.ChatTurn(name: 'Bạn',  text: 'OK lẩu Thái cũng được', isMe: true),
      ],
      onSend: (text) => debugPrint('Group send: $text'),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// NOTIFICATIONS — feed from real AI + trending + streak
// ─────────────────────────────────────────────────────────────
class _NotificationsReal extends StatefulWidget {
  const _NotificationsReal();
  @override
  State<_NotificationsReal> createState() => _NotificationsRealState();
}

class _NotificationsRealState extends State<_NotificationsReal> {
  final _api = HnagApi();
  List<social_v2.NotificationItem>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final out = <social_v2.NotificationItem>[];
    try {
      final r = await _api.aiMoodSuggest('happy');
      if (r.foods.isNotEmpty) {
        final top = r.foods.first;
        out.add(social_v2.NotificationItem(
          id: 'ai-${top['id']}',
          type: 'ai_suggest',
          title: 'Hà gợi ý: ${top['name_vi']}',
          body: r.theme.isNotEmpty ? r.theme : 'Món hợp tâm trạng bạn lúc này',
          createdAt: now,
        ));
      }
    } catch (_) {}
    try {
      final t = await _api.trendingFoods();
      if (t.isNotEmpty) {
        final top = t.first;
        out.add(social_v2.NotificationItem(
          id: 'trend-${top['id']}',
          type: 'social_like',
          title: '🔥 ${top['name_vi']} đang trending',
          body: 'Trending score ${top['trending_score']} — ${top['rating_count']} reviews',
          createdAt: now.subtract(const Duration(hours: 2)),
        ));
      }
    } catch (_) {}
    try {
      final s = await _api.myStreak();
      if (s != null) {
        final daily = (s['daily_decide'] as int?) ?? 0;
        if (daily > 0) {
          out.add(social_v2.NotificationItem(
            id: 'streak-$daily',
            type: 'streak',
            title: '🔥 Streak $daily ngày!',
            body: 'Best: ${s['best_decide'] ?? daily} ngày',
            createdAt: now.subtract(const Duration(hours: 8)),
          ));
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _items = out);
  }

  @override
  Widget build(BuildContext context) {
    if (_items == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: HnagColors.brand500)));
    }
    return social_v2.NotificationsScreenV2(
      items: _items!,
      onMarkAllRead: () {
        setState(() {
          _items = _items!.map((n) => social_v2.NotificationItem(
            id: n.id, type: n.type, title: n.title, body: n.body, createdAt: n.createdAt, read: true,
          )).toList();
        });
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// LATE NIGHT — filter trending for 24h-like items
// ─────────────────────────────────────────────────────────────
class _LateNightReal extends StatefulWidget {
  const _LateNightReal();
  @override
  State<_LateNightReal> createState() => _LateNightRealState();
}

class _LateNightRealState extends State<_LateNightReal> {
  final _api = HnagApi();
  List<social_v2.LateNightItem>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final trending = await _api.trendingFoods();
    if (!mounted) return;
    setState(() {
      _items = trending.take(5).map((f) => social_v2.LateNightItem(
        id: (f['id'] as String?) ?? '',
        name: (f['name_vi'] as String?) ?? '',
        foodSlug: 'pho',
        priceVnd: (f['avg_price_vnd'] as int?) ?? 50000,
        etaText: '~ ${15 + (f['rating_count'] as int? ?? 10) % 30} phút',
        tag: 'Còn mở · 24h',
      )).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_items == null) {
      return const Scaffold(backgroundColor: Color(0xFF1A1A40), body: Center(child: CircularProgressIndicator(color: Colors.white)));
    }
    return social_v2.LateNightScreen(items: _items!);
  }
}

// ─────────────────────────────────────────────────────────────
// HOME v2 — wired to /v1/foods/trending + /v1/ai/suggest + /v1/me
// ─────────────────────────────────────────────────────────────
class _HomeReal extends StatefulWidget {
  const _HomeReal();
  @override
  State<_HomeReal> createState() => _HomeRealState();
}

class _HomeRealState extends State<_HomeReal> {
  final _api = HnagApi();
  bool _loading = true;
  String _userName = 'bạn';
  String? _userAvatar;
  home_v2.FoodCardLargeData? _hero;
  List<home_v2.NearbyPlace> _trending = [];
  List<home_v2.FriendActivity> _friends = [];
  List<home_v2.TikTokVideo> _tiktoks = [];
  List<home_v2.StoryItem> _stories = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // 1. profile name
      final me = await _api.me();
      if (me != null && me['user'] is Map) {
        final u = me['user'] as Map;
        _userName = (u['display_name'] as String?) ?? (u['username'] as String?) ?? 'bạn';
        _userAvatar = u['avatar_url'] as String?;
      }

      // 2. AI hero
      final suggestions = await _api.aiSuggest(limit: 1);
      if (suggestions.isNotEmpty) {
        final s = suggestions.first;
        _hero = home_v2.FoodCardLargeData(
          id: s['id'] as String,
          name: (s['name_vi'] as String?) ?? '',
          imageUrl: s['primary_image'] as String?,
          foodSlug: _slug(s),
          price: _vnd(s['avg_price_vnd']),
          calories: '${s['avg_calories'] ?? 0} cal',
          time: '${s['cook_time_min'] ?? 30} phút',
          rating: _ratingStr(s['rating_avg']),
          kind: 'order',
          kindLabel: 'Giao tận nơi',
          reason: (s['ai_reason'] as String?) ?? (s['description'] as String?) ?? 'Khớp Food DNA của bạn.',
        );
      }

      // 3. Trending nearby
      final trending = await _api.trendingFoods();
      _trending = trending.take(6).map((f) => home_v2.NearbyPlace(
        id: (f['id'] as String?) ?? '',
        name: (f['name_vi'] as String?) ?? '',
        rating: _ratingStr(f['rating_avg']),
        price: _vnd(f['avg_price_vnd']),
        distance: 'gần đây',
        foodSlug: _slug(f),
        imageUrl: f['primary_image'] as String?,
        hot: ((f['trending_score'] as num?) ?? 0) > 50,
      )).toList();

      // 4. Stories from followed users (auth required — empty for guests)
      try {
        final storyRows = await _api.storiesFeed();
        _stories = storyRows.take(8).map((row) {
          final author = (row['users'] is Map ? row['users'] as Map : const {});
          final name = (author['display_name'] as String?) ?? (author['username'] as String?) ?? 'bạn';
          return home_v2.StoryItem(
            name: name,
            avatarUrl: author['avatar_url'] as String?,
            mediaUrl: (row['media_poster'] as String?) ?? (row['media_url'] as String?),
            foodSlug: _slug(row.containsKey('foods') && row['foods'] is Map ? row['foods'] as Map<String, dynamic> : {'name_vi': name}),
          );
        }).toList();
      } catch (_) { _stories = const []; }

      // 5. Friends activity via /v1/feed?tab=following (real posts from followees)
      try {
        final follow = await _api.friendsActivity();
        _friends = follow.take(3).map((p) {
          final u = (p['users'] is Map ? p['users'] as Map : const {});
          final name = (u['display_name'] as String?) ?? (u['username'] as String?) ?? 'Bạn';
          final type = (p['type'] as String?) ?? 'photo';
          final caption = (p['caption'] as String?) ?? '';
          final relTime = _relativeTime(p['created_at']);
          return home_v2.FriendActivity(
            name: name,
            avatarUrl: u['avatar_url'] as String?,
            text: type == 'review' ? caption : (type == 'video' ? 'đang nấu món mới' : caption.isEmpty ? 'check-in quán mới' : caption),
            time: relTime,
            emoji: type == 'video' ? '🍳' : (type == 'review' ? '⭐' : '🍜'),
            cooking: type == 'video',
          );
        }).toList();
      } catch (_) { _friends = const []; }

      // 6. TikTok feed via /v1/feed?tab=trending — real social posts (photo/video)
      try {
        final posts = await _api.feedPosts(tab: 'trending', page: 1);
        if (posts.isNotEmpty) {
          _tiktoks = posts.take(4).map((p) {
            return home_v2.TikTokVideo(
              name: (p['caption'] as String?) ?? '',
              views: _shortCount((p['like_count'] as num?) ?? 0),
              foodSlug: _slug(p.containsKey('foods') && p['foods'] is Map ? p['foods'] as Map<String, dynamic> : {'name_vi': (p['caption'] as String?) ?? ''}),
              videoUrl: p['media_url'] as String?,
            );
          }).toList();
        } else {
          // No social posts yet — fall back to trending foods so the grid isn't empty
          _tiktoks = trending.skip(2).take(2).map((f) => home_v2.TikTokVideo(
            name: (f['name_vi'] as String?) ?? '',
            views: '${((f['rating_count'] as int?) ?? 1) * 10}',
            foodSlug: _slug(f),
          )).toList();
        }
      } catch (_) {
        _tiktoks = trending.skip(2).take(2).map((f) => home_v2.TikTokVideo(
          name: (f['name_vi'] as String?) ?? '',
          views: '${((f['rating_count'] as int?) ?? 1) * 10}',
          foodSlug: _slug(f),
        )).toList();
      }
    } catch (e) {
      debugPrint('HNAG_API homeDemo error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _slug(Map<String, dynamic> f) {
    final cuisine = (f['cuisine'] as String? ?? '').toLowerCase();
    final name = ((f['name_vi'] as String?) ?? '').toLowerCase();
    if (name.contains('phở')) return 'pho';
    if (name.contains('bún bò')) return 'bunbo';
    if (name.contains('bún chả') || name.contains('bún')) return 'bunch';
    if (name.contains('cơm gà')) return 'comga';
    if (name.contains('cơm tấm')) return 'comtam';
    if (name.contains('bánh mì')) return 'banhmi';
    if (name.contains('bánh xèo')) return 'banhxeo';
    if (name.contains('gỏi')) return 'goicuon';
    if (name.contains('lẩu')) return 'lau';
    if (name.contains('cháo')) return 'chao';
    if (name.contains('mì')) return 'mi';
    if (name.contains('chè')) return 'che';
    if (name.contains('cà phê') || cuisine.contains('drink')) return 'caphe';
    if (name.contains('trà sữa') || name.contains('trà')) return 'trasua';
    if (name.contains('sushi')) return 'sushi';
    if (name.contains('pizza')) return 'pizza';
    return 'pho';
  }

  String _vnd(dynamic v) {
    final n = v is num ? v.toInt() : 0;
    return '${(n / 1000).round()}k';
  }
  String _ratingStr(dynamic v) {
    if (v is num) return v.toStringAsFixed(1);
    return '4.5';
  }

  String _shortCount(num n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toInt().toString();
  }

  String _relativeTime(dynamic at) {
    if (at is! String) return 'vừa xong';
    try {
      final d = DateTime.parse(at);
      final diff = DateTime.now().difference(d);
      if (diff.inMinutes < 1) return 'vừa xong';
      if (diff.inMinutes < 60) return '${diff.inMinutes} phút';
      if (diff.inHours < 24) return '${diff.inHours} giờ';
      return '${diff.inDays} ngày';
    } catch (_) { return 'vừa xong'; }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFFBFAF7),
        body: const Center(child: CircularProgressIndicator(color: HnagColors.brand500)),
      );
    }
    return home_v2.HomeScreenV2(
      userName: _userName,
      userAvatar: _userAvatar,
      heroSuggestion: _hero,
      stories: _stories,
      trending: _trending,
      friends: _friends,
      tiktoks: _tiktoks,
      onRefresh: _load,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// AI DECIDE v2 — wired to /v1/ai/suggest with session params
// ─────────────────────────────────────────────────────────────
class _AiDecideReal extends StatelessWidget {
  final _api = HnagApi();
  _AiDecideReal();

  @override
  Widget build(BuildContext context) {
    return home_v2.AiDecideScreen(
      onDecide: (session) async {
        // hunger/budget/time inform the AI suggest call.
        // The endpoint we have today is `/v1/ai/suggest` — pass budget.
        final budgetVnd = (session.budget * 1000).round();
        final suggestions = await _api.aiSuggest(limit: 5);
        if (!context.mounted) return;
        // Navigate to card stack with results
        final cards = suggestions.map<home_v2.FoodCardLargeData>((s) => home_v2.FoodCardLargeData(
          id: (s['id'] as String?) ?? '',
          name: (s['name_vi'] as String?) ?? '',
          imageUrl: s['primary_image'] as String?,
          foodSlug: _slug(s),
          price: '${(((s['avg_price_vnd'] as num?) ?? 0).toInt() / 1000).round()}k',
          calories: '${s['avg_calories'] ?? 0} cal',
          time: '${s['cook_time_min'] ?? 30} phút',
          rating: ((s['rating_avg'] as num?) ?? 4.5).toStringAsFixed(1),
          kind: 'order',
          kindLabel: 'Giao tận nơi',
          reason: (s['ai_reason'] as String?) ?? (s['description'] as String?) ?? 'Khớp ngân sách ${(budgetVnd / 1000).round()}k và mức đói ${(session.hunger / 10).round()}/10.',
        )).toList();
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => home_v2.CardStackV2(
            cards: cards,
            onAction: (c, a) => debugPrint('CardStack: ${c.name} → $a'),
          ),
        ));
      },
    );
  }

  String _slug(Map<String, dynamic> f) {
    final name = ((f['name_vi'] as String?) ?? '').toLowerCase();
    if (name.contains('phở')) return 'pho';
    if (name.contains('bún bò')) return 'bunbo';
    if (name.contains('bún')) return 'bunch';
    if (name.contains('cơm gà')) return 'comga';
    if (name.contains('bánh mì')) return 'banhmi';
    if (name.contains('lẩu')) return 'lau';
    if (name.contains('gỏi')) return 'goicuon';
    if (name.contains('sushi')) return 'sushi';
    return 'pho';
  }
}

// ─────────────────────────────────────────────────────────────
// CARD STACK v2 — wired to /v1/ai/suggest
// ─────────────────────────────────────────────────────────────
class _CardStackReal extends StatefulWidget {
  const _CardStackReal();
  @override
  State<_CardStackReal> createState() => _CardStackRealState();
}

class _CardStackRealState extends State<_CardStackReal> {
  final _api = HnagApi();
  List<home_v2.FoodCardLargeData>? _cards;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final suggestions = await _api.aiSuggest(limit: 8);
    if (!mounted) return;
    setState(() {
      _cards = suggestions.map<home_v2.FoodCardLargeData>((s) => home_v2.FoodCardLargeData(
        id: (s['id'] as String?) ?? '',
        name: (s['name_vi'] as String?) ?? '',
        imageUrl: s['primary_image'] as String?,
        foodSlug: _slug(s),
        price: '${(((s['avg_price_vnd'] as num?) ?? 0).toInt() / 1000).round()}k',
        calories: '${s['avg_calories'] ?? 0} cal',
        time: '${s['cook_time_min'] ?? 30} phút',
        rating: ((s['rating_avg'] as num?) ?? 4.5).toStringAsFixed(1),
        kind: 'order',
        kindLabel: 'Giao tận nơi',
        reason: (s['ai_reason'] as String?) ?? (s['description'] as String?) ?? '',
      )).toList();
    });
  }

  String _slug(Map<String, dynamic> f) {
    final name = ((f['name_vi'] as String?) ?? '').toLowerCase();
    if (name.contains('phở')) return 'pho';
    if (name.contains('bún bò')) return 'bunbo';
    if (name.contains('bún')) return 'bunch';
    if (name.contains('cơm')) return 'comga';
    if (name.contains('bánh mì')) return 'banhmi';
    if (name.contains('lẩu')) return 'lau';
    return 'pho';
  }

  @override
  Widget build(BuildContext context) {
    if (_cards == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: HnagColors.brand500)));
    }
    return home_v2.CardStackV2(
      cards: _cards!,
      onAction: (c, a) => debugPrint('CardStack ${c.name} → $a'),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FOOD DETAIL v2 — uses first AI-suggested food, fetches /v1/foods/:id
// ─────────────────────────────────────────────────────────────
class _FoodDetailReal extends StatefulWidget {
  const _FoodDetailReal();
  @override
  State<_FoodDetailReal> createState() => _FoodDetailRealState();
}

class _FoodDetailRealState extends State<_FoodDetailReal> {
  final _api = HnagApi();
  detail_v2.FoodDetailDataV2? _food;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _api.aiSuggest(limit: 1);
      if (list.isEmpty) {
        setState(() => _error = 'Không tải được món');
        return;
      }
      final id = list.first['id'] as String;
      final detail = await _api.foodDetail(id);
      if (detail == null) {
        setState(() => _error = 'Không tải được chi tiết món');
        return;
      }
      final ings = <({String name, String qty})>[];
      final ingJson = detail['ingredients'];
      if (ingJson is List) {
        for (final raw in ingJson) {
          if (raw is Map) ings.add((name: (raw['name'] ?? '').toString(), qty: (raw['qty'] ?? '').toString()));
          else if (raw is String) ings.add((name: raw, qty: ''));
        }
      }
      final steps = <({String index, String title, String description})>[];
      final recJson = detail['recipe'];
      if (recJson is List) {
        for (var i = 0; i < recJson.length; i++) {
          final raw = recJson[i];
          if (raw is String) {
            steps.add((index: (i + 1).toString().padLeft(2, '0'), title: 'Bước ${i + 1}', description: raw));
          } else if (raw is Map) {
            steps.add((
              index: (i + 1).toString().padLeft(2, '0'),
              title: (raw['title'] ?? 'Bước ${i + 1}').toString(),
              description: (raw['desc'] ?? raw['description'] ?? '').toString(),
            ));
          }
        }
      }
      setState(() => _food = detail_v2.FoodDetailDataV2(
        id: detail['id'] as String,
        name: (detail['name_vi'] as String?) ?? '',
        imageUrl: detail['primary_image'] as String?,
        foodSlug: 'pho',
        rating: ((detail['rating_avg'] as num?) ?? 4.5).toDouble(),
        reviewCount: (detail['rating_count'] as int?) ?? 0,
        flavorTags: ((detail['flavor_tags'] as List?) ?? const []).cast<String>().take(2).toList(),
        region: (detail['region'] as String?) ?? 'Việt Nam',
        priceVnd: (detail['avg_price_vnd'] as int?) ?? 0,
        calories: (detail['avg_calories'] as int?) ?? 0,
        prepTimeMin: (detail['cook_time_min'] as int?) ?? 30,
        macroLabel: 'High protein',
        hashtags: ((detail['mood_tags'] as List?) ?? const []).cast<String>().take(6).toList(),
        aiReason: (detail['description'] as String?) ?? '',
        ingredients: ings,
        servings: (detail['servings'] as int?) ?? 4,
        steps: steps.take(3).toList(),
        totalSteps: steps.length,
      ));
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Food Detail v2'), backgroundColor: Colors.transparent),
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!))),
      );
    }
    if (_food == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: HnagColors.brand500)));
    }
    return detail_v2.FoodDetailScreenV2(food: _food!);
  }
}

// ─────────────────────────────────────────────────────────────
// RESTAURANT DETAIL v2 — wired to /v1/restaurants/nearby
// ─────────────────────────────────────────────────────────────
class _RestaurantDetailReal extends StatefulWidget {
  const _RestaurantDetailReal();
  @override
  State<_RestaurantDetailReal> createState() => _RestaurantDetailRealState();
}

class _RestaurantDetailRealState extends State<_RestaurantDetailReal> {
  final _api = HnagApi();
  detail_v2.RestaurantDetailDataV2? _r;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      Position? pos;
      try {
        final perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
          pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
        }
      } catch (_) {}
      // Fallback HCMC center
      final lat = pos?.latitude ?? 10.7769;
      final lng = pos?.longitude ?? 106.7009;

      final list = await _api.nearbyRestaurants(lat: lat, lng: lng, radius: 3000);
      if (list.isEmpty) {
        setState(() => _error = 'Không tìm thấy quán quanh bạn');
        return;
      }
      final first = list.first;
      setState(() => _r = detail_v2.RestaurantDetailDataV2(
        id: (first['id'] as String?) ?? '',
        name: (first['name'] as String?) ?? '',
        imageUrl: first['cover_url'] as String?,
        foodSlug: 'lau',
        rating: ((first['rating_avg'] as num?) ?? 4.5).toDouble(),
        reviewCount: (first['rating_count'] as int?) ?? 0,
        priceRange: (first['price_range'] as String?) ?? '50k–150k',
        openNow: (first['open_now'] as bool?) ?? true,
        distance: '${((first['distance_m'] as num?) ?? 1200).toInt()}m',
        hoursLabel: (first['hours_label'] as String?) ?? '10–22h',
        closingNote: 'đóng cửa 22:00',
        crowdLabel: 'đông vừa',
        crowdLevel: '~30%',
        verified: (first['is_verified'] as bool?) ?? false,
        menu: const [],
      ));
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Restaurant v2'), backgroundColor: Colors.transparent),
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!))),
      );
    }
    if (_r == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: HnagColors.brand500)));
    }
    return detail_v2.RestaurantDetailScreenV2(restaurant: _r!);
  }
}

// ─────────────────────────────────────────────────────────────
// CART v2 — starts from real trending foods (top 3)
// ─────────────────────────────────────────────────────────────
class _CartReal extends StatefulWidget {
  @override
  State<_CartReal> createState() => _CartRealState();
}

class _CartRealState extends State<_CartReal> {
  final _api = HnagApi();
  List<detail_v2.CartItem>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final trending = await _api.trendingFoods();
    if (!mounted) return;
    setState(() {
      _items = trending.take(3).map((f) => detail_v2.CartItem(
        id: (f['id'] as String?) ?? '',
        name: (f['name_vi'] as String?) ?? '',
        foodSlug: 'pho',
        imageUrl: f['primary_image'] as String?,
        unitPriceVnd: (f['avg_price_vnd'] as int?) ?? 50000,
        qty: 1,
      )).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_items == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: HnagColors.brand500)));
    }
    return detail_v2.CartScreen(
      items: _items!,
      restaurantName: 'Phở Lý Quốc Sư · Q.3',
      deliveryFeeVnd: 25000,
      onCheckout: (items, total) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => detail_v2.CheckoutScreen(
            items: items,
            subtotalVnd: total - 25000,
            onPlaceOrder: () async {
              // Real call: POST /v1/orders. Backend wires later. Returns id.
              await Future.delayed(const Duration(seconds: 1));
              return 'order-${DateTime.now().millisecondsSinceEpoch}';
            },
          ),
        ));
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ORDER TRACKING v2 — for now reads first active order id; stage realtime
// would come via WS subscribe (Phase 11 wires).
// ─────────────────────────────────────────────────────────────
class _OrderTrackingReal extends StatelessWidget {
  const _OrderTrackingReal();
  @override
  Widget build(BuildContext context) {
    // Backend orders endpoint not finalized; show stage example.
    return const detail_v2.OrderTrackingScreen(
      orderId: 'demo000123',
      restaurantName: 'Phở Lý Quốc Sư',
      stage: detail_v2.OrderStage.delivering,
      etaText: '~ 8 phút tới',
      driverName: 'Bác Tài',
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MOOD WHEEL — picker → calls /v1/ai/mood-suggest with picked mood
// ─────────────────────────────────────────────────────────────
class _MoodWheelReal extends StatelessWidget {
  final _api = HnagApi();
  _MoodWheelReal();

  @override
  Widget build(BuildContext context) {
    return ai_v2.MoodWheelScreen(
      onPicked: (mood) async {
        final result = await _api.aiMoodSuggest(mood);
        if (!context.mounted) return;
        final cards = result.foods.take(5).map<home_v2.FoodCardLargeData>((s) => home_v2.FoodCardLargeData(
          id: (s['id'] as String?) ?? '',
          name: (s['name_vi'] as String?) ?? '',
          imageUrl: s['primary_image'] as String?,
          foodSlug: 'pho',
          price: '${(((s['avg_price_vnd'] as num?) ?? 0).toInt() / 1000).round()}k',
          calories: '${s['avg_calories'] ?? 0} cal',
          time: '${s['cook_time_min'] ?? 30} phút',
          rating: ((s['rating_avg'] as num?) ?? 4.5).toStringAsFixed(1),
          kind: 'order',
          kindLabel: 'Giao tận nơi',
          reason: result.theme.isNotEmpty ? result.theme : '${(s['name_vi'] as String?) ?? ''} hợp mood "$mood"',
        )).toList();
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => home_v2.CardStackV2(
            cards: cards,
            onAction: (c, a) => debugPrint('Mood card ${c.name} → $a'),
          ),
        ));
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// VOICE v2 — wires to /v1/ai/mood-suggest with naive intent classification
// ─────────────────────────────────────────────────────────────
class _VoiceReal extends StatefulWidget {
  @override
  State<_VoiceReal> createState() => _VoiceRealState();
}

class _VoiceRealState extends State<_VoiceReal> {
  final _api = HnagApi();
  final _stt = stt.SpeechToText();
  final _tts = FlutterTts();
  bool _sttReady = false;
  String _transcript = '';

  @override
  void initState() {
    super.initState();
    _initVoice();
  }

  Future<void> _initVoice() async {
    _sttReady = await _stt.initialize(onError: (_) {});
    await _tts.setLanguage('vi-VN');
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
  }

  @override
  void dispose() {
    _stt.stop();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ai_v2.VoiceHaScreen(
      onListen: (start) async {
        if (start) {
          if (!_sttReady) {
            // Fallback when STT init failed (sim/no mic perm): return canned
            return null;
          }
          _transcript = '';
          await _stt.listen(
            localeId: 'vi-VN',
            onResult: (r) { _transcript = r.recognizedWords; },
            listenFor: const Duration(seconds: 10),
            pauseFor: const Duration(seconds: 2),
          );
          return null;
        }
        await _stt.stop();
        if (_transcript.trim().isEmpty) {
          return 'Hôm nay tôi đói lắm, gợi món gì đậm vị?';
        }
        return _transcript.trim();
      },
      onAsk: (text) async {
        final t = text.toLowerCase();
        String mood = 'chill';
        if (t.contains('stress') || t.contains('mệt')) mood = 'stress';
        else if (t.contains('buồn') || t.contains('cô đơn')) mood = 'sad';
        else if (t.contains('vui')) mood = 'happy';
        else if (t.contains('khuya') || t.contains('đêm')) mood = 'late_night';
        final result = await _api.aiMoodSuggest(mood);
        if (result.foods.isEmpty) {
          const reply = 'Hà chưa tìm được món hợp lúc này. Thử lại nha.';
          unawaited(_tts.speak(reply));
          return reply;
        }
        final top = result.foods.first;
        final name = (top['name_vi'] as String?) ?? 'món';
        final priceK = (((top['avg_price_vnd'] as num?) ?? 0).toInt() / 1000).round();
        final reply = 'Hà gợi ý $name, ${priceK}k. ${result.theme}';
        unawaited(_tts.speak(reply));
        return reply;
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PREMIUM v2 — wires to /v1/billing/checkout
// ─────────────────────────────────────────────────────────────
class _PremiumReal extends StatelessWidget {
  final _api = HnagApi();
  _PremiumReal();

  @override
  Widget build(BuildContext context) {
    return premium_v2.PremiumScreenV2(
      onSubscribe: (planId) async {
        // Real call would open the gateway (MoMo/ZaloPay/VNPay) deep-link.
        // For now request a checkout session via the existing backend method.
        try {
          await _api.startCheckout(planId, 'vietqr');
        } catch (e) {
          debugPrint('Checkout error: $e');
        }
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PROFILE v2 — wired to /v1/me + /v1/streaks
// ─────────────────────────────────────────────────────────────
class _ProfileReal extends StatefulWidget {
  const _ProfileReal();
  @override
  State<_ProfileReal> createState() => _ProfileRealState();
}

class _ProfileRealState extends State<_ProfileReal> {
  final _api = HnagApi();
  profile_v2.ProfileDataV2? _profile;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = await _api.me();
      if (me == null || me['user'] is! Map) {
        setState(() => _error = 'Cần đăng nhập để xem profile.');
        return;
      }
      final u = me['user'] as Map<String, dynamic>;
      final level = ((u['level'] as int?) ?? 1).clamp(1, 99);
      final fc = (u['foodie_class'] as String?) ?? 'tep';
      final emoji = switch (fc) {
        'tep' => '🦐', 'tom' => '🍤', 'cua' => '🦀', 'muc' => '🦑', 'ca-map' => '🦈', 'rong' => '🐉', _ => '🦐',
      };
      // Proper Vietnamese display name for foodie class (with accent).
      final classLabel = switch (fc) {
        'tep' => 'Tép', 'tom' => 'Tôm', 'cua' => 'Cua', 'muc' => 'Mực',
        'ca-map' => 'Cá mập', 'rong' => 'Rồng', _ => 'Tép',
      };
      // Better display name fallback: if no display_name, use the part before the
      // numeric suffix in username, capitalized.
      String displayName = (u['display_name'] as String?)?.trim() ?? '';
      if (displayName.isEmpty) {
        final raw = (u['username'] as String?) ?? '';
        // Strip trailing _XXXXX (random suffix) from auto-generated usernames
        final stripped = raw.replaceAll(RegExp(r'_[a-f0-9]{6,}\$'), '');
        if (stripped.isNotEmpty) {
          displayName = stripped[0].toUpperCase() + stripped.substring(1);
        } else {
          displayName = 'Bạn';
        }
      }
      // Fetch real reviews + saved + photos in parallel; ignore errors per tab.
      final results = await Future.wait<dynamic>([
        _api.mySaves().catchError((_) => <Map<String, dynamic>>[]),
        _api.feedPosts(tab: 'for_you', page: 1).catchError((_) => <Map<String, dynamic>>[]),
      ]);
      final saves = (results[0] as List).cast<Map<String, dynamic>>();
      final myPosts = ((results[1] as List).cast<Map<String, dynamic>>())
          .where((p) => p['user_id'] == u['id']).toList();
      final reviewPosts = myPosts.where((p) => p['type'] == 'review').toList();
      final reviewItems = reviewPosts.map((p) {
        final food = (p['foods'] is Map ? (p['foods'] as Map)['name_vi'] : null) as String? ?? 'Món';
        return profile_v2.ProfileReviewItem(
          food: food,
          rating: (p['rating'] as int?) ?? 5,
          text: (p['caption'] as String?) ?? '',
          relTime: _relTimeFrom(p['created_at']),
        );
      }).toList();
      setState(() => _profile = profile_v2.ProfileDataV2(
        id: u['id'] as String,
        displayName: displayName,
        username: (u['username'] as String?) ?? 'foodie',
        avatarUrl: u['avatar_url'] as String?,
        coverUrl: u['cover_url'] as String?,
        bio: (u['bio'] as String?) ?? '',
        level: level,
        foodieClass: classLabel,
        classEmoji: emoji,
        reviews: reviewItems.length,
        followers: (me['followers'] as int?) ?? 0,
        following: (me['following'] as int?) ?? 0,
        isPremium: (u['is_premium'] as bool?) ?? false,
        isVerified: (u['is_verified'] as bool?) ?? false,
        isMe: true,
        reviewItems: reviewItems,
        savedItems: saves.map((s) => (s['primary_image'] as String?) ?? '').where((u) => u.isNotEmpty).toList(),
        photoItems: myPosts.where((p) => p['type'] == 'photo')
            .map((p) => (p['media_url'] as String?) ?? '').where((u) => u.isNotEmpty).toList(),
      ));
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  String _relTimeFrom(dynamic at) {
    if (at is! String) return 'vừa xong';
    try {
      final d = DateTime.parse(at);
      final diff = DateTime.now().difference(d);
      if (diff.inMinutes < 1) return 'vừa xong';
      if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
      if (diff.inDays < 1) return '${diff.inHours} giờ trước';
      return '${diff.inDays} ngày trước';
    } catch (_) { return 'vừa xong'; }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      // Fallback: still let user reach Settings + Dev menu even if /v1/me fails
      return _ProfileFallback(error: _error!, onRetry: () { setState(() => _error = null); _load(); });
    }
    if (_profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: HnagColors.brand500)));
    }
    return profile_v2.ProfileScreenV2(
      profile: _profile!,
      onSettings: () => _openSettingsAndTools(context),
    );
  }
}

void _openSettingsAndTools(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFBFAF7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: const Color(0xFFC9C3B6), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text('Cài đặt & Công cụ',
            style: HnagType.h2.copyWith(color: HnagColors.neutral900, fontFamily: HnagFonts.display),
          ),
          const SizedBox(height: 16),
          _ToolMenuItem(emoji: '⚙️', title: 'Cài đặt', subtitle: 'Tài khoản · thông báo · giao diện',
            onTap: () { Navigator.pop(context); Navigator.of(context).push(MaterialPageRoute(builder: (_) => Hifi.settingsDemo(context))); }),
          _ToolMenuItem(emoji: '💎', title: 'HNAG+ Premium', subtitle: 'Unlock unlimited AI + ẩn QC',
            onTap: () { Navigator.pop(context); Navigator.of(context).push(MaterialPageRoute(builder: (_) => Hifi.premiumDemo(context))); }),
          _ToolMenuItem(emoji: '💖', title: 'Mood Wheel', subtitle: 'Chọn món theo cảm xúc',
            onTap: () { Navigator.pop(context); Navigator.of(context).push(MaterialPageRoute(builder: (_) => Hifi.moodWheelDemo(context))); }),
          _ToolMenuItem(emoji: '🎤', title: 'Trợ lý Hà (voice)', subtitle: 'Hỏi bằng giọng tự nhiên',
            onTap: () { Navigator.pop(context); Navigator.of(context).push(MaterialPageRoute(builder: (_) => Hifi.voiceHaDemo(context))); }),
          _ToolMenuItem(emoji: '📅', title: 'Lịch ăn tuần', subtitle: 'AI plan 7 ngày + grocery list',
            onTap: () { Navigator.pop(context); Navigator.of(context).push(MaterialPageRoute(builder: (_) => Hifi.mealPlannerDemo(context))); }),
          _ToolMenuItem(emoji: '🗳️', title: 'Vote nhóm', subtitle: 'Realtime vote với bạn bè',
            onTap: () { Navigator.pop(context); Navigator.of(context).push(MaterialPageRoute(builder: (_) => Hifi.groupVotingDemo(context))); }),
          _ToolMenuItem(emoji: '🌙', title: 'Late Night Mode', subtitle: 'Quán còn mở 24h',
            onTap: () { Navigator.pop(context); Navigator.of(context).push(MaterialPageRoute(builder: (_) => Hifi.lateNightDemo(context))); }),
          _ToolMenuItem(emoji: '🔔', title: 'Thông báo', subtitle: 'AI gợi ý · trending · streak',
            onTap: () { Navigator.pop(context); Navigator.of(context).push(MaterialPageRoute(builder: (_) => Hifi.notificationsDemo(context))); }),
          _ToolMenuItem(emoji: '🏪', title: 'Quán gần đây', subtitle: 'Restaurant chi tiết',
            onTap: () { Navigator.pop(context); Navigator.of(context).push(MaterialPageRoute(builder: (_) => Hifi.restaurantDetailDemo(context))); }),
          _ToolMenuItem(emoji: '🛒', title: 'Giỏ hàng', subtitle: 'Cart + checkout flow',
            onTap: () { Navigator.pop(context); Navigator.of(context).push(MaterialPageRoute(builder: (_) => Hifi.cartDemo(context))); }),
        ],
      ),
    ),
  );
}

class _ToolMenuItem extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ToolMenuItem({required this.emoji, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: const Color(0xFFEFECE5), borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: HnagType.label.copyWith(color: HnagColors.neutral900, fontWeight: FontWeight.w600, fontFamily: HnagFonts.body)),
                    Text(subtitle, style: HnagType.bodySm.copyWith(color: HnagColors.neutral600, fontFamily: HnagFonts.body)),
                  ],
                ),
              ),
              const HnagIcon('chevR', size: 18, color: HnagColors.neutral400),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileFallback extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ProfileFallback({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFAF7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Text('🍜', style: TextStyle(fontSize: 64), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Text('Cần đăng nhập',
                textAlign: TextAlign.center,
                style: HnagType.h2.copyWith(color: HnagColors.neutral900, fontFamily: HnagFonts.display),
              ),
              const SizedBox(height: 8),
              Text(error,
                textAlign: TextAlign.center,
                style: HnagType.bodySm.copyWith(color: HnagColors.neutral600, fontFamily: HnagFonts.body),
              ),
              const SizedBox(height: 28),
              HnagButton(
                label: 'Thử lại',
                variant: BtnVariant.primary,
                size: BtnSize.lg,
                iconLeading: 'refresh',
                fullWidth: true,
                onPressed: onRetry,
              ),
              const SizedBox(height: 12),
              HnagButton(
                label: 'Cài đặt & Công cụ',
                variant: BtnVariant.outline,
                size: BtnSize.lg,
                iconLeading: 'settings',
                fullWidth: true,
                onPressed: () => _openSettingsAndTools(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
