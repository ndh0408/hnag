import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'theme/app_theme.dart';
import 'models/food_card.dart';
import 'api/hnag_api.dart';
import 'api/auth_service.dart';

import 'widgets/home_feed.dart';
import 'widgets/card_stack.dart';
import 'widgets/voice_assistant.dart';
import 'widgets/live_cooking.dart';

import 'screens/onboarding_screen.dart';
import 'screens/auth/auth.dart' as auth_v2;
import 'screens/restaurant_claim_screen.dart';
import 'screens/mood_selector_screen.dart';
import 'screens/mood_result_screen.dart';
import 'screens/fridge_scan_screen.dart';
import 'screens/group_vote_launcher.dart';
import 'screens/random_wheel_screen.dart';
import 'screens/premium_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/search_screen.dart';
import 'screens/food_detail_screen.dart';
import 'screens/restaurant_detail_screen.dart';
import 'screens/meal_planner_screen.dart';
import 'screens/nearby_restaurants_screen.dart';

/// Mapbox PUBLIC token (pk.*) — safe to embed in the app binary (Mapbox public
/// tokens are designed for client-side use). Override at build time with
/// --dart-define=MAPBOX_TOKEN=pk.xxxx. Rotate in the Mapbox dashboard if abused.
const _mapboxToken = String.fromEnvironment(
  'MAPBOX_TOKEN',
  defaultValue: 'pk.eyJ1IjoibmRoMDQwOCIsImEiOiJjbW93ZGR1NDUwZ3h1MnRwdXc5Y2pzMTZ3In0.d2_0AkgEVIApE5XG0EQdAg',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));
  if (_mapboxToken.isNotEmpty) {
    MapboxOptions.setAccessToken(_mapboxToken);
  }
  await AuthService.instance.init();
  runApp(const ProviderScope(child: HnagApp()));
}

class HnagApp extends StatelessWidget {
  const HnagApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hôm Nay Ăn Gì?',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const _Boot(),
    );
  }
}

class _Boot extends StatefulWidget {
  const _Boot();
  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  bool _splashDone = false;
  bool _onboarded = true;

  @override
  void initState() {
    super.initState();
    AuthService.instance.isOnboarded().then((v) {
      if (mounted) setState(() => _onboarded = v);
    });
  }

  Future<bool> _doLogin(String email) async {
    await AuthService.instance.sendEmailOtp(email);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) {
      return auth_v2.SplashScreenV2(onReady: () => setState(() => _splashDone = true));
    }

    return StreamBuilder<AuthUser?>(
      stream: AuthService.instance.userChanges,
      initialData: AuthService.instance.currentUser,
      builder: (_, snap) {
        if (snap.data == null) {
          return _AuthFlow(onDoLogin: _doLogin);
        }
        if (!_onboarded) {
          return OnboardingScreen(onComplete: (dna) async {
            // Persist taste preferences to the backend, then mark done.
            try { await HnagApi().updatePreferences(dna); } catch (_) {}
            await AuthService.instance.setOnboarded();
            if (mounted) setState(() => _onboarded = true);
          });
        }
        return const RootScreen();
      },
    );
  }
}

