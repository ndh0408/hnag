import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../theme/app_theme.dart';
import '../api/hnag_api.dart';
import '../api/auth_service.dart';
import '../widgets/live_cooking.dart';

class FoodDetailData {
  final String id;
  final String name;
  final String? description;
  final String image;
  final double rating;
  final int ratingCount;
  final int priceVnd;
  final int calories;
  final int cookTimeMin;
  final List<String> tags;
  final List<({String name, String qty})> ingredients;
  final List<String> steps;
  final String? videoUrl;
  const FoodDetailData({
    required this.id, required this.name, this.description, required this.image,
    required this.rating, required this.ratingCount, required this.priceVnd,
    required this.calories, required this.cookTimeMin, this.tags = const [],
    this.ingredients = const [], this.steps = const [], this.videoUrl,
  });
}

class FoodDetailScreen extends StatefulWidget {
  final FoodDetailData food;
  final VoidCallback? onCook;
  final VoidCallback? onOrder;
  final VoidCallback? onDine;
  final VoidCallback? onSave;
  const FoodDetailScreen({super.key, required this.food, this.onCook, this.onOrder, this.onDine, this.onSave});

  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen> {
  final _api = HnagApi();
  bool _saved = false;
  bool _saveBusy = false;
  bool _decided = false;
  bool _decideBusy = false;

  FoodDetailData get food => widget.food;

  @override
  void initState() {
    super.initState();
    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    if (!AuthService.instance.isAuthed) return;
    final saves = await _api.mySaves();
    if (!mounted) return;
    final isIn = saves.any((s) => (s['food'] as Map?)?['id'] == food.id);
    if (isIn != _saved) setState(() => _saved = isIn);
  }

  List<Map<String, dynamic>>? _restaurants;
  Future<void> _loadRestaurants() async {
    if (_restaurants != null) return;
    final r = await _api.restaurantsServing(food.id);
    if (mounted) setState(() => _restaurants = r);
  }

  Widget _restaurantsTab() {
    _loadRestaurants();
    if (_restaurants == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.phoOrange));
    }
    if (_restaurants!.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🏪', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text('Chưa có quán bán món này trong dữ liệu', textAlign: TextAlign.center,
              style: AppTypography.bodyMd.copyWith(color: Colors.grey.shade600)),
        ])));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.x4),
      itemCount: _restaurants!.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final r = _restaurants![i];
        final price = r['_menu_price_vnd'];
        final rating = double.tryParse('${r['rating_avg']}') ?? 0;
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: SizedBox(width: 52, height: 52,
              child: (r['cover_image'] as String?)?.isNotEmpty == true
                  ? CachedNetworkImage(imageUrl: r['cover_image'], fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: Colors.grey.shade200))
                  : Container(color: Colors.grey.shade200, child: const Icon(Icons.storefront))),
          ),
          title: Text(r['name'] as String? ?? '', style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600)),
          subtitle: Row(children: [
            const Icon(Icons.star_rounded, size: 14, color: AppColors.turmeric),
            Text(' ${rating.toStringAsFixed(1)}', style: AppTypography.caption),
            if ([r['district'], r['city']].any((x) => x != null)) ...[
              const SizedBox(width: 6),
              Flexible(child: Text('· ${[r['district'], r['city']].where((x) => x != null).join(', ')}',
                  style: AppTypography.caption.copyWith(color: Colors.grey.shade600), overflow: TextOverflow.ellipsis)),
            ],
          ]),
          trailing: price != null
              ? Text('${(((price as num).toInt()) / 1000).round()}k₫',
                  style: AppTypography.bodyMd.copyWith(color: AppColors.phoOrange, fontWeight: FontWeight.w700))
              : null,
        );
      },
    );
  }

  Future<void> _toggleSave() async {
    if (!AuthService.instance.isAuthed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đăng nhập để lưu món')));
      return;
    }
    setState(() => _saveBusy = true);
    try {
      final ok = _saved ? await _api.removeSave(food.id) : await _api.addSave(food.id);
      if (ok && mounted) setState(() => _saved = !_saved);
    } finally {
      if (mounted) setState(() => _saveBusy = false);
    }
    widget.onSave?.call();
  }

  Future<void> _confirmDecide() async {
    if (!AuthService.instance.isAuthed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đăng nhập để track streak')));
      return;
    }
    setState(() => _decideBusy = true);
    final result = await _api.bumpDecide();
    if (!mounted) return;
    setState(() {
      _decideBusy = false;
      _decided = true;
    });
    if (result != null) {
      final daily = (result['daily_decide'] as int?) ?? 1;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔥 Streak $daily ngày! ${food.name} — chúc ngon miệng'),
          backgroundColor: AppColors.phoOrange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DefaultTabController(
        length: 3,
        child: CustomScrollView(slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            actions: [
              IconButton(
                icon: _saveBusy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                    : Icon(_saved ? Icons.bookmark : Icons.bookmark_border, color: Colors.white),
                onPressed: _saveBusy ? null : _toggleSave,
              ),
              IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: () {}),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(fit: StackFit.expand, children: [
                CachedNetworkImage(imageUrl: food.image, fit: BoxFit.cover),
                Container(decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
                ))),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.x4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.photo_camera_outlined, size: 12, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text('Nguồn ảnh: Wikimedia Commons',
                      style: AppTypography.caption.copyWith(color: Colors.grey.shade500, fontSize: 11)),
                ]),
                const SizedBox(height: 8),
                Text(food.name, style: AppTypography.displayLg),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.star_rounded, color: AppColors.turmeric),
                  Text(' ${food.rating.toStringAsFixed(1)} (${food.ratingCount}) · ',
                      style: AppTypography.bodyMd),
                  Text('${(food.priceVnd / 1000).round()}k₫ · ${food.calories} cal · ${food.cookTimeMin}p',
                      style: AppTypography.bodyMd.copyWith(color: Colors.grey.shade700)),
                ]),
                const SizedBox(height: 12),
                Wrap(spacing: 6, runSpacing: 6, children: food.tags.map((t) => Chip(
                  label: Text('#$t'),
                  labelStyle: AppTypography.caption,
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                  backgroundColor: AppColors.phoOrange.withOpacity(0.1),
                )).toList()),
                if (food.description != null) ...[
                  const SizedBox(height: 16),
                  Text(food.description!, style: AppTypography.bodyMd.copyWith(height: 1.5)),
                ],
              ]),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SDelegate(
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: const TabBar(
                  labelColor: AppColors.phoOrange,
                  indicatorColor: AppColors.phoOrange,
                  tabs: [Tab(text: 'Công thức'), Tab(text: 'Quán bán'), Tab(text: 'Bài viết')],
                ),
              ),
            ),
          ),
          SliverFillRemaining(
            child: Column(children: [
              Expanded(child: TabBarView(children: [
                _recipe(),
                _restaurantsTab(),
                Center(child: Padding(padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('📝', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 8),
                    Text('Chưa có bài viết về món này', style: AppTypography.bodyMd.copyWith(color: Colors.grey.shade600)),
                  ]))),
              ])),
              _cta(),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _recipe() {
    final hasIng = food.ingredients.isNotEmpty;
    final hasSteps = food.steps.isNotEmpty;
    if (!hasIng && !hasSteps) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🥢', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('Công thức chi tiết sắp có', style: AppTypography.headingSm),
          const SizedBox(height: 4),
          Text('Hà đang biên soạn cách nấu món này. Trong khi đó bạn có thể đặt giao hoặc tìm quán gần.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd.copyWith(color: Colors.grey.shade600)),
        ]),
      ));
    }
    return ListView(padding: const EdgeInsets.all(AppSpacing.x4), children: [
      if (hasIng) ...[
        Text('Nguyên liệu', style: AppTypography.headingSm),
        const SizedBox(height: 8),
        ...food.ingredients.map((i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            const Icon(Icons.fiber_manual_record, size: 8, color: AppColors.phoOrange),
            const SizedBox(width: 10),
            Expanded(child: Text(i.name)),
            Text(i.qty, style: AppTypography.caption.copyWith(color: Colors.grey.shade600)),
          ]),
        )),
        const SizedBox(height: 24),
      ],
      if (hasSteps) ...[
        Text('Cách làm', style: AppTypography.headingSm),
        const SizedBox(height: 8),
        ...food.steps.asMap().entries.map((e) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
              radius: 14, backgroundColor: AppColors.phoOrange,
              child: Text('${e.key + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(e.value, style: AppTypography.bodyMd.copyWith(height: 1.5))),
          ]),
        )),
      ],
    ]);
  }

  Widget _cta() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.x4),
        decoration: BoxDecoration(color: Colors.white, boxShadow: AppShadows.md),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Primary action: confirm decision (drives streak)
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            icon: _decideBusy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                : Icon(_decided ? Icons.check_circle : Icons.restaurant_rounded),
            label: Text(_decided ? 'Đã chọn món này' : 'Hôm nay ăn món này'),
            onPressed: (_decideBusy || _decided) ? null : _confirmDecide,
            style: ElevatedButton.styleFrom(
              backgroundColor: _decided ? AppColors.basil : AppColors.phoOrange,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.full)),
            ),
          )),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              icon: const Icon(Icons.local_fire_department, size: 18),
              label: const Text('Nấu'),
              onPressed: widget.onCook ?? (food.steps.isEmpty ? null : () => _openLiveCooking()),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.full))),
            )),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(
              icon: const Icon(Icons.delivery_dining_rounded, size: 18),
              label: const Text('Đặt giao'),
              onPressed: widget.onOrder ?? () => _showOrderSheet(),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.full))),
            )),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(
              icon: const Icon(Icons.directions_walk_rounded, size: 18),
              label: const Text('Đi ăn'),
              onPressed: widget.onDine,
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.full))),
            )),
          ]),
        ]),
      ),
    );
  }

  void _showOrderSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Đặt ${food.name} qua', style: AppTypography.headingSm),
            const SizedBox(height: 16),
            _deliveryOption('🟢', 'GrabFood', 'https://food.grab.com/vn/vi/restaurants?query=${Uri.encodeComponent(food.name)}'),
            _deliveryOption('🟠', 'ShopeeFood', 'https://shopeefood.vn/tim-kiem?content=${Uri.encodeComponent(food.name)}'),
            _deliveryOption('🗺️', 'Tìm trên Google Maps', 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(food.name)}'),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  void _openLiveCooking() {
    final steps = <CookingStep>[];
    for (var i = 0; i < food.steps.length; i++) {
      final text = food.steps[i];
      // Heuristic: extract first 4-5 words as title
      final words = text.split(' ');
      final title = words.take(words.length > 6 ? 5 : words.length).join(' ').replaceAll('.', '');
      // Estimate duration from text — divide cook_time_min equally
      final dur = (food.cookTimeMin / food.steps.length).round().clamp(1, 30);
      steps.add(CookingStep(
        index: i,
        title: title,
        description: text,
        durationMin: dur,
        timerSeconds: text.toLowerCase().contains('phút') ? dur * 60 : null,
      ));
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LiveCookingScreen(recipe: CookingRecipe(name: food.name, steps: steps)),
    ));
  }

  Widget _deliveryOption(String emoji, String name, String url) {
    return ListTile(
      leading: Text(emoji, style: const TextStyle(fontSize: 28)),
      title: Text(name, style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.open_in_new_rounded, color: AppColors.phoOrange),
      onTap: () async {
        Navigator.pop(context);
        // Launch the https universal link (carries the search query) — opens the
        // app to the right search results if installed, else the website.
        await launchUrlString(url, mode: LaunchMode.externalApplication);
      },
    );
  }
}

class _SDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _SDelegate({required this.child});
  @override double get minExtent => 48;
  @override double get maxExtent => 48;
  @override Widget build(_, __, ___) => child;
  @override bool shouldRebuild(covariant _) => false;
}
