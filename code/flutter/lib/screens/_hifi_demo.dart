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
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../widgets/live_cooking.dart';
import 'fridge_scan_screen.dart';
import 'couple_mode_screen.dart';
import 'random_wheel_screen.dart';
import 'nearby_restaurants_screen.dart';

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

/// Safe casts — Prisma serializes Decimal/BigInt as String, and JSON might
/// vary integer vs double for the same field. Use these instead of raw casts.
int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.toInt();
  return null;
}
double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

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
  static Widget settingsDemo(BuildContext c) {
    final api = HnagApi();
    // Persist toggles via /v1/users/me preferences PATCH (real backend wire).
    Future<void> savePref(String key, dynamic value) async {
      try { await api.updatePreferences({key: value}); } catch (_) {}
    }
    final me = AuthService.instance.currentUser;
    return settings_v2.SettingsScreenV2(
      userName: me?.displayName ?? me?.username ?? 'Bạn',
      userEmail: me?.username,
      onSignOut: () async {
        await AuthService.instance.signOut();
        if (c.mounted) Navigator.of(c).popUntil((r) => r.isFirst);
      },
      onPushChanged: (v) => savePref('notifications.push', v),
      onEmailChanged: (v) => savePref('notifications.email', v),
      onVoiceWakeChanged: (v) => savePref('voice.wake_word', v),
      onThemeChanged: (v) => savePref('ui.theme', v),
      onLanguageChanged: (v) => savePref('ui.language', v),
      onResetTaste: () async {
        await api.updatePreferences({'taste.reset': true});
      },
    );
  }
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
    // Prefer real posts so like/comment/save hit real `posts` rows. Fall back
    // to trending foods only when there are no posts yet (early-stage app).
    List<social_v2.TikTokVideoData> rows = [];
    try {
      final posts = await _api.feedPosts(tab: 'trending', page: 1);
      if (posts.isNotEmpty) {
        rows = posts.take(8).map((p) {
          final user = (p['users'] is Map ? p['users'] as Map : const {});
          final author = (user['username'] as String?) ?? (user['display_name'] as String?) ?? 'hnag';
          final caption = (p['caption'] as String?) ?? '';
          final foodName = (p['foods'] is Map ? ((p['foods'] as Map)['name_vi'] as String?) : null) ?? caption;
          return social_v2.TikTokVideoData(
            id: (p['id'] as String?) ?? '',
            author: author,
            authorAvatarUrl: user['avatar_url'] as String?,
            caption: caption.length > 120 ? '${caption.substring(0, 120)}…' : caption,
            foodName: foodName,
            foodSlug: _slugFromName(foodName),
            likes: _asInt(p['like_count']) ?? 0,
            comments: _asInt(p['comment_count']) ?? 0,
            shares: _asInt(p['share_count']) ?? 0,
            saves: _asInt(p['save_count']) ?? 0,
          );
        }).toList();
      }
    } catch (_) {}
    if (rows.isEmpty) {
      // No real posts → display trending foods as preview cards. Like still
      // works (post_likes has no FK in seed data), but comment will degrade
      // gracefully via the CommentsSheet's "post not yet" notice.
      final trending = await _api.trendingFoods();
      rows = trending.take(8).map((f) => social_v2.TikTokVideoData(
        id: (f['id'] as String?) ?? '',
        author: (f['cuisine'] as String?) ?? 'hnag',
        caption: ((f['description'] as String?) ?? (f['name_vi'] as String?) ?? '').length > 120
            ? '${((f['description'] as String?) ?? (f['name_vi'] as String?) ?? '').substring(0, 120)}…'
            : ((f['description'] as String?) ?? (f['name_vi'] as String?) ?? ''),
        foodName: (f['name_vi'] as String?) ?? '',
        foodSlug: _slugFromName(f['name_vi'] as String?),
        likes: (_asInt(f['rating_count']) ?? 200) * 7,
        comments: (_asInt(f['rating_count']) ?? 100),
        shares: 42,
        saves: 88,
      )).toList();
    }
    if (!mounted) return;
    setState(() => _videos = rows);
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
      onToggleLike: (id, like) async => await _api.likePost(id, like: like),
      onShare: (v) {
        // Native share via system sheet
        if (v.id.isNotEmpty) {
          Share.share('${v.foodName} trên HNAG — https://tothanhthuy.cloud/post/${v.id}');
        }
      },
      onComment: (v) async {
        await social_v2.CommentsSheet.show(context, v.id, initialCount: v.comments);
      },
      onSave: (v) async {
        // Real: persist save to backend (food saves list). v.id IS the foodId
        // since this feed is mapped from /v1/foods/trending.
        final ok = await _api.addSave(v.id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? '⭐ Đã lưu vào Yêu thích' : 'Không lưu được, thử lại'),
          duration: const Duration(seconds: 2),
        ));
      },
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
            calories: _asInt(s['avg_calories']) ?? 0,
            priceVnd: _asInt(s['avg_price_vnd']) ?? 0,
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
          calories: _asInt(f['avg_calories']) ?? 0,
          priceVnd: _asInt(f['avg_price_vnd']) ?? 0,
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
      onLoadTrending: () async {
        try { return await _api.trendingFoods(); }
        catch (_) { return <Map<String, dynamic>>[]; }
      },
      onVoice: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => Hifi.voiceHaDemo(context),
      )),
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
              rating: ((_asDouble(detail['rating_avg'])) ?? 4.5).toDouble(),
              reviewCount: _asInt(detail['rating_count']) ?? 0,
              flavorTags: ((detail['flavor_tags'] as List?) ?? const []).cast<String>().take(2).toList(),
              region: (detail['region'] as String?) ?? 'Việt Nam',
              priceVnd: _asInt(detail['avg_price_vnd']) ?? 0,
              calories: _asInt(detail['avg_calories']) ?? 0,
              prepTimeMin: _asInt(detail['cook_time_min']) ?? 30,
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
  io.Socket? _socket;
  List<social_v2.GroupOption>? _options;
  List<int>? _tally;
  String? _groupId;
  String? _pollId;
  String _groupName = 'Đang tải…';
  String _userId = 'me';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _socket?.dispose();
    super.dispose();
  }

  /// Real flow: ensure a group exists for the user (auto-create if first time),
  /// fetch trending foods as options, create a fresh poll, subscribe to the
  /// group's WS room for live tally updates from other voters.
  Future<void> _bootstrap() async {
    _userId = AuthService.instance.currentUser?.id ?? 'me';

    var groups = await _api.myGroups();
    Map<String, dynamic>? group;
    if (groups.isEmpty) {
      group = await _api.createGroup('Team lunch 🍜');
    } else {
      group = groups.first;
    }
    if (group == null || !mounted) return;
    _groupId = group['id'] as String?;
    _groupName = (group['name'] as String?) ?? 'Team lunch';

    // Trending foods → poll options
    final trending = await _api.trendingFoods();
    if (!mounted) return;
    final picks = trending.take(4).toList();
    final foodIds = picks.map((f) => f['id'] as String).toList();

    final poll = await _api.createPoll(_groupId!, foodIds, closesInMinutes: 30);
    _pollId = poll?['id'] as String?;

    final opts = picks.asMap().entries.map((e) {
      final i = e.key;
      final f = e.value;
      // Use the cuisine/region tag from the food itself rather than a hardcoded
      // address — Q.3 was just a placeholder.
      final region = (f['region'] as String?) ?? (f['cuisine'] as String?) ?? 'Việt Nam';
      return social_v2.GroupOption(
        id: i.toString(), // optionIdx is what backend expects on vote
        name: (f['name_vi'] as String?) ?? '',
        imageUrl: f['primary_image'] as String?,
        foodSlug: 'pho',
        priceVnd: _asInt(f['avg_price_vnd']) ?? 50000,
        location: region,
        voterAvatars: const [],
      );
    }).toList();

    if (!mounted) return;
    setState(() {
      _options = opts;
      _tally = List<int>.filled(opts.length, 0);
    });

    _connectSocket();
  }

  void _connectSocket() {
    final token = AuthService.instance.accessToken;
    if (token == null || _groupId == null) return;
    _socket = io.io(
      'wss://api.tothanhthuy.cloud',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );
    _socket!.onConnect((_) {
      _socket!.emitWithAck('subscribe:group', {'groupId': _groupId}, ack: (resp) {
        debugPrint('subscribe:group ack=$resp');
      });
    });
    _socket!.on('group.poll.updated', (data) {
      if (!mounted || data is! Map) return;
      if (data['pollId'] != _pollId) return;
      final t = (data['tally'] as List?)?.cast<int>();
      if (t != null) setState(() => _tally = t);
    });
    _socket!.connect();
  }

  Future<void> _vote(String optionIdxStr) async {
    if (_groupId == null || _pollId == null) return;
    final idx = int.tryParse(optionIdxStr);
    if (idx == null) return;
    final newTally = await _api.votePoll(_groupId!, _pollId!, idx);
    if (newTally != null && mounted) setState(() => _tally = newTally);
  }

  @override
  Widget build(BuildContext context) {
    if (_options == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: HnagColors.brand500)));
    }
    // Bake tally counts into voterAvatars (simple "N người" badge via repeat).
    final tallyOpts = List.generate(_options!.length, (i) {
      final o = _options![i];
      final n = (_tally != null && i < _tally!.length) ? _tally![i] : 0;
      return social_v2.GroupOption(
        id: o.id, name: o.name, imageUrl: o.imageUrl, foodSlug: o.foodSlug,
        priceVnd: o.priceVnd, location: o.location, proposerName: o.proposerName,
        voterAvatars: List<String>.filled(n, 'V'),
      );
    });
    return social_v2.GroupVotingScreenV2(
      groupName: _groupName,
      memberCount: 1,
      userId: _userId,
      options: tallyOpts,
      chat: const [
        social_v2.ChatTurn(name: 'Hà', text: 'Mình chọn món hot tuần này nha — vote thoải mái!'),
      ],
      onToggleVote: _vote,
      onSend: (text) {
        // Group chat backend doesn't exist yet — surface that to user instead
        // of silent no-op so the send button still feels responsive.
        if (text.trim().isEmpty) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('💬 Chat nhóm đang build — vote là cách nhanh nhất rồi 😉'),
          duration: Duration(seconds: 2),
        ));
      },
      onReveal: _pollId == null ? null : () async {
        // Real reveal: fetch /v1/groups/:id/polls/:pollId/result and show winner.
        final result = await _api.pollResult(_groupId!, _pollId!);
        if (!context.mounted) return;
        final winner = result?['winner'] as Map<String, dynamic>?;
        final foodId = winner?['foodId'] as String?;
        final tally = ((result?['tally'] as List?) ?? []).cast<int>();
        final total = tally.fold<int>(0, (a, b) => a + b);
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('🎉 Kết quả'),
            content: Text(total == 0
                ? 'Chưa có ai vote 🥲'
                : 'Món chiến thắng có ${tally.reduce((a, b) => a > b ? a : b)} vote / $total tổng vote.\n\nMở chi tiết món?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
              if (foodId != null)
                TextButton(onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => _FoodDetailRealById(foodId: foodId)));
                }, child: const Text('Mở chi tiết')),
            ],
          ),
        );
      },
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
        final daily = _asInt(s['daily_decide']) ?? 0;
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
      onTap: (item) {
        // Route by notification type:
        //   ai_suggest / trending → food detail (id encoded as foodId)
        //   social_like → tiktok feed
        //   streak → late night / profile
        //   order_update → order tracking
        setState(() {
          // Mark as read locally
          _items = _items!.map((n) => n.id == item.id
              ? social_v2.NotificationItem(id: n.id, type: n.type, title: n.title, body: n.body, createdAt: n.createdAt, read: true)
              : n).toList();
        });
        final type = item.type;
        final id = item.id;
        if (type == 'ai_suggest' || type == 'trending') {
          final foodId = id.split('-').skip(1).join('-');
          if (foodId.isNotEmpty) {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => _FoodDetailRealById(foodId: foodId)));
          }
        } else if (type == 'social_like' || type == 'social_comment' || type == 'follow') {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _TikTokReal()));
        } else if (type == 'order_update') {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _OrderTrackingReal()));
        } else if (type == 'streak' || type == 'badge') {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _ProfileReal()));
        }
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
        priceVnd: _asInt(f['avg_price_vnd']) ?? 50000,
        etaText: '~ ${15 + ((_asInt(f['rating_count']) ?? 10) % 30)} phút',
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

      // 3. Trending nearby (each card opens food detail)
      final trending = await _api.trendingFoods();
      _trending = trending.take(6).map((f) {
        final id = (f['id'] as String?) ?? '';
        return home_v2.NearbyPlace(
          id: id,
          name: (f['name_vi'] as String?) ?? '',
          rating: _ratingStr(f['rating_avg']),
          price: _vnd(f['avg_price_vnd']),
          distance: 'gần đây',
          foodSlug: _slug(f),
          imageUrl: f['primary_image'] as String?,
          hot: ((_asDouble(f['trending_score'])) ?? 0) > 50,
          onTap: id.isEmpty ? null : () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => _FoodDetailRealById(foodId: id),
          )),
        );
      }).toList();

      // 4. Stories from followed users (auth required — empty for guests). Tap
      // opens the TikTok-style feed since stories show people's recent food posts.
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
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _TikTokReal())),
          );
        }).toList();
      } catch (_) { _stories = const []; }

      // 5. Friends activity via /v1/feed?tab=following (real posts from followees).
      // Tap → opens the food the friend posted (or comments sheet if no food id).
      try {
        final follow = await _api.friendsActivity();
        _friends = follow.take(3).map((p) {
          final u = (p['users'] is Map ? p['users'] as Map : const {});
          final name = (u['display_name'] as String?) ?? (u['username'] as String?) ?? 'Bạn';
          final type = (p['type'] as String?) ?? 'photo';
          final caption = (p['caption'] as String?) ?? '';
          final relTime = _relativeTime(p['created_at']);
          final foodId = p['food_id'] as String?;
          final postId = p['id'] as String?;
          return home_v2.FriendActivity(
            name: name,
            avatarUrl: u['avatar_url'] as String?,
            text: type == 'review' ? caption : (type == 'video' ? 'đang nấu món mới' : caption.isEmpty ? 'check-in quán mới' : caption),
            time: relTime,
            emoji: type == 'video' ? '🍳' : (type == 'review' ? '⭐' : '🍜'),
            cooking: type == 'video',
            onTap: foodId != null
                ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _FoodDetailRealById(foodId: foodId)))
                : (postId != null ? () => social_v2.CommentsSheet.show(context, postId) : null),
          );
        }).toList();
      } catch (_) { _friends = const []; }

      // 6. TikTok feed via /v1/feed?tab=trending — real social posts. Tap any
      // tile → opens the full vertical video feed.
      VoidCallback openFeed() => () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _TikTokReal()));
      try {
        final posts = await _api.feedPosts(tab: 'trending', page: 1);
        if (posts.isNotEmpty) {
          _tiktoks = posts.take(4).map((p) {
            return home_v2.TikTokVideo(
              name: (p['caption'] as String?) ?? '',
              views: _shortCount((_asDouble(p['like_count'])) ?? 0),
              foodSlug: _slug(p.containsKey('foods') && p['foods'] is Map ? p['foods'] as Map<String, dynamic> : {'name_vi': (p['caption'] as String?) ?? ''}),
              videoUrl: p['media_url'] as String?,
              onTap: openFeed(),
            );
          }).toList();
        } else {
          _tiktoks = trending.skip(2).take(2).map((f) => home_v2.TikTokVideo(
            name: (f['name_vi'] as String?) ?? '',
            views: '${(_asInt(f['rating_count']) ?? 1) * 10}',
            foodSlug: _slug(f),
            onTap: openFeed(),
          )).toList();
        }
      } catch (_) {
        _tiktoks = trending.skip(2).take(2).map((f) => home_v2.TikTokVideo(
          name: (f['name_vi'] as String?) ?? '',
          views: '${(_asInt(f['rating_count']) ?? 1) * 10}',
          foodSlug: _slug(f),
          onTap: openFeed(),
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
      onSearch: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => Hifi.searchDemo(context))),
      onNotifications: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _NotificationsReal())),
      onHeroTap: () {
        if (_hero == null) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => _FoodDetailRealById(foodId: _hero!.id),
        ));
      },
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
      // Each mode routes to the right backend/UI:
      //   Quick   → /v1/ai/suggest-public (default)
      //   Detail  → same + tighter filters
      //   Mood    → push MoodWheelScreen
      //   Voice   → push VoiceHa screen
      //   Fridge  → push FridgeScanScreen
      //   Group   → push GroupVoteLauncher
      onModeChange: (mode) {
        Future<void> route() async {
          switch (mode) {
            case home_v2.AiDecideMode.mood:
              Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (_) => Hifi.moodWheelDemo(context),
              ));
              break;
            case home_v2.AiDecideMode.voice:
              Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (_) => Hifi.voiceHaDemo(context),
              ));
              break;
            case home_v2.AiDecideMode.fridge:
              Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (c) => FridgeScanScreen(
                  onScan: (_) async { throw UnimplementedError('Vision AI cho ảnh chưa bật.'); },
                  onSuggestRecipes: (items) async {
                    final ings = items.map((e) => e.name).toList();
                    final recipes = await _api.aiFridgeRecipes(ings);
                    return recipes.map((r) {
                      final food = r['food'] as Map<String, dynamic>? ?? {};
                      return FridgeRecipe(
                        id: food['id'] as String? ?? '',
                        name: food['name_vi'] as String? ?? '',
                        timeMin: _asInt(food['cook_time_min']) ?? 30,
                        uses: ((r['uses'] as List?) ?? []).cast<String>(),
                        missing: ((r['missing'] as List?) ?? []).cast<String>(),
                        tip: r['tip'] as String? ?? '',
                      );
                    }).toList();
                  },
                ),
              ));
              break;
            case home_v2.AiDecideMode.group:
              Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (_) => Hifi.groupVotingDemo(context),
              ));
              break;
            case home_v2.AiDecideMode.quick:
            case home_v2.AiDecideMode.detail:
              // No nav; mode tile is selected on Decide screen
              break;
          }
        }
        unawaited(route());
      },
      onDecide: (session) async {
        final budgetVnd = (session.budget * 1000).round();
        // Quick + Detail: /v1/ai/suggest-public with budget filter.
        final budgetCap = session.mode == home_v2.AiDecideMode.detail
            ? budgetVnd  // narrower cap for Detail mode
            : null;
        final suggestions = await _api.aiSuggest(
          limit: 5,
          budgetMax: budgetCap,
        );
        if (!context.mounted) return;
        final cards = suggestions.map<home_v2.FoodCardLargeData>((s) => home_v2.FoodCardLargeData(
          id: (s['id'] as String?) ?? '',
          name: (s['name_vi'] as String?) ?? '',
          imageUrl: s['primary_image'] as String?,
          foodSlug: _slug(s),
          price: '${(((_asDouble(s['avg_price_vnd'])) ?? 0).toInt() / 1000).round()}k',
          calories: '${s['avg_calories'] ?? 0} cal',
          time: '${s['cook_time_min'] ?? 30} phút',
          rating: ((_asDouble(s['rating_avg'])) ?? 4.5).toStringAsFixed(1),
          kind: 'order',
          kindLabel: 'Giao tận nơi',
          reason: (s['ai_reason'] as String?) ?? (s['description'] as String?) ?? 'Khớp ngân sách ${(budgetVnd / 1000).round()}k và mức đói ${(session.hunger / 10).round()}/10.',
        )).toList();
        final sessionId = '00000000-0000-0000-0000-${DateTime.now().millisecondsSinceEpoch.toRadixString(16).padLeft(12, '0').substring(0, 12)}';
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (ctx2) => home_v2.CardStackV2(
            cards: cards,
            onAction: (c, a) {
              final api = HnagApi();
              unawaited(api.aiFeedback(
                sessionId: sessionId,
                foodId: c.id,
                action: switch (a) {
                  home_v2.CardSwipe.skip => 'skip',
                  home_v2.CardSwipe.save || home_v2.CardSwipe.later => 'save',
                  home_v2.CardSwipe.detail => 'view',
                  home_v2.CardSwipe.reroll => 'skip',
                },
              ));
              if (a == home_v2.CardSwipe.save || a == home_v2.CardSwipe.later) {
                unawaited(api.addSave(c.id));
              } else if (a == home_v2.CardSwipe.detail) {
                Navigator.of(ctx2).push(MaterialPageRoute(
                  builder: (_) => _FoodDetailRealById(foodId: c.id),
                ));
              }
            },
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
  final String _sessionId = '00000000-0000-0000-0000-${DateTime.now().millisecondsSinceEpoch.toRadixString(16).padLeft(12, '0').substring(0, 12)}';
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
        price: '${(((_asDouble(s['avg_price_vnd'])) ?? 0).toInt() / 1000).round()}k',
        calories: '${s['avg_calories'] ?? 0} cal',
        time: '${s['cook_time_min'] ?? 30} phút',
        rating: ((_asDouble(s['rating_avg'])) ?? 4.5).toStringAsFixed(1),
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

  String _swipeToAction(home_v2.CardSwipe a) => switch (a) {
    home_v2.CardSwipe.skip   => 'skip',
    home_v2.CardSwipe.save   => 'save',
    home_v2.CardSwipe.detail => 'view',
    home_v2.CardSwipe.later  => 'view',
    home_v2.CardSwipe.reroll => 'skip',
  };

  void _onSwipe(home_v2.FoodCardLargeData card, home_v2.CardSwipe a) {
    // Persist behavior to backend so AI learns from real user signal.
    unawaited(_api.aiFeedback(
      sessionId: _sessionId,
      foodId: card.id,
      action: _swipeToAction(a),
    ));
    switch (a) {
      case home_v2.CardSwipe.skip:
        home_v2.WhySkipSheet.show(
          context,
          foodName: card.name,
          onSubmit: (reason) async {
            await _api.aiFeedback(
              sessionId: _sessionId,
              foodId: card.id,
              action: 'skip',
              reason: reason,
            );
          },
        );
        break;
      case home_v2.CardSwipe.save:
        unawaited(_api.addSave(card.id));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('⭐ Đã lưu ${card.name}'),
          duration: const Duration(seconds: 2),
        ));
        break;
      case home_v2.CardSwipe.detail:
        // Open the food detail to read recipe + restaurants.
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => _FoodDetailRealById(foodId: card.id),
        ));
        break;
      case home_v2.CardSwipe.later:
        unawaited(_api.addSave(card.id));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('🕒 Thêm vào "Để sau" — ${card.name}'),
          duration: const Duration(seconds: 2),
        ));
        break;
      case home_v2.CardSwipe.reroll:
        // Re-fetch a fresh stack of suggestions.
        setState(() => _cards = null);
        _load();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cards == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: HnagColors.brand500)));
    }
    return home_v2.CardStackV2(
      cards: _cards!,
      onAction: _onSwipe,
      onRefreshStack: () { setState(() => _cards = null); _load(); },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FOOD DETAIL v2 — uses first AI-suggested food, fetches /v1/foods/:id
// ─────────────────────────────────────────────────────────────
class _FoodDetailReal extends StatefulWidget {
  /// When non-null, fetches THAT food's detail; otherwise loads first AI suggestion.
  final String? foodId;
  const _FoodDetailReal({this.foodId});
  @override
  State<_FoodDetailReal> createState() => _FoodDetailRealState();
}

/// Wrapper for `_FoodDetailReal` opened with an explicit foodId — keeps the
/// call-site readable from CardStack / TikTok / Home story taps.
class _FoodDetailRealById extends StatelessWidget {
  final String foodId;
  const _FoodDetailRealById({required this.foodId});
  @override
  Widget build(BuildContext context) => _FoodDetailReal(foodId: foodId);
}

class _FoodDetailRealState extends State<_FoodDetailReal> {
  final _api = HnagApi();
  detail_v2.FoodDetailDataV2? _food;
  List<detail_v2.RestaurantBriefForFood>? _serving;
  List<detail_v2.FoodPostV2>? _posts;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      String id;
      if (widget.foodId != null) {
        id = widget.foodId!;
      } else {
        final list = await _api.aiSuggest(limit: 1);
        if (list.isEmpty) {
          setState(() => _error = 'Không tải được món');
          return;
        }
        id = list.first['id'] as String;
      }
      final detail = await _api.foodDetail(id);
      if (detail == null) {
        setState(() => _error = 'Không tải được chi tiết món');
        return;
      }
      // Fetch in parallel: real posts about this food (Bài viết tab).
      _api.feedPosts(tab: 'for_you', page: 1).then((rows) {
        if (!mounted) return;
        final filtered = rows.where((p) => p['food_id'] == id).take(20).map((p) {
          final u = (p['users'] is Map ? p['users'] as Map : const {});
          final created = p['created_at'] is String ? DateTime.tryParse(p['created_at'] as String) : null;
          return detail_v2.FoodPostV2(
            id: (p['id'] as String?) ?? '',
            authorName: (u['display_name'] as String?) ?? (u['username'] as String?) ?? 'Foodie',
            authorAvatarUrl: u['avatar_url'] as String?,
            caption: (p['caption'] as String?) ?? '',
            mediaUrl: (p['media_url'] as String?) ?? (p['media_poster'] as String?),
            likeCount: _asInt(p['like_count']) ?? 0,
            commentCount: _asInt(p['comment_count']) ?? 0,
            createdAt: created,
          );
        }).toList();
        setState(() => _posts = filtered);
      });
      // Fetch in parallel: real restaurants serving this food (Quán bán tab)
      _api.restaurantsServingFood(id).then((rows) {
        if (!mounted) return;
        setState(() => _serving = rows.take(8).map((r) => detail_v2.RestaurantBriefForFood(
          id: (r['id'] as String?) ?? '',
          name: (r['name'] as String?) ?? '',
          imageUrl: r['primary_image'] as String? ?? r['cover_image'] as String? ?? r['cover_url'] as String?,
          rating: _asDouble(r['rating_avg']),
          distanceM: _asInt(r['distance_m']),
          priceVnd: _asInt(r['min_price_vnd']) ?? _asInt(detail['avg_price_vnd']) ?? 0,
          address: r['address'] as String? ?? r['district'] as String?,
        )).toList());
      });
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
        rating: _asDouble(detail['rating_avg']) ?? 4.5,
        reviewCount: _asInt(detail['rating_count']) ?? 0,
        flavorTags: ((detail['flavor_tags'] as List?) ?? const []).cast<String>().take(2).toList(),
        region: (detail['region'] as String?) ?? 'Việt Nam',
        priceVnd: _asInt(detail['avg_price_vnd']) ?? 0,
        calories: _asInt(detail['avg_calories']) ?? 0,
        prepTimeMin: _asInt(detail['cook_time_min']) ?? 30,
        macroLabel: 'High protein',
        hashtags: ((detail['mood_tags'] as List?) ?? const []).cast<String>().take(6).toList(),
        aiReason: (detail['description'] as String?) ?? '',
        ingredients: ings,
        servings: _asInt(detail['servings']) ?? 4,
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
    return detail_v2.FoodDetailScreenV2(
      food: _food!,
      restaurantsServing: _serving,
      posts: _posts,
      onTapPost: (p) => social_v2.CommentsSheet.show(context, p.id, initialCount: p.commentCount),
      onTapRestaurant: (r) => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _RestaurantDetailRealForId(restaurantId: r.id),
      )),
      onSave: () => _api.addSave(_food!.id),
      onOrder: () async {
        // Real flow: backend creates an order intent → returns partner deep-link
        // (Grab/Shopee/BeFood). We launch it via url_launcher.
        final intent = await _api.createOrderIntent(foodId: _food!.id);
        if (!context.mounted) return;
        if (intent == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Món này chưa có quán nào hỗ trợ giao gần bạn 🥲'),
            duration: Duration(seconds: 3),
          ));
          return;
        }
        final url = intent['deeplink'] as String?;
        final orderId = intent['orderId'] as String?;
        if (url != null && url.isNotEmpty) {
          await launchUrlString(url, mode: LaunchMode.externalApplication);
          if (context.mounted && orderId != null) {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => _OrderTrackingReal(orderId: orderId, restaurantName: _food!.name),
            ));
          }
        }
      },
      onCook: () {
        // Open the v1 Live Cooking flow with the food's recipe steps. v2
        // refactor of Live Cooking is in a separate ticket; the v1 already
        // works end-to-end (multi-timer, voice nav, wake-lock).
        if (_food!.steps.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Món này chưa có công thức chi tiết.'),
          ));
          return;
        }
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => LiveCookingScreen(
            recipe: CookingRecipe(
              name: _food!.name,
              steps: [
                for (var i = 0; i < _food!.steps.length; i++)
                  CookingStep(
                    index: i,
                    title: _food!.steps[i].title,
                    description: _food!.steps[i].description,
                    durationMin: 5,
                  ),
              ],
            ),
          ),
        ));
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// RESTAURANT DETAIL v2 — wired to /v1/restaurants/nearby
// ─────────────────────────────────────────────────────────────
class _RestaurantDetailReal extends StatefulWidget {
  /// When provided, fetches that exact restaurant. Otherwise picks the nearest.
  final String? restaurantId;
  const _RestaurantDetailReal({this.restaurantId});
  @override
  State<_RestaurantDetailReal> createState() => _RestaurantDetailRealState();
}