/// New v2 auth flow: Welcome → Login (email/phone) → OTP. Falls through to
/// the original onboarding once `AuthService.currentUser` flips non-null.
class _AuthFlow extends StatefulWidget {
  final Future<bool> Function(String email) onDoLogin;
  const _AuthFlow({required this.onDoLogin});
  @override
  State<_AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<_AuthFlow> {
  bool _welcomeDone = false;

  void _goLogin() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => auth_v2.LoginScreenV2(
        onSendOtp: (emailOrPhone) async {
          if (emailOrPhone.contains('@')) {
            await widget.onDoLogin(emailOrPhone);
          } else {
            // Phone OTP not wired yet — fall back to email flow path.
            // TODO Phase 8: hook phone OTP backend.
            await widget.onDoLogin(emailOrPhone);
          }
          if (!mounted) return;
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => auth_v2.OtpScreen(
              destination: emailOrPhone,
              onVerify: (otp) async {
                if (emailOrPhone.contains('@')) {
                  return AuthService.instance.verifyEmailOtp(emailOrPhone, otp);
                }
                return false;
              },
              onResend: () => widget.onDoLogin(emailOrPhone),
            ),
          ));
        },
        onApple: null, // wired in Phase 8
        onGoogle: null,
        onGuest: null,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (!_welcomeDone) {
      return auth_v2.WelcomeScreen(
        onStart: () => setState(() => _welcomeDone = true),
        onSignIn: _goLogin,
      );
    }
    return auth_v2.PermissionsScreen(
      onComplete: (_) async {
        if (!mounted) return;
        _goLogin();
      },
    );
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});
  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _HomeTab(),
      const _AiDecideTab(),
      const _ToolsTab(),
      const _ProfileTab(),
    ];
    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_rounded), label: 'AI Decide'),
          NavigationDestination(icon: Icon(Icons.apps_rounded), label: 'Tools'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.phoOrange,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.mic_rounded),
              label: const Text('Hỏi Hà'),
              onPressed: () => _openVoice(context),
            )
          : null,
    );
  }

  void _openVoice(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VoiceAssistantScreen(onTranscript: _voiceIntent),
    ));
  }

  Future<HaResponse> _voiceIntent(String transcript) async {
    final api = HnagApi();
    final t = transcript.toLowerCase();
    String mood = 'chill';
    if (t.contains('stress') || t.contains('mệt')) mood = 'stress';
    else if (t.contains('buồn') || t.contains('cô đơn')) mood = 'sad';
    else if (t.contains('vui') || t.contains('hạnh phúc')) mood = 'happy';
    else if (t.contains('khuya') || t.contains('đêm')) mood = 'late_night';
    else if (t.contains('vội') || t.contains('nhanh')) mood = 'rushed';
    else if (t.contains('mưa') || t.contains('lạnh')) mood = 'rainy';

    final result = await api.aiMoodSuggest(mood);
    if (result.foods.isEmpty) {
      return const HaResponse(speech: 'Hà chưa tìm được món hợp lúc này. Thử lại nha.', emotion: 'warm');
    }
    final top = result.foods.first;
    final name = top['name_vi'] as String? ?? 'món';
    final price = top['avg_price_vnd'] as int? ?? 0;
    return HaResponse(
      speech: 'Hà gợi ý $name, ${(price / 1000).round()}k. ${result.theme}',
      emotion: 'warm',
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab();
  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final _api = HnagApi();
  List<FoodCard>? _cards;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final trending = await _api.trendingFoods();
      final more = await _api.listFoods(limit: 30);
      debugPrint('HNAG_API trending=${trending.length} list=${more.length}');
      final all = [...trending, ...more];
      final seen = <String>{};
      final parsed = <FoodCard>[];
      for (final j in all) {
        final id = j['id'];
        if (id is! String || !seen.add(id)) continue; // skip null/dup ids
        try {
          parsed.add(FoodCardFromApi.fromApiJson(j));
        } catch (e) {
          debugPrint('HNAG_API skip item $id: $e'); // one bad item must not nuke the whole feed
        }
      }
      debugPrint('HNAG_API parsed ${parsed.length} cards');
      setState(() {
        _cards = parsed.isNotEmpty ? parsed : FoodCard.demos();
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('HNAG_API load error: $e\n$st');
      setState(() {
        _cards = FoodCard.demos();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _cards == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.phoOrange));
    }
    // Always have content: use API if available, fall back to demos.
    final cards = (_cards != null && _cards!.isNotEmpty) ? _cards! : FoodCard.demos();
    final hero = cards.first;
    final base = cards.length > 1 ? cards.sublist(1) : cards;
    return HomeFeed(
      heroPick: hero,
      onRefresh: _load,
      onCardTap: (card) async {
        final detail = await _api.foodDetail(card.foodId);
        if (!context.mounted) return;
        final ings = <({String name, String qty})>[];
        final ingJson = detail?['ingredients'];
        if (ingJson is List) {
          for (final raw in ingJson) {
            if (raw is Map) {
              ings.add((name: (raw['name'] ?? '').toString(), qty: (raw['qty'] ?? '').toString()));
            } else if (raw is String) {
              ings.add((name: raw, qty: ''));
            }
          }
        }
        final steps = <String>[];
        final recJson = detail?['recipe'];
        if (recJson is List) {
          for (final s in recJson) {
            if (s is String) steps.add(s);
          }
        } else if (recJson is Map && recJson['steps'] is List) {
          for (final s in (recJson['steps'] as List)) {
            if (s is String) steps.add(s);
          }
        }
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => FoodDetailScreen(
          food: FoodDetailData(
            id: card.foodId, name: card.title, image: card.media.poster,
            rating: card.rating.avg, ratingCount: card.rating.count,
            priceVnd: card.price.amount, calories: card.calories ?? 0,
            cookTimeMin: (detail?['cook_time_min'] as int?) ?? 30,
            tags: card.tags,
            description: (detail?['description'] as String?) ?? card.aiReason,
            ingredients: ings,
            steps: steps,
          ),
        )));
      },
      sections: {
        '🔥 Trending Near You': base.take(8).toList(),
        '💰 Dưới 50K': base.where((c) => c.price.amount < 50000).toList()..addAll(base.take(3)),
        '🌧 Trời mưa, ấm bụng': base.where((c) {
          final l = c.title.toLowerCase();
          return l.contains('phở') || l.contains('cháo') || l.contains('lẩu') || l.contains('bún bò');
        }).toList()..addAll(base.take(4)),
        '🎬 Viral TikTok tuần này': base.skip(2).take(8).toList(),
        '💎 Hidden Gems': base.skip(5).take(8).toList(),
      },
    );
  }
}

