import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';

class SearchScreen extends StatefulWidget {
  final Future<List<dynamic>> Function(String query) onSearch;
  final void Function(Map<String, dynamic> food)? onResultTap;
  final VoidCallback? onVoiceSearch;
  final VoidCallback? onVisualSearch;
  const SearchScreen({super.key, required this.onSearch, this.onResultTap, this.onVoiceSearch, this.onVisualSearch});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<dynamic>? _results;
  bool _busy = false;

  final List<String> _aiSuggestions = const [
    'phở bò ngon dưới 60k',
    'quán date sang chảnh',
    'ăn healthy không quá 500 cal',
    'lẩu nhóm dưới 200k/người',
  ];

  final List<({String emoji, String name})> _categories = const [
    (emoji: '🍜', name: 'Phở'),
    (emoji: '🍚', name: 'Cơm'),
    (emoji: '🥢', name: 'Bún'),
    (emoji: '🍢', name: 'Nướng'),
    (emoji: '☕', name: 'Cafe'),
    (emoji: '🍰', name: 'Dessert'),
    (emoji: '🥤', name: 'Đồ uống'),
    (emoji: '🍔', name: 'Fast food'),
  ];

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () => _doSearch(q));
  }

  Future<void> _doSearch(String q) async {
    if (q.trim().isEmpty) { setState(() => _results = null); return; }
    setState(() => _busy = true);
    try {
      _results = await widget.onSearch(q);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() { _debounce?.cancel(); _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Tìm món, quán, người...',
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
        ),
        actions: [
          IconButton(icon: const Icon(Icons.mic_rounded), onPressed: widget.onVoiceSearch),
          IconButton(icon: const Icon(Icons.camera_alt_outlined), onPressed: widget.onVisualSearch),
        ],
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator(color: AppColors.phoOrange))
          : _results == null ? _empty() : _resultsList(),
    );
  }

  Widget _empty() => ListView(padding: const EdgeInsets.all(AppSpacing.x4), children: [
        _sectionTitle('Đề xuất Hà'),
        ..._aiSuggestions.map((s) => ListTile(
              leading: const Icon(Icons.auto_awesome, color: AppColors.phoOrange),
              title: Text(s),
              onTap: () { _ctrl.text = s; _doSearch(s); },
            )),
        const SizedBox(height: 16),
        _sectionTitle('Danh mục'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: _categories.map((c) => ActionChip(
          avatar: Text(c.emoji),
          label: Text(c.name),
          onPressed: () { _ctrl.text = c.name; _doSearch(c.name); },
        )).toList()),
        const SizedBox(height: 24),
        _sectionTitle('Trending tuần này'),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.4, crossAxisSpacing: 8, mainAxisSpacing: 8),
          itemCount: 4,
          itemBuilder: (_, i) => ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: Image.network('https://picsum.photos/seed/t$i/400/250', fit: BoxFit.cover),
          ),
        ),
      ]);

  Widget _sectionTitle(String s) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(s, style: AppTypography.headingSm),
      );

  Widget _resultsList() {
    if (_results!.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🤔', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          Text('Hà chưa tìm thấy gì hợp', style: AppTypography.headingSm),
          const SizedBox(height: 4),
          Text('Thử từ khoá khác nhé', style: AppTypography.bodyMd.copyWith(color: Colors.grey.shade600)),
        ]),
      ));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results!.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final raw = _results![i];
        if (raw is! Map) return const SizedBox.shrink();
        final f = raw.cast<String, dynamic>();
        final name = (f['name_vi'] as String?) ?? '';
        final img = (f['primary_image'] as String?) ?? '';
        final price = (f['avg_price_vnd'] as int?) ?? 0;
        final rating = double.tryParse('${f['rating_avg']}') ?? 0;
        final cat = (f['category'] as String?) ?? '';
        return ListTile(
          onTap: widget.onResultTap == null ? null : () => widget.onResultTap!(f),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: SizedBox(
              width: 56, height: 56,
              child: img.isNotEmpty
                  ? CachedNetworkImage(imageUrl: img, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: Colors.grey.shade200))
                  : Container(color: Colors.grey.shade200, child: const Icon(Icons.restaurant)),
            ),
          ),
          title: Text(name, style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600)),
          subtitle: Row(children: [
            const Icon(Icons.star_rounded, size: 14, color: AppColors.turmeric),
            Text(' ${rating.toStringAsFixed(1)} · ', style: AppTypography.caption),
            Text('${(price / 1000).round()}k₫', style: AppTypography.caption.copyWith(color: AppColors.phoOrange, fontWeight: FontWeight.w700)),
            if (cat.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text('· $cat', style: AppTypography.caption.copyWith(color: Colors.grey.shade600)),
            ],
          ]),
          trailing: const Icon(Icons.chevron_right_rounded),
        );
      },
    );
  }
}