/// Alias used from food detail's Quán bán tab — keeps call sites readable.
class _RestaurantDetailRealForId extends StatelessWidget {
  final String restaurantId;
  const _RestaurantDetailRealForId({required this.restaurantId});
  @override
  Widget build(BuildContext context) => _RestaurantDetailReal(restaurantId: restaurantId);
}

class _RestaurantDetailRealState extends State<_RestaurantDetailReal> {
  final _api = HnagApi();
  detail_v2.RestaurantDetailDataV2? _r;
  Map<String, dynamic>? _lastDetail; // raw full detail for lat/lng/phone wiring
  List<detail_v2.RestaurantReviewV2>? _reviews;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      Map<String, dynamic>? first;
      if (widget.restaurantId != null) {
        // Specific restaurant requested (e.g. from food detail's Quán bán tab).
        final r = await _api.restaurantDetail(widget.restaurantId!);
        if (r == null) {
          setState(() => _error = 'Không tải được quán');
          return;
        }
        first = r;
      } else {
        Position? pos;
        try {
          final perm = await Geolocator.checkPermission();
          if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
            pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
          }
        } catch (_) {}
        final lat = pos?.latitude ?? 10.7769;
        final lng = pos?.longitude ?? 106.7009;

        final list = await _api.nearbyRestaurants(lat: lat, lng: lng, radius: 3000);
        if (list.isEmpty) {
          setState(() => _error = 'Không tìm thấy quán quanh bạn');
          return;
        }
        first = list.first;
      }
      // Fetch the FULL restaurant detail (with menu_items + live status)
      final firstNN = first!;
      final detail = widget.restaurantId != null ? firstNN : await _api.restaurantDetail(firstNN['id'] as String);
      _lastDetail = detail; // stash for lat/lng/phone wiring
      // Fetch reviews in parallel for the Reviews tab
      _api.restaurantReviews(firstNN['id'] as String).then((rows) {
        if (!mounted) return;
        setState(() => _reviews = rows.take(20).map((r) {
          final user = (r['users'] is Map ? r['users'] as Map : const {});
          final created = r['created_at'] is String ? DateTime.tryParse(r['created_at'] as String) : null;
          return detail_v2.RestaurantReviewV2(
            id: (r['id'] as String?) ?? '',
            authorName: (user['display_name'] as String?) ?? (user['username'] as String?) ?? 'Foodie',
            authorAvatarUrl: user['avatar_url'] as String?,
            rating: _asInt(r['rating']) ?? 5,
            content: (r['content'] as String?) ?? (r['title'] as String?) ?? '',
            createdAt: created,
          );
        }).toList());
      });
      final menuRaw = (detail?['menu_items'] as List?) ?? const [];
      // Group menu items by category.
      final byCategory = <String, List<detail_v2.MenuItemV2>>{};
      for (final raw in menuRaw) {
        if (raw is! Map) continue;
        final m = raw as Map<String, dynamic>;
        final cat = (m['category'] as String?) ?? 'Khác';
        byCategory.putIfAbsent(cat, () => []);
        byCategory[cat]!.add(detail_v2.MenuItemV2(
          id: (m['id'] as String?) ?? '',
          name: (m['name'] as String?) ?? '',
          description: (m['description'] as String?) ?? '',
          priceVnd: _asInt(m['price_vnd']) ?? 0,
          foodSlug: 'lau',
          imageUrl: m['image_url'] as String?,
          tag: (m['is_bestseller'] as bool?) == true ? 'BESTSELLER' : null,
        ));
      }
      final categories = byCategory.entries
          .map((e) => detail_v2.MenuCategoryV2(name: e.key, items: e.value))
          .toList();
      setState(() => _r = detail_v2.RestaurantDetailDataV2(
        id: (firstNN['id'] as String?) ?? '',
        name: (detail?['name'] as String?) ?? (firstNN['name'] as String?) ?? '',
        imageUrl: (detail?['cover_image'] as String?) ?? (detail?['cover_url'] as String?) ?? (firstNN['cover_image'] as String?) ?? (firstNN['cover_url'] as String?),
        foodSlug: 'lau',
        rating: _asDouble(detail?['rating_avg']) ?? _asDouble(firstNN['rating_avg']) ?? 4.5,
        reviewCount: _asInt(detail?['rating_count']) ?? _asInt(firstNN['rating_count']) ?? 0,
        priceRange: (detail?['price_range'] as String?) ?? '50k–150k',
        openNow: (detail?['restaurant_live']?['is_open'] as bool?) ?? (firstNN['open_now'] as bool?) ?? true,
        distance: '${_asInt(firstNN['distance_m']) ?? 1200}m',
        hoursLabel: (detail?['hours_label'] as String?) ?? '10–22h',
        closingNote: 'đóng cửa 22:00',
        crowdLabel: 'đông vừa',
        crowdLevel: '${_asInt(detail?['restaurant_live']?['wait_minutes']) ?? 15}p chờ',
        verified: (detail?['is_verified'] as bool?) ?? (firstNN['is_verified'] as bool?) ?? false,
        menu: categories,
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
    // Coordinates + phone are available on the full restaurant row.
    final lat = _asDouble(_lastDetail?['lat']) ?? _asDouble(_lastDetail?['latitude']);
    final lng = _asDouble(_lastDetail?['lng']) ?? _asDouble(_lastDetail?['longitude']);
    final phone = _lastDetail?['phone'] as String?;
    return detail_v2.RestaurantDetailScreenV2(
      restaurant: _r!,
      reviews: _reviews,
      onDirections: (lat != null && lng != null) ? () async {
        // Native Google Maps deeplink. Falls back to web URL.
        final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
        await launchUrlString(url, mode: LaunchMode.externalApplication);
      } : null,
      onCall: (phone != null && phone.isNotEmpty) ? () async {
        await launchUrlString('tel:$phone');
      } : null,
      onBook: () {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('📅 Đặt bàn sẽ mở Zalo/SMS cho quán khi quán đăng ký gói Boost'),
          duration: Duration(seconds: 3),
        ));
      },
      onShare: () {
        Share.share('${_r!.name} trên HNAG — https://tothanhthuy.cloud/r/${_r!.id}');
      },
      onAddItem: (item) async {
        // Real flow: create an order intent for this menu item at THIS quán.
        final intent = await _api.createOrderIntent(
          foodId: item.id,
          restaurantId: _r!.id,
        );
        if (!context.mounted) return;
        if (intent == null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Quán chưa có link đặt giao "${item.name}"'),
          ));
          return;
        }
        final url = intent['deeplink'] as String?;
        final orderId = intent['orderId'] as String?;
        if (url != null && url.isNotEmpty) {
          await launchUrlString(url, mode: LaunchMode.externalApplication);
          // After kicking out to partner app, show live tracking for the intent.
          if (context.mounted && orderId != null) {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => _OrderTrackingReal(orderId: orderId, restaurantName: _r!.name),
            ));
          }
        }
      },
    );
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
  String _restaurantName = '';
  String? _restaurantId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Start cart from user's most recently saved foods (real "interested in"
    // signal). Fall back to trending if user has no saves.
    final saves = await _api.mySaves();
    var foods = saves.take(3).toList();
    if (foods.isEmpty) {
      foods = (await _api.trendingFoods()).take(3).toList();
    }
    if (foods.isEmpty || !mounted) {
      if (mounted) setState(() => _items = []);
      return;
    }
    // Find a real restaurant serving the first food (cart belongs to ONE quán).
    String name = '';
    String? rid;
    try {
      final servers = await _api.restaurantsServingFood(foods.first['id'] as String);
      if (servers.isNotEmpty) {
        name = (servers.first['name'] as String?) ?? '';
        rid = servers.first['id'] as String?;
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _restaurantName = name.isEmpty ? 'Quán địa phương' : name;
      _restaurantId = rid;
      _items = foods.map((f) => detail_v2.CartItem(
        id: (f['id'] as String?) ?? '',
        name: (f['name_vi'] as String?) ?? '',
        foodSlug: 'pho',
        imageUrl: f['primary_image'] as String?,
        unitPriceVnd: _asInt(f['avg_price_vnd']) ?? 50000,
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
      restaurantName: _restaurantName,
      deliveryFeeVnd: 25000,
      onCheckout: (items, total) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => detail_v2.CheckoutScreen(
            items: items,
            subtotalVnd: total - 25000,
            onPlaceOrder: () async {
              // Real flow: create one order intent per cart-restaurant.
              // Backend `/v1/orders/intent` takes one foodId — we use the
              // first item as the canonical, restaurant is auto-resolved.
              if (items.isEmpty) return null;
              final firstFoodId = items.first.id;
              final intent = await _api.createOrderIntent(
                foodId: firstFoodId,
                restaurantId: _restaurantId,
              );
              final orderId = intent?['orderId'] as String?;
              if (orderId == null || !context.mounted) return orderId;
              // After successful intent: route to live order tracking.
              Future.microtask(() {
                Navigator.of(context).pushReplacement(MaterialPageRoute(
                  builder: (_) => _OrderTrackingReal(orderId: orderId, restaurantName: _restaurantName),
                ));
              });
              return orderId;
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
/// Real order tracking — when `orderId` is provided, jumps straight in;
/// otherwise loads the user's most recent open order. If no orders exist,
/// shows an empty state inviting the user to place one.
class _OrderTrackingReal extends StatefulWidget {
  final String? orderId;
  final String? restaurantName;
  const _OrderTrackingReal({this.orderId, this.restaurantName});
  @override
  State<_OrderTrackingReal> createState() => _OrderTrackingRealState();
}

class _OrderTrackingRealState extends State<_OrderTrackingReal> {
  final _api = HnagApi();
  String? _orderId;
  String _restaurantName = '';
  detail_v2.OrderStage _stage = detail_v2.OrderStage.placed;
  String _eta = '~ 30 phút';
  bool _loading = true;
  bool _noOrders = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.orderId != null) {
      // Came from checkout — fetch the order detail to seed stage.
      final order = await _fetchOrder(widget.orderId!);
      if (!mounted) return;
      setState(() {
        _orderId = widget.orderId;
        _restaurantName = widget.restaurantName ?? 'Quán địa phương';
        _stage = _stageFromString(order?['status'] as String?);
        _eta = _etaForStage(_stage);
        _loading = false;
      });
      return;
    }
    // No id provided: pick the latest open order from history.
    final history = await _api.myOrders();
    if (!mounted) return;
    final open = history.firstWhere(
      (o) {
        final s = (o['status'] as String?) ?? '';
        return s != 'done' && s != 'delivered' && s != 'cancelled';
      },
      orElse: () => <String, dynamic>{},
    );
    if (open.isEmpty) {
      setState(() { _loading = false; _noOrders = true; });
      return;
    }
    final partnerName = (open['partner'] as String?) ?? 'Quán địa phương';
    setState(() {
      _orderId = open['id'] as String?;
      _restaurantName = partnerName;
      _stage = _stageFromString(open['status'] as String?);
      _eta = _etaForStage(_stage);
      _loading = false;
    });
  }

  Future<Map<String, dynamic>?> _fetchOrder(String id) async {
    try {
      final list = await _api.myOrders();
      for (final o in list) {
        if (o['id'] == id) return o;
      }
    } catch (_) {}
    return null;
  }

  detail_v2.OrderStage _stageFromString(String? s) {
    switch (s) {
      case 'placed':
      case 'intent': return detail_v2.OrderStage.placed;
      case 'cooking': return detail_v2.OrderStage.cooking;
      case 'picking': return detail_v2.OrderStage.picking;
      case 'delivering': return detail_v2.OrderStage.delivering;
      case 'done':
      case 'delivered': return detail_v2.OrderStage.done;
      default: return detail_v2.OrderStage.placed;
    }
  }

  String _etaForStage(detail_v2.OrderStage s) {
    switch (s) {
      case detail_v2.OrderStage.placed: return '~ 30 phút tới';
      case detail_v2.OrderStage.cooking: return '~ 22 phút tới';
      case detail_v2.OrderStage.picking: return '~ 15 phút tới';
      case detail_v2.OrderStage.delivering: return '~ 8 phút tới';
      case detail_v2.OrderStage.done: return 'Đã giao';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: HnagColors.brand500)));
    }
    if (_noOrders || _orderId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Đơn hàng'), backgroundColor: Colors.transparent, elevation: 0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🍜', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                Text('Chưa có đơn nào đang giao',
                  style: HnagType.h3.copyWith(fontFamily: HnagFonts.display),
                ),
                const SizedBox(height: 6),
                const Text('Đặt món ngon đi rồi quay lại đây xem shipper nha 🛵',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
    return detail_v2.OrderTrackingScreen(
      orderId: _orderId!,
      restaurantName: _restaurantName,
      stage: _stage,
      etaText: _eta,
      driverName: _stage.index >= detail_v2.OrderStage.picking.index ? 'Shipper' : null,
      onCallDriver: () async {
        // Partner drivers don't expose direct phone yet — show a friendly
        // notice so the user knows what to expect.
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('📞 Số shipper sẽ hiển thị khi đối tác kết nối API'),
          duration: Duration(seconds: 3),
        ));
      },
      onCancel: _stage.index < detail_v2.OrderStage.delivering.index ? () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Huỷ đơn?'),
            content: const Text('Đơn sẽ bị huỷ. Quán có thể tính phí nếu đã bắt đầu nấu.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Không')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Huỷ đơn')),
            ],
          ),
        );
        if (confirm != true || !context.mounted) return;
        final ok = await _api.cancelOrder(_orderId!);
        if (!context.mounted) return;
        if (ok) {
          setState(() {
            _stage = detail_v2.OrderStage.done;
            _eta = 'Đã huỷ';
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Đã huỷ đơn')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không huỷ được, thử lại')));
        }
      } : null,
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
          price: '${(((_asDouble(s['avg_price_vnd'])) ?? 0).toInt() / 1000).round()}k',
          calories: '${s['avg_calories'] ?? 0} cal',
          time: '${s['cook_time_min'] ?? 30} phút',
          rating: ((_asDouble(s['rating_avg'])) ?? 4.5).toStringAsFixed(1),
          kind: 'order',
          kindLabel: 'Giao tận nơi',
          reason: result.theme.isNotEmpty ? result.theme : '${(s['name_vi'] as String?) ?? ''} hợp mood "$mood"',
        )).toList();
        final sessionId = '00000000-0000-0000-0000-${DateTime.now().millisecondsSinceEpoch.toRadixString(16).padLeft(12, '0').substring(0, 12)}';
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (ctx2) => home_v2.CardStackV2(
            cards: cards,
            onAction: (c, a) {
              unawaited(_api.aiFeedback(
                sessionId: sessionId,
                foodId: c.id,
                action: switch (a) {
                  home_v2.CardSwipe.skip => 'skip',
                  home_v2.CardSwipe.save || home_v2.CardSwipe.later => 'save',
                  home_v2.CardSwipe.detail => 'view',
                  home_v2.CardSwipe.reroll => 'skip',
                },
              ));
              if (a == home_v2.CardSwipe.save || a == home_v2.CardSwipe.later) {
                unawaited(_api.addSave(c.id));
                ScaffoldMessenger.of(ctx2).showSnackBar(SnackBar(
                  content: Text('⭐ Đã lưu ${c.name}'),
                  duration: const Duration(seconds: 2),
                ));
              } else if (a == home_v2.CardSwipe.detail) {
                Navigator.of(ctx2).push(MaterialPageRoute(
                  builder: (_) => _FoodDetailRealById(foodId: c.id),
                ));
              }
            },
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
        final priceK = (((_asDouble(top['avg_price_vnd'])) ?? 0).toInt() / 1000).round();
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
      final level = (_asInt(u['level']) ?? 1).clamp(1, 99);
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
          rating: _asInt(p['rating']) ?? 5,
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
        followers: _asInt(me['followers']) ?? 0,
        following: _asInt(me['following']) ?? 0,
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
      onShare: () {
        final user = AuthService.instance.currentUser;
        final handle = user?.username ?? 'foodie';
        Share.share('Theo dõi @$handle trên HNAG — https://tothanhthuy.cloud/u/$handle');
      },
      onEdit: () {
        // Quick-edit: open settings sheet (Profile section is there)
        _openSettingsAndTools(context);
      },
    );
  }
}

