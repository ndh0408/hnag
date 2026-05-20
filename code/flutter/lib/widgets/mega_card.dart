import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/food_card.dart';
import '../theme/app_theme.dart';

/// The flagship "Mega Card" — used in the AI Card Stack and feed hero.
///
/// Visual spec: docs/06-VISUAL-FEED.md §3.1. Production-ready w/ video autoplay,
/// blurhash fallback, glass overlay, badges, CTA bar.
class MegaCard extends StatefulWidget {
  final FoodCard card;
  final VoidCallback? onTap;
  final VoidCallback? onSave;
  final VoidCallback? onSkip;
  final VoidCallback? onDetail;
  final ValueChanged<String>? onActionTap; // 'cook' | 'order' | 'dine'
  final bool autoplay;
  final bool active; // top of stack — drives video play

  const MegaCard({
    super.key,
    required this.card,
    this.onTap,
    this.onSave,
    this.onSkip,
    this.onDetail,
    this.onActionTap,
    this.autoplay = true,
    this.active = true,
  });

  @override
  State<MegaCard> createState() => _MegaCardState();
}

class _MegaCardState extends State<MegaCard> {
  VideoPlayerController? _video;
  bool _videoReady = false;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    if (widget.autoplay && widget.card.media.primaryVideo != null) {
      _initVideo(widget.card.media.primaryVideo!);
    }
  }

  Future<void> _initVideo(String url) async {
    final c = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await c.initialize();
      c
        ..setLooping(true)
        ..setVolume(_muted ? 0.0 : 1.0);
      if (widget.active) await c.play();
      if (!mounted) return;
      setState(() {
        _video = c;
        _videoReady = true;
      });
    } catch (_) {
      // fallback to poster only
    }
  }

  @override
  void didUpdateWidget(covariant MegaCard old) {
    super.didUpdateWidget(old);
    if (_video != null && _videoReady) {
      if (widget.active && !_video!.value.isPlaying) _video!.play();
      if (!widget.active && _video!.value.isPlaying) _video!.pause();
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    return VisibilityDetector(
      key: ValueKey('mega-${card.cardId}'),
      onVisibilityChanged: (info) {
        if (_video == null || !_videoReady) return;
        if (info.visibleFraction < 0.3 && _video!.value.isPlaying) {
          _video!.pause();
        } else if (info.visibleFraction >= 0.6 && widget.active) {
          _video!.play();
        }
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.bgElevatedDark,
              borderRadius: BorderRadius.circular(AppRadii.xl),
              boxShadow: AppShadows.lg,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildMedia(card),
                _buildTopChrome(card),
                _buildBottomGlass(card),
                _buildCtaBar(card),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMedia(FoodCard card) {
    final poster = CachedNetworkImage(
      imageUrl: card.media.poster,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: const Color(0xFF222226)),
      errorWidget: (_, __, ___) => Container(color: const Color(0xFF222226)),
    );
    if (_videoReady && _video != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _video!.value.size.width,
              height: _video!.value.size.height,
              child: VideoPlayer(_video!),
            ),
          ),
          // subtle Ken-Burns simulated by background image when video pauses (skipped here)
        ],
      ).animate().fadeIn(duration: 200.ms);
    }
    // Poster + slow Ken-Burns
    return poster
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(begin: const Offset(1.0, 1.0), end: const Offset(1.04, 1.04), duration: 8.seconds);
  }

  Widget _buildTopChrome(FoodCard card) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.x4, AppSpacing.x4, AppSpacing.x4, 0),
        child: Row(
          children: [
            // Badge stack
            Expanded(
              child: Wrap(
                spacing: AppSpacing.x2,
                children: card.badges.take(2).map((b) => _Pill(text: '${b.icon}  ${b.text}', emphasis: b.type)).toList(),
              ),
            ),
            const SizedBox(width: AppSpacing.x2),
            _CircleIconButton(
              icon: _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              onTap: () {
                setState(() => _muted = !_muted);
                _video?.setVolume(_muted ? 0.0 : 1.0);
              },
            ),
            const SizedBox(width: AppSpacing.x2),
            _CircleIconButton(icon: Icons.bookmark_border_rounded, onTap: widget.onSave),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomGlass(FoodCard card) {
    return Positioned(
      left: 0, right: 0, bottom: 76, // leave room for CTA bar (+spacing)
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(AppSpacing.x5, AppSpacing.x5, AppSpacing.x5, AppSpacing.x4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x60000000), Color(0xA8000000)],
              ),
              border: const Border(top: BorderSide(color: Color(0x1FFFFFFF))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(card.title,
                    style: AppTypography.headingMd.copyWith(color: Colors.white),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                _MetaRow(card: card),
                const SizedBox(height: AppSpacing.x3),
                _LiveStatusLine(card: card),
                if (card.aiReason.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.x3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('✨ ', style: TextStyle(fontSize: 13)),
                      Expanded(
                        child: Text(
                          '"${card.aiReason}" — Hà',
                          style: AppTypography.bodyMd.copyWith(
                            color: Colors.white.withOpacity(0.85),
                            fontStyle: FontStyle.italic,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCtaBar(FoodCard card) {
    return Positioned(
      left: AppSpacing.x4, right: AppSpacing.x4, bottom: AppSpacing.x4,
      child: Row(
        children: [
          if (card.actions.cookEnabled)
            Expanded(child: _CtaButton(label: 'Nấu', icon: Icons.local_fire_department_rounded, onTap: () => widget.onActionTap?.call('cook'))),
          if (card.actions.cookEnabled) const SizedBox(width: AppSpacing.x2),
          Expanded(
            flex: 2,
            child: _CtaButton(
              label: 'Đặt giao · ${card.distance.deliveryMin ?? "?"} phút',
              icon: Icons.delivery_dining_rounded,
              isPrimary: true,
              onTap: () => widget.onActionTap?.call('order'),
            ),
          ),
          if (card.actions.dineEnabled) const SizedBox(width: AppSpacing.x2),
          if (card.actions.dineEnabled)
            _CtaButton(label: 'Đi ăn', icon: Icons.directions_walk_rounded, onTap: () => widget.onActionTap?.call('dine')),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Sub-widgets

class _MetaRow extends StatelessWidget {
  final FoodCard card;
  const _MetaRow({required this.card});
  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: AppTypography.bodyMd.copyWith(color: Colors.white.withOpacity(0.92)),
      child: Wrap(
        spacing: AppSpacing.x3,
        runSpacing: 4,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.star_rounded, size: 18, color: AppColors.turmeric),
            const SizedBox(width: 4),
            Text('${card.rating.avg.toStringAsFixed(1)}  (${_compact(card.rating.count)})'),
          ]),
          Text(card.price.display, style: AppTypography.bodyMd.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.place_rounded, size: 18, color: Colors.white70),
            const SizedBox(width: 4),
            Text(card.distance.display),
          ]),
          if (card.calories != null)
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.local_fire_department_outlined, size: 18, color: Colors.white70),
              const SizedBox(width: 4),
              Text('${card.calories} cal'),
            ]),
        ],
      ),
    );
  }

  String _compact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

class _LiveStatusLine extends StatelessWidget {
  final FoodCard card;
  const _LiveStatusLine({required this.card});
  @override
  Widget build(BuildContext context) {
    final live = card.liveStatus;
    if (live == null) return const SizedBox.shrink();
    final crowd = live.crowdedness ?? 0;
    final crowdLabel = crowd < .3 ? 'Trống' : crowd < .65 ? 'Vừa' : crowd < .9 ? 'Đông' : 'Cực đông';
    final crowdColor = crowd < .3 ? AppColors.success : crowd < .65 ? AppColors.turmeric : crowd < .9 ? Color(0xFFFF8C42) : AppColors.danger;

    return Wrap(
      spacing: AppSpacing.x3, runSpacing: 4,
      children: [
        _Dot(color: live.isOpen ? AppColors.success : Colors.grey, text: live.isOpen ? 'Đang mở' : 'Đóng cửa'),
        _Dot(color: crowdColor, text: crowdLabel),
        if (live.recentOrders24h != null && live.recentOrders24h! > 0)
          Text('🔥 ${live.recentOrders24h} đơn 24h',
              style: AppTypography.caption.copyWith(color: Colors.white.withOpacity(0.85))),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  final String text;
  const _Dot({required this.color, required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(text, style: AppTypography.caption.copyWith(color: Colors.white.withOpacity(0.85))),
    ]);
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final String emphasis;
  const _Pill({required this.text, required this.emphasis});
  @override
  Widget build(BuildContext context) {
    final isTrending = emphasis == 'trending' || emphasis == 'viral';
    final isAi = emphasis == 'ai_pick';
    Color bg;
    if (isTrending) {
      bg = AppColors.phoOrange.withOpacity(0.95);
    } else if (isAi) {
      bg = const Color(0xCCA855F7);
    } else {
      bg = Colors.black.withOpacity(0.55);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.full),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Text(text, style: AppTypography.labelSm.copyWith(color: Colors.white)),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _CircleIconButton({required this.icon, this.onTap});
  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Material(
          color: Colors.black.withOpacity(0.32),
          shape: const CircleBorder(side: BorderSide(color: Color(0x33FFFFFF))),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 40, height: 40,
              child: Icon(icon, size: 20, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _CtaButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback? onTap;
  const _CtaButton({required this.label, required this.icon, this.isPrimary = false, this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.full),
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
          decoration: BoxDecoration(
            gradient: isPrimary ? AppGradients.pho : null,
            color: isPrimary ? null : Colors.black.withOpacity(0.55),
            borderRadius: BorderRadius.circular(AppRadii.full),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            boxShadow: isPrimary ? AppShadows.glow(AppColors.phoOrange) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMd.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
