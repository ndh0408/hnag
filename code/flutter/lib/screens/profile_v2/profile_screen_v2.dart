// Profile v2 — cover + avatar overlap + stats + tabs + content grid.
// Mirrors design/m-social.jsx (Profile self/other).

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/gradients.dart';
import '../../design/food_gradients.dart';
import '../../design/theme.dart';
import '../../widgets/ds/ds.dart';

class ProfileDataV2 {
  final String id;
  final String displayName;
  final String username;
  final String? avatarUrl;
  final String? coverUrl;
  final String? coverFoodSlug;
  final String bio;
  final int level;
  final String foodieClass; // tép / tôm / cua / mực / cá-mập / rồng
  final String classEmoji;
  final int reviews;
  final int followers;
  final int following;
  final bool isPremium;
  final bool isVerified;
  final bool isMe;
  final bool followed;

  const ProfileDataV2({
    required this.id,
    required this.displayName,
    required this.username,
    this.avatarUrl,
    this.coverUrl,
    this.coverFoodSlug = 'pho',
    required this.bio,
    required this.level,
    required this.foodieClass,
    required this.classEmoji,
    required this.reviews,
    required this.followers,
    required this.following,
    this.isPremium = false,
    this.isVerified = false,
    this.isMe = false,
    this.followed = false,
  });
}

class ProfileScreenV2 extends StatefulWidget {
  final ProfileDataV2 profile;
  final VoidCallback? onEdit;
  final VoidCallback? onSettings;
  final VoidCallback? onMessage;
  final VoidCallback? onShare;
  final VoidCallback? onFollow;
  const ProfileScreenV2({
    super.key,
    required this.profile,
    this.onEdit,
    this.onSettings,
    this.onMessage,
    this.onShare,
    this.onFollow,
  });

  @override
  State<ProfileScreenV2> createState() => _ProfileScreenV2State();
}

class _ProfileScreenV2State extends State<ProfileScreenV2> {
  String _tab = 'Reviews';
  late bool _followed;

  @override
  void initState() {
    super.initState();
    _followed = widget.profile.followed;
  }

