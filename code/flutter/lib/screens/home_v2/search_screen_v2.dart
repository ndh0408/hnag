// Search v2 — large title + searchbar + filter chips + AI natural-language
// search hero + trending list + recent chips.
// Mirrors design/m-home.jsx#Screen_Search.

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

import '../../design/tokens.dart';
import '../../design/theme.dart';
import '../../widgets/ds/ds.dart';

class SearchScreenV2 extends StatefulWidget {
  /// Free-text search.
  final Future<List<Map<String, dynamic>>> Function(String query) onSearch;
  /// Pull trending search terms from backend (top 5 most-searched).
  final Future<List<Map<String, dynamic>>> Function()? onLoadTrending;
  final ValueChanged<Map<String, dynamic>>? onResultTap;
  final VoidCallback? onVoice;
  const SearchScreenV2({super.key, required this.onSearch, this.onLoadTrending, this.onResultTap, this.onVoice});

  @override
  State<SearchScreenV2> createState() => _SearchScreenV2State();
}

class _SearchScreenV2State extends State<SearchScreenV2> {
  final _ctrl = TextEditingController();
  final _storage = const FlutterSecureStorage();
  static const _recentKey = 'hnag.search.recent';

  String _filter = 'Tất cả';
  List<Map<String, dynamic>>? _results;
  bool _searching = false;
  List<({String name, String trend, String count})> _trending = [];
  List<String> _recent = [];

  static const _filters = ['Tất cả', 'Món', 'Quán', 'Người', 'Recipe'];

  @override
  void initState() {
    super.initState();
    _loadRecent();
    _loadTrending();
  }