class _AiDecideTab extends StatefulWidget {
  const _AiDecideTab();
  @override
  State<_AiDecideTab> createState() => _AiDecideTabState();
}

class _AiDecideTabState extends State<_AiDecideTab> {
  final _api = HnagApi();
  List<FoodCard>? _cards;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Use AI suggest endpoint (context-aware: time-of-day based filtering)
    final foods = await _api.aiSuggest(limit: 8);
    if (!mounted) return;
    final parsed = <FoodCard>[];
    for (final j in foods.take(8)) {
      try {
        parsed.add(FoodCardFromApi.fromApiJson(j));
      } catch (e) {
        debugPrint('HNAG_API skip ai-suggest item: $e'); // one bad item must not blank the tab
      }
    }
    setState(() {
      _cards = parsed;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cards == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.phoOrange));
    }
    final cards = _cards!.isNotEmpty ? _cards! : FoodCard.demos();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(children: [
              const Text('Hà gợi ý cho bạn', style: AppTypography.displayLg),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.mood, color: AppColors.phoOrange),
                tooltip: 'Pick mood',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MoodSelectorScreen(onMoodPicked: (m) => Navigator.pop(context)),
                )),
              ),
            ]),
            const SizedBox(height: 12),
            Expanded(
              child: CardStack(
                cards: cards,
                onSwipe: (c, a) => debugPrint('${c.title} → $a'),
                onCtaTap: (c, a) async {
                  final q = Uri.encodeComponent(c.title);
                  if (a == 'order') {
                    await launchUrlString('https://food.grab.com/vn/vi/restaurants?query=$q', mode: LaunchMode.externalApplication);
                  } else if (a == 'dine') {
                    await launchUrlString('https://www.google.com/maps/search/?api=1&query=$q', mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolsTab extends StatelessWidget {
  const _ToolsTab();

  static const _moodLabels = {
    'happy': ('Vui', Color(0xFFFFD166)),
    'sad': ('Buồn', Color(0xFF4A6FA5)),
    'tired': ('Mệt', Color(0xFF8E7B9A)),
    'stress': ('Stress', Color(0xFFE63946)),
    'chill': ('Chill', Color(0xFF26A69A)),
    'lonely': ('Cô đơn', Color(0xFFC79DD9)),
    'late_night': ('Khuya', Color(0xFF1A1A40)),
    'celebrate': ('Ăn mừng', Color(0xFFFF6B2B)),
  };

  Future<void> _onMoodPicked(BuildContext context, String mood) async {
    Navigator.pop(context); // close mood selector
    final label = _moodLabels[mood]?.$1 ?? mood;
    final color = _moodLabels[mood]?.$2 ?? AppColors.phoOrange;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MoodResultScreen(mood: mood, moodLabel: label, moodColor: color),
    ));
  }

  Future<List<WheelOption>> _loadRandomWheelOptions() async {
    final api = HnagApi();
    final foods = await api.aiRandom(n: 8);
    if (foods.isEmpty) {
      return const [
        WheelOption('1', 'Phở bò', AppColors.phoOrange),
        WheelOption('2', 'Bún chả', AppColors.basil),
        WheelOption('3', 'Cơm tấm', AppColors.turmeric),
        WheelOption('4', 'Lẩu Thái', AppColors.danger),
        WheelOption('5', 'Sushi', Color(0xFFA855F7)),
        WheelOption('6', 'BBQ', Color(0xFF6B4FA0)),
      ];
    }
    final colors = [
      AppColors.phoOrange, AppColors.basil, AppColors.turmeric, AppColors.danger,
      const Color(0xFFA855F7), const Color(0xFF6B4FA0), const Color(0xFF26A69A), const Color(0xFFFF6B2B),
    ];
    return [
      for (int i = 0; i < foods.length; i++)
        WheelOption(
          (foods[i]['id'] as String),
          (foods[i]['name_vi'] as String).length > 14
              ? (foods[i]['name_vi'] as String).substring(0, 13) + '…'
              : foods[i]['name_vi'] as String,
          colors[i % colors.length],
        ),
    ];
  }

  Future<HaResponse> _onVoiceTranscript(String transcript) async {
    // Naive intent: if transcript mentions mood, suggest. Otherwise generic suggest.
    final api = HnagApi();
    final t = transcript.toLowerCase();
    String mood = 'chill';
    if (t.contains('stress') || t.contains('mệt')) mood = 'stress';
    else if (t.contains('buồn') || t.contains('cô đơn')) mood = 'sad';
    else if (t.contains('vui')) mood = 'happy';
    else if (t.contains('khuya')) mood = 'late_night';
    else if (t.contains('vội')) mood = 'rushed';

    final result = await api.aiMoodSuggest(mood);
    final foods = result.foods;
    if (foods.isEmpty) {
      return const HaResponse(speech: 'Hà chưa tìm được món hợp lúc này. Thử lại nha.', emotion: 'warm');
    }
    final top = foods.first;
    final name = top['name_vi'] as String? ?? 'món';
    final price = top['avg_price_vnd'] as int? ?? 0;
    return HaResponse(
      speech: 'Hà gợi ý $name, ${(price/1000).round()}k. ${result.theme}',
      emotion: 'warm',
    );
  }

  @override
  Widget build(BuildContext context) {
    final decide = [
      ('🔍', 'Tìm món / quán', 'Search trên 60 món + 30 quán', () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SearchScreen(
          onSearch: (q) async => HnagApi().searchFoods(q),
          onResultTap: (f) async {
            final detail = await HnagApi().foodDetail(f['id'] as String) ?? f;
            if (!context.mounted) return;
            final ings = <({String name, String qty})>[];
            final ingJson = detail['ingredients'];
            if (ingJson is List) {
              for (final raw in ingJson) {
                if (raw is Map) {
                  ings.add((name: (raw['name'] ?? '').toString(), qty: (raw['qty'] ?? '').toString()));
                } else if (raw is String) ings.add((name: raw, qty: ''));
              }
            }
            final steps = <String>[];
            final rec = detail['recipe'];
            if (rec is List) for (final s in rec) if (s is String) steps.add(s);
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => FoodDetailScreen(
              food: FoodDetailData(
                id: detail['id'] as String,
                name: detail['name_vi'] as String? ?? '',
                image: detail['primary_image'] as String? ?? '',
                rating: double.tryParse('${detail['rating_avg']}') ?? 4.5,
                ratingCount: (detail['rating_count'] as int?) ?? 0,
                priceVnd: (detail['avg_price_vnd'] as int?) ?? 0,
                calories: (detail['avg_calories'] as int?) ?? 0,
                cookTimeMin: (detail['cook_time_min'] as int?) ?? 30,
                tags: [
                  ...((detail['flavor_tags'] as List?) ?? []).cast<String>().take(2),
                  ...((detail['mood_tags'] as List?) ?? []).cast<String>().take(2),
                ],
                description: detail['description'] as String?,
                ingredients: ings,
                steps: steps,
              ),
            )));
          },
        )))),
      ('📍', 'Quán gần đây', 'Quanh bạn 5km', () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const NearbyRestaurantsScreen()))),
      ('🔔', 'Thông báo', 'AI gợi ý + trending mới nhất', () async {
        final items = await _ProfileTab.buildNotifications();
        if (!context.mounted) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => NotificationsScreen(items: items, onMarkAllRead: () async {}),
        ));
      }),
      ('🎤', 'Trợ lý Hà (voice)', 'Hỏi bằng giọng tự nhiên', () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VoiceAssistantScreen(onTranscript: _onVoiceTranscript)))),
      ('💖', 'Chọn mood', 'AI gợi món theo cảm xúc', () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MoodSelectorScreen(onMoodPicked: (m) => _onMoodPicked(context, m))))),
      ('🎲', 'Quay random', 'Không quyết được? Quay!', () async {
        final options = await _loadRandomWheelOptions();
        if (!context.mounted) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => RandomWheelScreen(options: options, onResult: (_) {}),
        ));
      }),
    ];
    final cook = [
      ('🥗', 'Có gì trong tủ?', 'Nhập nguyên liệu → công thức từ kho 60+ món', () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => FridgeScanScreen(
          onScan: (_) async { throw UnimplementedError('Vision AI cho ảnh chưa bật. Hãy nhập tay.'); },
          onSuggestRecipes: (items) async {
            final api = HnagApi();
            final ings = items.map((e) => e.name).toList();
            final recipes = await api.aiFridgeRecipes(ings);
            return recipes.map((r) {
              final food = r['food'] as Map<String, dynamic>? ?? {};
              return FridgeRecipe(
                id: food['id'] as String? ?? '',
                name: food['name_vi'] as String? ?? '',
                timeMin: food['cook_time_min'] as int? ?? 30,
                uses: ((r['uses'] as List?) ?? []).cast<String>(),
                missing: ((r['missing'] as List?) ?? []).cast<String>(),
                tip: r['tip'] as String? ?? '',
              );
            }).toList();
          },
        )))),
      ('🍳', 'Live cooking', 'Nấu hands-free, voice control', () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const LiveCookingScreen(recipe: CookingRecipe(
          name: 'Trứng chiên cà chua',
          steps: [
            CookingStep(index: 0, title: 'Đập trứng', description: 'Đập 3 trứng vào tô, nêm chút nước mắm + tiêu, đánh tan.', durationMin: 2),
            CookingStep(index: 1, title: 'Xào cà chua', description: 'Phi thơm hành tím với dầu, cho cà chua thái múi cau xào mềm. Nêm chút đường + nước mắm.', durationMin: 5, timerSeconds: 300),
            CookingStep(index: 2, title: 'Đổ trứng', description: 'Đổ trứng vào, đảo nhanh tay đến khi trứng chín tới. Tắt bếp, rắc hành lá.', durationMin: 3),
          ],
        ))))),
      ('📅', 'Lịch ăn tuần', 'Plan 7 ngày + shopping list', () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const MealPlannerScreen()))),
    ];
    final social = [
      ('👥', 'Vote nhóm', 'Tạo poll realtime, bạn bè vote cùng', () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const GroupVoteLauncher()))),
      ('✨', 'HNAG+ Premium', 'Unlock unlimited AI + ẩn quảng cáo', () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PremiumScreen(onSubscribe: (planId) async {
          await HnagApi().startCheckout(planId, 'vietqr');
        })))),
    ];
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.x4),
        children: [
          const Text('Công cụ', style: AppTypography.displayLg),
          const SizedBox(height: AppSpacing.x4),
          _sectionLabel('Quyết định nhanh'),
          ...decide.map((t) => _ToolTile(icon: t.$1, title: t.$2, subtitle: t.$3, onTap: t.$4)),
          const SizedBox(height: AppSpacing.x4),
          _sectionLabel('Tự nấu'),
          ...cook.map((t) => _ToolTile(icon: t.$1, title: t.$2, subtitle: t.$3, onTap: t.$4)),
          const SizedBox(height: AppSpacing.x4),
          _sectionLabel('Cùng bạn bè'),
          ...social.map((t) => _ToolTile(icon: t.$1, title: t.$2, subtitle: t.$3, onTap: t.$4)),
        ],
      ),
    );
  }

  Widget _sectionLabel(String s) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Text(s.toUpperCase(),
            style: AppTypography.labelSm.copyWith(color: Colors.grey.shade600, letterSpacing: 0.8)),
      );
}