  @override
  Widget build(BuildContext context) {
    return HnagThemeScope(
      dark: false,
      child: Builder(builder: (context) {
        final t = context.hnag;
        final p = widget.profile;
        return Scaffold(
          backgroundColor: t.bg,
          body: NestedScrollView(
            headerSliverBuilder: (_, __) => [
              SliverAppBar(
                expandedHeight: 220,
                pinned: false,
                automaticallyImplyLeading: false,
                backgroundColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      HnagPhoto(
                        imageUrl: p.coverUrl,
                        foodSlug: p.coverFoodSlug,
                        aspectRatio: 5 / 3, radius: 0,
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                colors: [Colors.black.withOpacity(0.3), Colors.transparent, Colors.black.withOpacity(0.5)],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              HnagIconButton(
                                icon: 'chevL',
                                variant: IconBtnVariant.glass,
                                onPressed: () => Navigator.maybePop(context),
                              ),
                              Row(children: [
                                HnagIconButton(icon: 'share', variant: IconBtnVariant.glass, onPressed: widget.onShare),
                                const SizedBox(width: 8),
                                if (p.isMe)
                                  HnagIconButton(icon: 'settings', variant: IconBtnVariant.glass, onPressed: widget.onSettings)
                                else
                                  const HnagIconButton(icon: 'more', variant: IconBtnVariant.glass),
                              ]),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            body: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Avatar + name section
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, -36),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(color: t.bg, shape: BoxShape.circle),
                              child: HnagAvatar(
                                name: p.displayName, imageUrl: p.avatarUrl, size: 88,
                                ring: p.isPremium, ringColor: p.isPremium ? HnagColors.turmeric500 : null,
                              ),
                            ),
                            const Spacer(),
                            if (p.isMe)
                              HnagButton(label: 'Sửa', iconLeading: 'edit', variant: BtnVariant.secondary, size: BtnSize.sm, onPressed: widget.onEdit)
                            else
                              Row(children: [
                                HnagButton(label: 'Nhắn', iconLeading: 'chat', variant: BtnVariant.secondary, size: BtnSize.sm, onPressed: widget.onMessage),
                                const SizedBox(width: 6),
                                HnagButton(
                                  label: _followed ? 'Đang theo dõi' : 'Theo dõi',
                                  variant: _followed ? BtnVariant.soft : BtnVariant.primary,
                                  size: BtnSize.sm,
                                  onPressed: () {
                                    setState(() => _followed = !_followed);
                                    widget.onFollow?.call();
                                  },
                                ),
                              ]),
                          ],
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(0, -16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(p.displayName,
                                    overflow: TextOverflow.ellipsis,
                                    style: HnagType.h1.copyWith(color: t.text, fontFamily: HnagFonts.display),
                                  ),
                                ),
                                if (p.isVerified) ...[
                                  const SizedBox(width: 6),
                                  HnagIcon('check', color: t.brand, size: 18),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('@${p.username}',
                              style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                            ),
                            const SizedBox(height: 10),
                            // Class + level
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    gradient: HnagGradients.brand,
                                    borderRadius: BorderRadius.circular(HnagRadius.full),
                                  ),
                                  child: Text('${p.classEmoji} ${p.foodieClass} · Lv ${p.level}',
                                    style: HnagType.labelSm.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontFamily: HnagFonts.body),
                                  ),
                                ),
                                if (p.isPremium) ...[
                                  const SizedBox(width: 6),
                                  const HnagBadge(label: 'HNAG+', icon: 'crown', variant: BadgeVariant.warning),
                                ],
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(p.bio,
                              style: HnagType.body.copyWith(color: t.text, fontFamily: HnagFonts.body),
                            ),
                          ],
                        ),
                      ),
                      // Stats row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatCol(value: '${p.reviews}', label: 'Reviews'),
                          _vert(t),
                          _StatCol(value: '${p.followers}', label: 'Followers'),
                          _vert(t),
                          _StatCol(value: '${p.following}', label: 'Following'),
                        ],
                      ),
                    ],
                  ),
                ),

                // Tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: HnagTabs(
                    tabs: const ['Reviews', 'Saved', 'Photos', 'Badges'],
                    active: _tab,
                    onChanged: (v) => setState(() => _tab = v),
                  ),
                ),

                const SizedBox(height: 16),
                _buildTabContent(t),
                const SizedBox(height: 60),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _vert(SemanticTokens t) => Container(width: 1, height: 24, color: t.divider);

  Widget _buildTabContent(SemanticTokens t) {
    if (_tab == 'Reviews') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            for (final r in const [
              (food: 'Bún bò Huế', rating: '⭐⭐⭐⭐⭐', text: '"Đậm vị, đủ cay, đúng món miền Trung tôi thích."', time: '2 ngày trước'),
              (food: 'Phở Lý Quốc Sư', rating: '⭐⭐⭐⭐⭐', text: '"Phở ngon nhất quận 3, đáng đồng tiền."', time: '5 ngày trước'),
            ]) ...[
              HnagCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(r.food, style: HnagType.h4.copyWith(color: t.text, fontFamily: HnagFonts.display))),
                        Text(r.rating, style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(r.text, style: HnagType.body.copyWith(color: t.text, fontStyle: FontStyle.italic, fontFamily: HnagFonts.body)),
                    const SizedBox(height: 6),
                    Text(r.time, style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      );
    }
    if (_tab == 'Badges') {
      const badges = [
        ('🦐', 'Tép',     'Lv 1-2'),
        ('🍤', 'Tôm',     'Lv 3-5'),
        ('🦀', 'Cua',     'Lv 6-9'),
        ('🦑', 'Mực',     'Lv 10-14'),
        ('🦈', 'Cá mập',  'Lv 15-19'),
        ('🐉', 'Rồng',    'Lv 20+'),
      ];
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: badges.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.9,
          ),
          itemBuilder: (_, i) {
            final b = badges[i];
            final unlocked = i <= 3; // demo: 4 unlocked
            return HnagCard(
              variant: unlocked ? CardVariant.def : CardVariant.dashed,
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Opacity(opacity: unlocked ? 1 : 0.3, child: Text(b.$1, style: const TextStyle(fontSize: 36))),
                  const SizedBox(height: 4),
                  Text(b.$2, style: HnagType.label.copyWith(color: unlocked ? t.text : t.textFaint, fontWeight: FontWeight.w600, fontFamily: HnagFonts.body)),
                  Text(b.$3, style: HnagType.micro.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),
                ],
              ),
            );
          },
        ),
      );
    }
    // Saved + Photos: food gradient grid
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 9,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 4, crossAxisSpacing: 4, childAspectRatio: 1,
        ),
        itemBuilder: (_, i) => HnagPhoto(
          foodSlug: FoodGradients.all.keys.elementAt(i % FoodGradients.all.length),
          aspectRatio: 1, radius: HnagRadius.sm,
        ),
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  final String value;
  final String label;
  const _StatCol({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return Column(
      children: [
        Text(value, style: HnagType.h2.copyWith(color: t.text, fontFamily: HnagFonts.display)),
        Text(label, style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),
      ],
    );
  }
}
