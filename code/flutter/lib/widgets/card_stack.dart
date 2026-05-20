import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/food_card.dart';
import '../theme/app_theme.dart';
import 'mega_card.dart';

/// Swipeable Tinder-style stack of MegaCards.
///
/// Right swipe → save, Left swipe → skip, Up swipe → detail, Down swipe → later.
/// Includes ghost cards behind (z-depth scale), throw physics, and edge glow.
class CardStack extends StatefulWidget {
  final List<FoodCard> cards;
  final void Function(FoodCard card, SwipeAction action) onSwipe;
  final void Function(FoodCard card, String action)? onCtaTap;

  const CardStack({
    super.key,
    required this.cards,
    required this.onSwipe,
    this.onCtaTap,
  });

  @override
  State<CardStack> createState() => _CardStackState();
}

class _CardStackState extends State<CardStack> with TickerProviderStateMixin {
  late List<FoodCard> _cards;
  Offset _drag = Offset.zero;
  bool _animatingOut = false;
  AnimationController? _outCtrl;
  Animation<Offset>? _outAnim;
  SwipeAction _outAction = SwipeAction.skip;

  static const double _swipeThreshold = 120;

  @override
  void initState() {
    super.initState();
    _cards = List.of(widget.cards);
  }

  @override
  void didUpdateWidget(covariant CardStack old) {
    super.didUpdateWidget(old);
    // append new cards without disrupting current animation
    final fresh = widget.cards.where((c) => !_cards.any((o) => o.cardId == c.cardId)).toList();
    if (fresh.isNotEmpty) _cards.addAll(fresh);
  }