class _ProfileTab extends StatefulWidget {
  const _ProfileTab();

  static Future<List<HNotification>> buildNotifications() async {
    final api = HnagApi();
    final r = await api.aiMoodSuggest('happy');
    final t = await api.trendingFoods();
    final now = DateTime.now();
    final items = <HNotification>[];
    if (r.foods.isNotEmpty) {
      final top = r.foods.first;
      items.add(HNotification(
        id: 'ai-${top['id']}',
        type: 'ai_suggest',
        title: 'Hà gợi ý: ${top['name_vi']}',
        body: r.theme.isNotEmpty ? r.theme : 'Món hợp tâm trạng bạn lúc này',
        createdAt: now,
      ));
    }
    if (t.isNotEmpty) {
      final top = t.first;
      items.add(HNotification(
        id: 'trend-${top['id']}',
        type: 'social_like',
        title: '🔥 ${top['name_vi']} đang trending',
        body: 'Trending score ${top['trending_score']} — ${top['rating_count']} reviews',
        createdAt: now.subtract(const Duration(hours: 2)),
      ));
    }
    final streak = await api.myStreak();
    if (streak != null) {
      final dailyDecide = (streak['daily_decide'] as int?) ?? 0;
      if (dailyDecide > 0) {
        items.add(HNotification(
          id: 'streak-${dailyDecide}', type: 'streak',
          title: '🔥 Streak $dailyDecide ngày!',
          body: 'Bạn đã quyết định cùng Hà $dailyDecide ngày liên tiếp. Best: ${streak['best_decide'] ?? dailyDecide}',
          createdAt: now.subtract(const Duration(hours: 8)),
        ));
      }
    }
    return items;
  }

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  final _api = HnagApi();
  UserProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = await _api.me();
    final streak = await _api.myStreak();
    if (!mounted) return;
    if (me == null) { setState(() => _loading = false); return; }
    final u = me['user'] as Map<String, dynamic>?;
    if (u == null) { setState(() => _loading = false); return; }
    final reviewsCount = (me['reviewsCount'] as int?) ?? 0;
    final followers = (me['followers'] as int?) ?? 0;
    final following = (me['following'] as int?) ?? 0;
    final daily = (streak?['daily_decide'] as int?) ?? 0;
    setState(() {
      _profile = UserProfile(
        id: u['id'] as String,
        displayName: (u['display_name'] as String?) ?? (u['username'] as String?) ?? 'Bạn',
        username: (u['username'] as String?) ?? 'foodie',
        avatarUrl: u['avatar_url'] as String?,
        coverUrl: u['cover_url'] as String?,
        bio: u['bio'] as String?,
        level: ((u['level'] as int?) ?? 1).clamp(1, 99),
        foodieClass: (u['foodie_class'] as String?) ?? 'tep',
        reviews: reviewsCount,
        followers: followers,
        following: following,
        isPremium: (u['is_premium'] as bool?) ?? false,
        isVerified: (u['is_verified'] as bool?) ?? false,
      );
      _loading = false;
    });
    debugPrint('Streak loaded: daily_decide=$daily');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.phoOrange));
    }
    if (_profile == null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🍜', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 12),
          Text('Không tải được profile', style: AppTypography.headingSm),
          const SizedBox(height: 4),
          Text('Kiểm tra kết nối và thử lại', style: AppTypography.bodyMd.copyWith(color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: () { setState(() => _loading = true); _load(); }, child: const Text('Thử lại')),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () async { await AuthService.instance.signOut(); },
            child: const Text('Đăng xuất'),
          ),
        ]),
      ));
    }
    return ProfileScreen(
      isMe: true,
      profile: _profile!,
      onEdit: () {},
      onSettings: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettingsScreen(
        onSignOut: () async {
          await AuthService.instance.signOut();
          if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
        },
      ))),
    );
  }
}

class _ToolTile extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ToolTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppSpacing.x3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4, vertical: AppSpacing.x2),
        leading: CircleAvatar(
          backgroundColor: AppColors.phoOrange.withOpacity(0.12),
          child: Text(icon, style: const TextStyle(fontSize: 22)),
        ),
        title: Text(title, style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: AppTypography.caption),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
