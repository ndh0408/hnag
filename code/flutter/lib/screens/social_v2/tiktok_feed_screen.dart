// TikTok-style food video feed — vertical PageView, 9:16 fullscreen.
// Mirrors design/m-social.jsx Feed screen.

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/food_gradients.dart';
import '../../design/theme.dart';
import '../../widgets/ds/ds.dart';

class TikTokVideoData {
  final String id;
  final String author;
  final String? authorAvatarUrl;
  final String caption;
  final String foodName;
  final String? videoUrl;
  final String foodSlug;
  final int likes;
  final int comments;
  final int shares;
  final int saves;
  final bool followed;
  final bool liked;

  const TikTokVideoData({
    required this.id,
    required this.author,
    this.authorAvatarUrl,
    required this.caption,
    required this.foodName,
    this.videoUrl,
    required this.foodSlug,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.saves,
    this.followed = false,
    this.liked = false,
  });
}

class TikTokFeedScreen extends StatefulWidget {
  final List<TikTokVideoData> videos;
  final VoidCallback? onClose;
  const TikTokFeedScreen({super.key, required this.videos, this.onClose});

  @override
  State<TikTokFeedScreen> createState() => _TikTokFeedScreenState();
}

class _TikTokFeedScreenState extends State<TikTokFeedScreen> {
  final _ctrl = PageController();
  int _index = 0;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return HnagThemeScope(
      dark: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PageView.builder(
              controller: _ctrl,
              scrollDirection: Axis.vertical,
              itemCount: widget.videos.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => _VideoPage(video: widget.videos[i]),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (widget.onClose != null)
                      HnagIconButton(icon: 'chevL', variant: IconBtnVariant.glass, onPressed: widget.onClose),
                    const Spacer(),
                    Text('${_index + 1}/${widget.videos.length}',
                      style: HnagType.mono.copyWith(color: Colors.white.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPage extends StatefulWidget {
  final TikTokVideoData video;
  const _VideoPage({required this.video});

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  late bool _liked;
  late int _likes;

  @override
  void initState() {
    super.initState();
    _liked = widget.video.liked;
    _likes = widget.video.likes;
  }

  String _short(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.video;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background — gradient or video poster
        DecoratedBox(
          decoration: BoxDecoration(gradient: FoodGradients.bySlug(v.foodSlug)),
        ),
        // Bottom gradient for legibility
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
          ),
        ),
        // Bottom-left: caption + author
        Positioned(
          left: 16, right: 80, bottom: 32,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text('@${v.author}',
                    style: HnagType.h3.copyWith(color: Colors.white, fontFamily: HnagFonts.display),
                  ),
                  if (!v.followed) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 1),
                        borderRadius: BorderRadius.circular(HnagRadius.sm),
                      ),
                      child: Text('Follow',
                        style: HnagType.labelSm.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontFamily: HnagFonts.body),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(v.caption,
                style: HnagType.body.copyWith(color: Colors.white, fontFamily: HnagFonts.body),
                maxLines: 3, overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              // Food sticker
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(HnagRadius.full),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const HnagIcon('forkKnife', color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(v.foodName,
                      style: HnagType.labelSm.copyWith(color: Colors.white, fontWeight: FontWeight.w600, fontFamily: HnagFonts.body),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Right side: actions
        Positioned(
          right: 12, bottom: 32,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HnagAvatar(name: v.author, imageUrl: v.authorAvatarUrl, size: 48, ring: true, ringColor: Colors.white),
              const SizedBox(height: 18),
              _Action(
                icon: _liked ? 'heart' : 'heartOutline',
                color: _liked ? HnagColors.chili500 : Colors.white,
                label: _short(_likes),
                onTap: () => setState(() {
                  _liked = !_liked;
                  _likes += _liked ? 1 : -1;
                }),
              ),
              const SizedBox(height: 18),
              _Action(icon: 'chat', color: Colors.white, label: _short(v.comments)),
              const SizedBox(height: 18),
              _Action(icon: 'share', color: Colors.white, label: _short(v.shares)),
              const SizedBox(height: 18),
              _Action(icon: 'bookmark', color: Colors.white, label: _short(v.saves)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  final String icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;
  const _Action({required this.icon, required this.color, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HnagIcon(icon, color: color, size: 32),
          const SizedBox(height: 4),
          Text(label,
            style: HnagType.labelSm.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontFamily: HnagFonts.body),
          ),
        ],
      ),
    );
  }
}
