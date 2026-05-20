import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../api/hnag_api.dart';

/// Shown after user picks a mood — fetches mood-matched foods from backend.
class MoodResultScreen extends StatefulWidget {
  final String mood;
  final String moodLabel;
  final Color moodColor;
  const MoodResultScreen({super.key, required this.mood, required this.moodLabel, required this.moodColor});

  @override
  State<MoodResultScreen> createState() => _MoodResultScreenState();
}

class _MoodResultScreenState extends State<MoodResultScreen> {
  final _api = HnagApi();
  String _theme = '';
  List<Map<String, dynamic>> _foods = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await _api.aiMoodSuggest(widget.mood);
    setState(() {
      _theme = result.theme;
      _foods = result.foods;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [widget.moodColor, widget.moodColor.withOpacity(0.5), AppColors.bgLight],
            stops: const [0.0, 0.35, 0.5],
          ),
        ),
        child: SafeArea(
          child: Column(children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(AppSpacing.x3),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _load),
              ]),
            ),
            const SizedBox(height: 8),
            Text('Mood: ${widget.moodLabel}',
                style: AppTypography.headingSm.copyWith(color: Colors.white.withOpacity(0.9))),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _theme.isNotEmpty ? _theme : 'Hà gợi ý...',
                textAlign: TextAlign.center,
                style: AppTypography.displayLg.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: AppSpacing.x5),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.phoOrange))
                    : _foods.isEmpty
                        ? Center(child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.x6),
                            child: Text('Hà chưa tìm được món hợp mood "${widget.moodLabel}". Thử mood khác nhé.',
                                textAlign: TextAlign.center,
                                style: AppTypography.bodyLg.copyWith(color: Colors.grey.shade600)),
                          ))
                        : ListView.separated(
                            padding: const EdgeInsets.all(AppSpacing.x4),
                            itemCount: _foods.length,
                            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x3),
                            itemBuilder: (_, i) => _foodCard(_foods[i]),
                          ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _foodCard(Map<String, dynamic> f) {
    final img = (f['primary_image'] as String?) ?? '';
    final name = (f['name_vi'] as String?) ?? '';
    final price = (f['avg_price_vnd'] as int?) ?? 0;
    final cal = (f['avg_calories'] as int?) ?? 0;
    final reason = (f['_ai_reason'] as String?) ?? '';
    final rating = double.tryParse('${f['rating_avg']}') ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.sm,
      ),
      child: Row(children: [
        ClipRRect(
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(AppRadii.lg)),
          child: SizedBox(
            width: 100, height: 100,
            child: img.isNotEmpty
                ? CachedNetworkImage(imageUrl: img, fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(color: Colors.grey.shade200))
                : Container(color: Colors.grey.shade200, child: const Icon(Icons.restaurant)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: AppTypography.headingSm, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.star_rounded, size: 14, color: AppColors.turmeric),
              const SizedBox(width: 2),
              Text(rating.toStringAsFixed(1), style: AppTypography.caption),
              const SizedBox(width: 6),
              Text('${(price / 1000).round()}k₫', style: AppTypography.caption.copyWith(color: AppColors.phoOrange, fontWeight: FontWeight.w700)),
              if (cal > 0) ...[
                const SizedBox(width: 6),
                Text('$cal cal', style: AppTypography.caption.copyWith(color: Colors.grey.shade600)),
              ],
            ]),
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('✨ $reason',
                  style: AppTypography.caption.copyWith(color: AppColors.phoOrange, fontStyle: FontStyle.italic),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ]),
        )),
        const Padding(
          padding: EdgeInsets.only(right: 8),
          child: Icon(Icons.chevron_right_rounded, color: Colors.grey),
        ),
      ]),
    );
  }
}
