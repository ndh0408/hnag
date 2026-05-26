// Search v2 — large title + searchbar + filter chips + AI natural-language
// search hero + trending list + recent chips.
// Mirrors design/m-home.jsx#Screen_Search.

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/theme.dart';
import '../../widgets/ds/ds.dart';

class SearchScreenV2 extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> Function(String query) onSearch;
  final ValueChanged<Map<String, dynamic>>? onResultTap;
  final VoidCallback? onVoice;
  const SearchScreenV2({super.key, required this.onSearch, this.onResultTap, this.onVoice});

  @override
  State<SearchScreenV2> createState() => _SearchScreenV2State();
}

class _SearchScreenV2State extends State<SearchScreenV2> {
  final _ctrl = TextEditingController();
  String _filter = 'Tất cả';
  List<Map<String, dynamic>>? _results;
  bool _searching = false;

  static const _filters = ['Tất cả', 'Món', 'Quán', 'Người', 'Recipe'];
  static const _trending = [
    ('lẩu thái', '+12%', '2.4k'),
    ('bún đậu mắm tôm', '+8%', '1.8k'),
    ('cơm tấm sườn cọng', '+5%', '1.5k'),
    ('phở khô Gia Lai', '+3%', '920'),
    ('bánh canh cua', '+2%', '780'),
  ];
  static const _recent = ['phở', 'bún chả', 'quán cô ba', 'salad cá hồi', 'bánh mì pate'];

  Future<void> _runSearch() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) { setState(() => _results = null); return; }
    setState(() => _searching = true);
    try {
      final r = await widget.onSearch(q);
      if (mounted) setState(() => _results = r);
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
      // AI search hero
      HnagCard(
        variant: CardVariant.gradient,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const HnagBadge(label: 'AI SEARCH', icon: 'sparkle', variant: BadgeVariant.glass),
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
              Padding(
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
                          Text(_trending[i].$1,
                            style: HnagType.label.copyWith(color: t.text, fontWeight: FontWeight.w500, fontFamily: HnagFonts.body),
                          ),
                          const SizedBox(height: 1),
                          Text('${_trending[i].$3} tìm',
                            style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                          ),
                        ],
                      ),
                    ),
                    HnagBadge(label: _trending[i].$2, icon: 'trend', variant: BadgeVariant.success),
                  ],
                ),
              ),
              if (i < _trending.length - 1) const HnagDivider(),
            ],
          ],
        ),
      ),
      const SizedBox(height: 22),
      Text('GẦN ĐÂY',
        style: HnagType.caps.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
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
    ];
  }
}

extension on int {
  R let<R>(R Function(int it) f) => f(this);
}