  Future<void> _loadRecent() async {
    try {
      final raw = await _storage.read(key: _recentKey);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List).cast<String>();
      if (mounted) setState(() => _recent = list.take(8).toList());
    } catch (_) {}
  }

  Future<void> _saveRecent(String q) async {
    if (q.trim().isEmpty) return;
    final next = [q, ..._recent.where((r) => r != q)].take(10).toList();
    setState(() => _recent = next);
    try { await _storage.write(key: _recentKey, value: jsonEncode(next)); } catch (_) {}
  }

  Future<void> _clearRecent() async {
    setState(() => _recent = []);
    try { await _storage.delete(key: _recentKey); } catch (_) {}
  }

  Future<void> _loadTrending() async {
    if (widget.onLoadTrending == null) return;
    try {
      final items = await widget.onLoadTrending!();
      if (!mounted) return;
      // Backend returns foods with `trending_score`, `rating_count`.
      setState(() => _trending = items.take(5).map((f) {
        final score = (f['trending_score'] as num?) ?? 0;
        final count = (f['rating_count'] as int?) ?? 0;
        return (
          name: ((f['name_vi'] as String?) ?? '').toLowerCase(),
          trend: '+${score.toStringAsFixed(0)}%',
          count: count >= 1000 ? '${(count / 1000).toStringAsFixed(1)}k' : '$count',
        );
      }).toList());
    } catch (_) {}
  }

  Future<void> _runSearch() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) { setState(() => _results = null); return; }
    setState(() => _searching = true);
    try {
      final r = await widget.onSearch(q);
      if (mounted) setState(() => _results = r);
      _saveRecent(q);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return HnagThemeScope(
      dark: false,
      child: Builder(builder: (context) {
        final t = context.hnag;
        return Scaffold(
          backgroundColor: t.bg,
          body: SafeArea(
            child: Column(
              children: [
                HnagAppBar(title: 'Khám phá', large: true, transparent: true),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: HnagInput(
                    controller: _ctrl,
                    leading: 'search',
                    placeholder: 'Tìm món, quán...',
                    onChanged: (_) => _runSearch(),
                    onSubmitted: (_) => _runSearch(),
                    trailing: GestureDetector(
                      onTap: widget.onVoice,
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(color: t.brandSoft, shape: BoxShape.circle),
                        child: Center(child: HnagIcon('mic', size: 14, color: t.brand)),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 52,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    itemCount: _filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => HnagChip(
                      label: _filters[i],
                      active: _filter == _filters[i],
                      onTap: () => setState(() => _filter = _filters[i]),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    children: [
                      if (_results != null) ..._buildResults(t)
                      else ..._buildSuggestions(t),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  List<Widget> _buildResults(SemanticTokens t) {
    if (_searching) {
      return [
        Padding(
          padding: const EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator(color: t.brand)),
        ),
      ];
    }
    final results = _results ?? [];
    if (results.isEmpty) {
      return [
        const SizedBox(height: 40),
        Center(
          child: Column(
            children: [
              Text('🥹', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 12),
              Text('Không có kết quả',
                style: HnagType.h3.copyWith(color: t.text, fontFamily: HnagFonts.display),
              ),
              const SizedBox(height: 4),
              Text('Thử từ khoá khác xem nhé',
                style: HnagType.body.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
              ),
            ],
          ),
        ),
      ];
    }
    return results.map((r) => HnagListItem(
      title: (r['name_vi'] as String?) ?? '',
      subtitle: (r['avg_price_vnd'] as int?)?.let((p) => '${(p / 1000).round()}k') ?? '',
      onTap: () => widget.onResultTap?.call(r),
      trailing: HnagIcon('chevR', size: 18, color: t.textMuted),
    )).toList();
  }

  List<Widget> _buildSuggestions(SemanticTokens t) {
    return [
      // AI search hero — taps to voice screen if voice handler exists
      GestureDetector(
        onTap: widget.onVoice,
        child: HnagCard(
          variant: CardVariant.gradient,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  HnagBadge(label: 'AI SEARCH', icon: 'sparkle', variant: BadgeVariant.glass),
                  Spacer(),
                  HnagBadge(label: 'Hỏi Hà bằng giọng', icon: 'mic', variant: BadgeVariant.glass),
                ],
              ),
              const SizedBox(height: 10),
              Text('Hỏi bằng câu tự nhiên',
                style: HnagType.h3.copyWith(color: Colors.white, fontFamily: HnagFonts.display),
              ),
              const SizedBox(height: 4),
              Text(
                '"Món rẻ healthy cho buổi trưa" · "Lẩu cay ≤ 150k cho 3 người"',
                style: HnagType.bodySm.copyWith(
                  color: Colors.white.withOpacity(0.85),
                  fontStyle: FontStyle.italic,
                  fontFamily: HnagFonts.body,
                ),
              ),
            ],
          ),
        ),
      ),
      if (_trending.isNotEmpty) ...[
        const SizedBox(height: 22),
        Text('🔥 ĐANG TÌM NHIỀU',
          style: HnagType.caps.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
        ),
        const SizedBox(height: 12),
        HnagCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < _trending.length; i++) ...[
                Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: () { _ctrl.text = _trending[i].name; _runSearch(); },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text('${i + 1}',
                              textAlign: TextAlign.center,
                              style: HnagType.h4.copyWith(color: t.textFaint, fontFamily: HnagFonts.display),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_trending[i].name,
                                  style: HnagType.label.copyWith(color: t.text, fontWeight: FontWeight.w500, fontFamily: HnagFonts.body),
                                ),
                                const SizedBox(height: 1),
                                Text('${_trending[i].count} tìm',
                                  style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                                ),
                              ],
                            ),
                          ),
                          HnagBadge(label: _trending[i].trend, icon: 'trend', variant: BadgeVariant.success),
                        ],
                      ),
                    ),
                  ),
                ),
                if (i < _trending.length - 1) const HnagDivider(),
              ],
            ],
          ),
        ),
      ],
      if (_recent.isNotEmpty) ...[
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: Text('GẦN ĐÂY',
                style: HnagType.caps.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
              ),
            ),
            GestureDetector(
              onTap: _clearRecent,
              child: Text('Xoá',
                style: HnagType.labelSm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: [
            for (final r in _recent)
              HnagChip(label: r, icon: 'refresh', onTap: () {
                _ctrl.text = r;
                _runSearch();
              }),
          ],
        ),
      ],
    ];
  }
}

extension on int {
  R let<R>(R Function(int it) f) => f(this);
}
