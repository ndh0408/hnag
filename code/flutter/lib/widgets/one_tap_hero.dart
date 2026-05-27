// One-tap "Hôm Nay Ăn Gì?" hero widget.
//
// Audit production-killer §"hero": consumer apps win on ONE moment that
// is impossibly easy. For HNAG that moment is — literally — "Hôm nay ăn
// gì?" → tap → answer. Everything else (cart, profile, social, claim)
// is secondary scaffolding.
//
// This widget sits at the top of Home v2. Single button, one tap, three
// states:
//   1. idle   — pulsing gradient with the hero text
//   2. think  — orange dot animation while /v1/ai/suggest is in flight
//   3. result — single-card answer + "Đặt giao" / "Đổi món" / "Đến quán"
//
// Why not a screen: a screen costs a navigator push + back gesture. The
// hero answers in-place, the user can keep tapping without leaving Home.
//
// Backend contract: calls existing AiOrchestratorService.suggest() with
// mode='quick' limit=1. Same response shape as the regular suggest;
// `degraded` field (B10) is honoured — "Hà đang nghỉ trưa" copy when
// the LLM path failed.

import 'package:flutter/material.dart';

import '../api/hnag_api.dart';
import '../design/hnag_feedback.dart';
import '../design/tokens.dart';
import '../observability/analytics.dart';
import '../widgets/ds/ds.dart';

typedef HeroPick = ({
  String foodId,
  String title,
  String? imageUrl,
  int priceVnd,
  String reason,
  bool degraded,
});

class OneTapHero extends StatefulWidget {
  /// Tapped on a result card → caller usually opens FoodDetailScreen.
  final void Function(HeroPick pick) onTapResult;
  const OneTapHero({super.key, required this.onTapResult});

  @override
  State<OneTapHero> createState() => _OneTapHeroState();
}

class _OneTapHeroState extends State<OneTapHero> {
  HeroPick? _pick;
  bool _busy = false;
  String? _error;

  Future<void> _decideForMe() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    HnagFeedback.tapMedium();
    Analytics.track('home:one_tap_pressed', {'has_previous': _pick != null});
    try {
      final result = await HnagApi().aiSuggest(limit: 1);
      if (!mounted) return;
      if (result.isEmpty) {
        setState(() => _error = 'Hà chưa tìm được món phù hợp lúc này');
        Analytics.track('home:one_tap_empty');
        return;
      }
      final first = result.first;
      final pick = (
        foodId: (first['foodId'] as String?) ?? (first['id'] as String? ?? ''),
        title: (first['title'] as String?) ?? (first['name_vi'] as String? ?? 'Món'),
        imageUrl: (first['media'] as Map?)?['imageUrl'] as String?
            ?? first['primary_image'] as String?,
        priceVnd: (first['price'] is num ? (first['price'] as num).toInt() : 0),
        reason: (first['aiReason'] as String?) ?? '',
        degraded: (first['degraded'] as bool?) ?? false,
      );
      setState(() => _pick = pick);
      Analytics.track('home:one_tap_answered', {
        'foodId': pick.foodId,
        'degraded': pick.degraded,
      });
      HnagFeedback.success();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      Analytics.track('home:one_tap_failed', {'error': e.toString().substring(0, 80.clamp(0, e.toString().length))});
      HnagFeedback.error();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return AnimatedSwitcher(
      duration: HnagMotion.medium,
      switchInCurve: HnagCurves.standard,
      switchOutCurve: HnagCurves.exit,
      child: _pick == null ? _idle(t) : _result(t, _pick!),
    );
  }

  Widget _idle(SemanticTokens t) => GestureDetector(
        key: const ValueKey('idle'),
        onTap: _decideForMe,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [t.brand, t.brandAlt ?? t.brand.withOpacity(0.85)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(HnagRadius.xl),
            boxShadow: [
              BoxShadow(
                color: t.brand.withOpacity(0.35),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hôm nay ăn gì?',
                      style: HnagType.h2.copyWith(
                        color: Colors.white,
                        fontFamily: HnagFonts.display,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _busy ? 'Hà đang nghĩ…' : (_error ?? 'Tap để Hà chọn cho bạn'),
                      style: HnagType.body.copyWith(
                        color: Colors.white.withOpacity(0.85),
                        fontFamily: HnagFonts.body,
                      ),
                    ),
                  ],
                ),
              ),
              _busy
                  ? const SizedBox(
                      width: 36, height: 36,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Icon(Icons.auto_awesome, color: t.brand, size: 22),
                    ),
            ],
          ),
        ),
      );

  Widget _result(SemanticTokens t, HeroPick pick) {
    final priceStr = pick.priceVnd > 0
        ? '${(pick.priceVnd / 1000).toStringAsFixed(0)}k'
        : '';
    return Container(
      key: ValueKey('result-${pick.foodId}'),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.bgRaised,
        borderRadius: BorderRadius.circular(HnagRadius.xl),
        border: Border.all(color: t.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              HnagFeedback.tap();
              widget.onTapResult(pick);
              Analytics.track('home:one_tap_card_tap', {'foodId': pick.foodId});
            },
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(HnagRadius.md),
                  child: HnagPhoto(
                    width: 96, height: 96,
                    imageUrl: pick.imageUrl,
                    foodSlug: pick.title,
                    radius: HnagRadius.md,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pick.degraded ? 'Hà gợi ý nhanh' : 'Hà đã chọn',
                        style: HnagType.bodySm.copyWith(
                          color: pick.degraded ? t.warning : t.brand,
                          fontWeight: FontWeight.w700,
                          fontFamily: HnagFonts.body,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pick.title,
                        style: HnagType.h3.copyWith(
                          color: t.text,
                          fontFamily: HnagFonts.display,
                          height: 1.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (priceStr.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          priceStr,
                          style: HnagType.bodySm.copyWith(
                            color: t.textMuted,
                            fontFamily: HnagFonts.body,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (pick.reason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '"${pick.reason}"',
              style: HnagType.bodySm.copyWith(
                color: t.textMuted,
                fontFamily: HnagFonts.body,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: HnagButton(
                  label: 'Đổi món',
                  iconLeading: 'refresh',
                  variant: BtnVariant.outline,
                  size: BtnSize.md,
                  onPressed: _busy ? null : _decideForMe,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: HnagButton(
                  label: 'Đi tới món',
                  iconTrailing: 'arrowR',
                  variant: BtnVariant.gradient,
                  size: BtnSize.md,
                  onPressed: () {
                    HnagFeedback.tap();
                    widget.onTapResult(pick);
                    Analytics.track('home:one_tap_card_tap', {'foodId': pick.foodId});
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