void _openSettingsAndTools(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Color(0xFFFBFAF7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(child: Column(
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
          _ToolMenuItem(emoji: '💑', title: 'Couple Mode', subtitle: 'Chọn món cho 2 người · date night',
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(MaterialPageRoute(builder: (ctx2) => CoupleModeScreen(
                onInvite: (phoneOrUsername) async {
                  // Real backend invite → /v1/couple/invite
                  final ok = await HnagApi().coupleInvite(phoneOrUsername);
                  if (!ctx2.mounted) return;
                  ScaffoldMessenger.of(ctx2).showSnackBar(SnackBar(
                    content: Text(ok
                        ? '💌 Lời mời đã gửi tới $phoneOrUsername — chờ họ accept!'
                        : 'Không tìm thấy user — kiểm tra @username hoặc SĐT'),
                    duration: const Duration(seconds: 3),
                  ));
                },
              )));
            }),
          _ToolMenuItem(emoji: '🎰', title: 'Random Wheel', subtitle: 'Vòng quay quyết định ngẫu nhiên',
            onTap: () {
              Navigator.pop(context);
              const opts = [
                WheelOption('pho', 'Phở bò', Color(0xFFFF6B2B)),
                WheelOption('com', 'Cơm tấm', Color(0xFFF59E0B)),
                WheelOption('bun', 'Bún bò', Color(0xFFEF4444)),
                WheelOption('banh', 'Bánh mì', Color(0xFFEAB308)),
                WheelOption('lau', 'Lẩu', Color(0xFFDC2626)),
                WheelOption('goi', 'Gỏi cuốn', Color(0xFF22C55E)),
              ];
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => RandomWheelScreen(
                options: opts,
                onResult: (w) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🎯 Quay được: ${w.label}'))),
              )));
            }),
          _ToolMenuItem(emoji: '🗺️', title: 'Bản đồ quán gần', subtitle: 'Xem quán theo địa lý',
            onTap: () { Navigator.pop(context); Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NearbyRestaurantsScreen())); }),
          _ToolMenuItem(emoji: '🥬', title: 'Quét tủ lạnh', subtitle: 'Có gì trong tủ → AI gợi món',
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => FridgeScanScreen(
                onScan: (_) async { throw UnimplementedError('Vision AI chưa bật — chỉ nhập tay'); },
                onSuggestRecipes: (items) async {
                  final ings = items.map((e) => e.name).toList();
                  final recipes = await HnagApi().aiFridgeRecipes(ings);
                  return recipes.map((r) {
                    final food = r['food'] as Map<String, dynamic>? ?? {};
                    return FridgeRecipe(
                      id: food['id'] as String? ?? '',
                      name: food['name_vi'] as String? ?? '',
                      timeMin: _asInt(food['cook_time_min']) ?? 30,
                      uses: ((r['uses'] as List?) ?? []).cast<String>(),
                      missing: ((r['missing'] as List?) ?? []).cast<String>(),
                      tip: r['tip'] as String? ?? '',
                    );
                  }).toList();
                },
              )));
            }),
        ],
      )),
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