  @override
  void dispose() {
    _outCtrl?.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_animatingOut) return;
    setState(() => _drag += d.delta);
  }

  void _onDragEnd(DragEndDetails d) {
    if (_animatingOut) return;
    final velocity = d.velocity.pixelsPerSecond;

    // Detect direction
    SwipeAction? action;
    if (_drag.dx.abs() > _swipeThreshold || velocity.dx.abs() > 800) {
      action = _drag.dx > 0 ? SwipeAction.save : SwipeAction.skip;
    } else if (_drag.dy < -_swipeThreshold || velocity.dy < -800) {
      action = SwipeAction.openDetail;
    } else if (_drag.dy > _swipeThreshold || velocity.dy > 800) {
      action = SwipeAction.later;
    }

    if (action != null) {
      _throwOut(action, velocity);
    } else {
      // Snap back
      setState(() => _drag = Offset.zero);
    }
  }

  void _throwOut(SwipeAction action, Offset velocity) {
    if (_cards.isEmpty) return;
    HapticFeedback.mediumImpact();
    final size = MediaQuery.of(context).size;
    Offset target;
    switch (action) {
      case SwipeAction.skip:       target = Offset(-size.width * 1.5, _drag.dy + velocity.dy * 0.1); break;
      case SwipeAction.save:       target = Offset( size.width * 1.5, _drag.dy + velocity.dy * 0.1); break;
      case SwipeAction.openDetail: target = Offset(_drag.dx, -size.height); break;
      case SwipeAction.later:      target = Offset(_drag.dx,  size.height); break;
    }
    _outCtrl?.dispose();
    _outCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _outAnim = Tween(begin: _drag, end: target).animate(
      CurvedAnimation(parent: _outCtrl!, curve: Curves.easeOutCubic),
    );
    _outAction = action;
    _animatingOut = true;
    _outCtrl!.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        final c = _cards.removeAt(0);
        widget.onSwipe(c, _outAction);
        setState(() {
          _drag = Offset.zero;
          _animatingOut = false;
        });
      }
    });
    _outCtrl!.forward();
  }

  @override
  Widget build(BuildContext context) {
    if (_cards.isEmpty) return _emptyState();

    final visible = _cards.take(3).toList();
    return LayoutBuilder(
      builder: (ctx, constraints) {
        return Stack(
          alignment: Alignment.center,
          children: [
            _edgeGlow(),
            for (int i = visible.length - 1; i >= 0; i--) _buildOneCard(visible[i], i),
            _swipeHints(),
          ],
        );
      },
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🍽', style: TextStyle(fontSize: 64)),
            const SizedBox(height: AppSpacing.x3),
            Text('Hết gợi ý rồi nha',
                style: AppTypography.headingMd.copyWith(color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: AppSpacing.x2),
            Text('Kéo xuống để Hà roll lại',
                style: AppTypography.bodyMd.copyWith(color: Theme.of(context).hintColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildOneCard(FoodCard card, int index) {
    final isTop = index == 0;
    final scale = 1 - (index * 0.04);
    final yOffset = index * 12.0;

    Widget mega = MegaCard(
      card: card,
      active: isTop,
      onTap: () {/* open detail */},
      onSave: () => _throwOut(SwipeAction.save, Offset.zero),
      onSkip: () => _throwOut(SwipeAction.skip, Offset.zero),
      onActionTap: (a) => widget.onCtaTap?.call(card, a),
    );

    if (!isTop) {
      // Static behind cards
      return Transform.translate(
        offset: Offset(0, yOffset),
        child: Transform.scale(scale: scale, child: mega),
      );
    }

    // Top card — draggable + animating out
    Offset effectiveDrag = _drag;
    if (_animatingOut && _outAnim != null) effectiveDrag = _outAnim!.value;

    final rotation = (effectiveDrag.dx / 320).clamp(-0.32, 0.32);
    final dragNormX = (effectiveDrag.dx / 200).clamp(-1.0, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanUpdate: _onDragUpdate,
      onPanEnd: _onDragEnd,
      child: AnimatedBuilder(
        animation: _outCtrl ?? const AlwaysStoppedAnimation(0),
        builder: (_, __) {
          return Transform.translate(
            offset: effectiveDrag,
            child: Transform.rotate(
              angle: rotation,
              child: Stack(
                children: [
                  mega,
                  // Like / Skip stamps
                  if (dragNormX > 0.1) Positioned(top: 32, left: 24, child: _stamp('LƯU', AppColors.basil, 1 - dragNormX.abs())),
                  if (dragNormX < -0.1) Positioned(top: 32, right: 24, child: _stamp('SKIP', AppColors.danger, 1 - dragNormX.abs())),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _stamp(String text, Color color, double inverse) {
    final opacity = (1 - inverse).clamp(0.0, 1.0);
    return Opacity(
      opacity: opacity,
      child: Transform.rotate(
        angle: text == 'LƯU' ? -0.2 : 0.2,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 3),
            borderRadius: BorderRadius.circular(AppRadii.md),
            color: color.withOpacity(0.05),
          ),
          child: Text(
            text,
            style: AppTypography.headingMd.copyWith(color: color, fontWeight: FontWeight.w800, letterSpacing: 2),
          ),
        ),
      ),
    );
  }

  Widget _edgeGlow() {
    // Subtle glow at edges based on drag x
    final x = _drag.dx;
    if (x.abs() < 30) return const SizedBox.shrink();
    final isRight = x > 0;
    final intensity = math.min((x.abs() - 30) / 200, 0.7);
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: isRight ? Alignment.centerLeft : Alignment.centerRight,
              end: isRight ? Alignment.centerRight : Alignment.centerLeft,
              colors: [
                Colors.transparent,
                (isRight ? AppColors.basil : AppColors.danger).withOpacity(intensity * 0.18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _swipeHints() {
    return Positioned(
      bottom: 4, left: 0, right: 0,
      child: Center(
        child: Opacity(
          opacity: 0.7,
          child: Text('⬅ Skip   ⬆ Chi tiết   Save ➡',
              style: AppTypography.caption.copyWith(color: Colors.white)),
        ),
      ),
    );
  }
}
