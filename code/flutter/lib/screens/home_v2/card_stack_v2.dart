// CardStack v2 — Tinder-style food card stack with 5-button action row.
// Mirrors design/m-home.jsx#Screen_CardStack.

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/gradients.dart';
import '../../design/theme.dart';
import '../../widgets/ds/ds.dart';
import 'food_card_large.dart';

enum CardSwipe { skip, save, detail, later, reroll }

class CardStackV2 extends StatefulWidget {
  final List<FoodCardLargeData> cards;
  final void Function(FoodCardLargeData card, CardSwipe action) onAction;
  final VoidCallback? onClose;
  final VoidCallback? onSettings;
  /// Fired when the user runs out of cards and taps the empty-state refresh.
  /// Parent should fetch a fresh batch of suggestions.
  final VoidCallback? onRefreshStack;
  const CardStackV2({
    super.key,
    required this.cards,
    required this.onAction,
    this.onClose,
    this.onSettings,
    this.onRefreshStack,
  });

  @override
  State<CardStackV2> createState() => _CardStackV2State();
}

class _CardStackV2State extends State<CardStackV2> with SingleTickerProviderStateMixin {
  int _index = 0;
  Offset _drag = Offset.zero;
  bool _animatingOut = false;
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _commit(CardSwipe a) {
    if (_animatingOut || _index >= widget.cards.length) return;
    setState(() {
      _animatingOut = true;
      _drag = switch (a) {
        CardSwipe.skip   => const Offset(-1.5, 0.1),
        CardSwipe.save   => const Offset(1.5, 0.1),
        CardSwipe.detail => const Offset(0, -1.5),
        CardSwipe.later  => const Offset(0, 1.2),
        CardSwipe.reroll => const Offset(0, 0),
      };
    });
    final card = widget.cards[_index];
    widget.onAction(card, a);
    Future.delayed(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() {
        _index = (_index + 1).clamp(0, widget.cards.length);
        _drag = Offset.zero;
        _animatingOut = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return HnagThemeScope(
      dark: false,
      child: Builder(builder: (context) {
        final t = context.hnag;
        final hasMore = _index < widget.cards.length;
        return Scaffold(
          backgroundColor: t.bg,
          body: SafeArea(
            child: Column(
              children: [
                HnagAppBar(
                  transparent: true,
                  title: '',
                  leading: HnagIconButton(icon: 'x', variant: IconBtnVariant.soft, onPressed: widget.onClose ?? () => Navigator.maybePop(context)),
                  actions: [
                    HnagIconButton(icon: 'settings', variant: IconBtnVariant.soft, onPressed: widget.onSettings),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(widget.cards.length.clamp(1, 7), (i) {
                      final active = i == _index.clamp(0, widget.cards.length - 1);
                      return AnimatedContainer(
                        duration: HnagMotion.fast,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: active ? 24 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i <= _index ? t.brand : t.bgMuted,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    hasMore
                        ? 'Món ${_index + 1} / ${widget.cards.length} · vuốt để duyệt'
                        : 'Đã xem hết — refresh để Hà chọn mới',
                    style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                  ),
                ),

                Expanded(
                  child: hasMore ? _buildStack(t) : _buildEmpty(t),
                ),

                if (hasMore) _buildActionRow(),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStack(SemanticTokens t) {
    return GestureDetector(
      onPanUpdate: _animatingOut ? null : (d) {
        setState(() => _drag += Offset(d.delta.dx, d.delta.dy) / 300);
      },
      onPanEnd: _animatingOut ? null : (d) {
        if (_drag.dx < -0.4) {
          _commit(CardSwipe.skip);
        } else if (_drag.dx > 0.4) {
          _commit(CardSwipe.save);
        } else if (_drag.dy < -0.3) {
          _commit(CardSwipe.detail);
        } else if (_drag.dy > 0.3) {
          _commit(CardSwipe.later);
        } else {
          setState(() => _drag = Offset.zero);
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background cards (the next 2)
            for (var i = 2; i >= 1; i--)
              if (_index + i < widget.cards.length)
                Positioned(
                  top: 12.0 + i * 8,
                  left: i * 8,
                  right: i * 8,
                  child: Opacity(
                    opacity: (0.4 - i * 0.15).clamp(0.0, 1.0),
                    child: Transform.rotate(
                      angle: i == 1 ? -0.04 : 0.04,
                      child: Transform.scale(
                        scale: 1 - i * 0.04,
                        child: IgnorePointer(child: FoodCardLarge(food: widget.cards[_index + i])),
                      ),
                    ),
                  ),
                ),
            // Top card
            AnimatedContainer(
              duration: _animatingOut ? const Duration(milliseconds: 220) : Duration.zero,
              curve: HnagMotion.out,
              transform: Matrix4.identity()
                ..translate(_drag.dx * 300, _drag.dy * 300)
                ..rotateZ(_drag.dx * 0.18),
              transformAlignment: Alignment.bottomCenter,
              child: FoodCardLarge(food: widget.cards[_index], showActions: false),
            ),
            // Labels overlay (NOPE / LIKE / DETAIL / LATER)
            _OverlayLabel(text: 'NOPE',   color: t.danger,  visible: _drag.dx < -0.1, angle: -0.18, alignment: const Alignment(-1, -0.7)),
            _OverlayLabel(text: 'LIKE',   color: t.success, visible: _drag.dx > 0.1,  angle: 0.18,  alignment: const Alignment(1, -0.7)),
            _OverlayLabel(text: 'DETAIL', color: HnagColors.info500, visible: _drag.dy < -0.1, angle: 0, alignment: Alignment.topCenter),
            _OverlayLabel(text: 'LẦN SAU',color: t.warning, visible: _drag.dy > 0.1, angle: 0, alignment: Alignment.bottomCenter),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(SemanticTokens t) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🦑', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text('Hết món rồi!',
              style: HnagType.h2.copyWith(color: t.text, fontFamily: HnagFonts.display),
            ),
            const SizedBox(height: 4),
            Text('Refresh để Hà gợi món mới',
              textAlign: TextAlign.center,
              style: HnagType.bodyLg.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
            ),
            const SizedBox(height: 24),
            HnagButton(
              label: 'Refresh',
              variant: BtnVariant.gradient,
              size: BtnSize.lg,
              iconLeading: 'refresh',
              onPressed: () {
                if (widget.onRefreshStack != null) {
                  widget.onRefreshStack!();
                } else {
                  setState(() => _index = 0);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow() {
    return Builder(builder: (context) {
      final t = context.hnag;
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ActionBtn(icon: 'x',       color: t.danger,   size: 52, onTap: () => _commit(CardSwipe.skip)),
                _ActionBtn(icon: 'chevD',   color: t.textMuted,size: 40, onTap: () => _commit(CardSwipe.later)),
                _PrimaryHeart(onTap: () => _commit(CardSwipe.save)),
                _ActionBtn(icon: 'chevU',   color: HnagColors.info500, size: 40, onTap: () => _commit(CardSwipe.detail)),
                _ActionBtn(icon: 'refresh', color: t.ai,       size: 52, onTap: () => _commit(CardSwipe.reroll)),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _label('Bỏ qua', t.textMuted, 52),
                  _label('Lát', t.textMuted, 40),
                  _label('Lưu', t.brand, 64, bold: true),
                  _label('Chi tiết', t.textMuted, 40),
                  _label('Re-roll', t.textMuted, 52),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _label(String s, Color c, double w, {bool bold = false}) => SizedBox(
    width: w,
    child: Text(s, textAlign: TextAlign.center,
      style: HnagType.micro.copyWith(color: c, fontWeight: bold ? FontWeight.w600 : FontWeight.w500, fontFamily: HnagFonts.body),
    ),
  );
}

class _OverlayLabel extends StatelessWidget {
  final String text;
  final Color color;
  final bool visible;
  final double angle;
  final Alignment alignment;
  const _OverlayLabel({required this.text, required this.color, required this.visible, required this.angle, required this.alignment});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: AnimatedOpacity(
          duration: HnagMotion.fast,
          opacity: visible ? 0.9 : 0,
          child: Transform.rotate(
            angle: angle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color, width: 2.5),
              ),
              child: Text(text,
                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 1.2, fontFamily: HnagFonts.body),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String icon;
  final Color color;
  final double size;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.color, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: color, width: 1.5),
        ),
        child: Center(child: HnagIcon(icon, size: size * 0.45, color: color)),
      ),
    );
  }
}

class _PrimaryHeart extends StatelessWidget {
  final VoidCallback onTap;
  const _PrimaryHeart({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: HnagGradients.brand,
          boxShadow: [...t.glow, ...t.shadow3],
        ),
        child: const Center(child: HnagIcon('heart', size: 28, color: Colors.white)),
      ),
    );
  }
}
