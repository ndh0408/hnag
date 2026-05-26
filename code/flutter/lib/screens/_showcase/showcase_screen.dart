// Hi-Fi Design System showcase — every primitive rendered in both light + dark
// theme. Reach this screen from Settings → "🎨 Design Showcase" for QA.
//
// This page does not depend on any API or auth state — it's pure widget demo
// so we can confirm tokens / spacing / typography pixel-perfect against
// design_handoff_hnag/design/index.html.

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/theme.dart';
import '../../design/gradients.dart';
import '../../design/food_gradients.dart';
import '../../widgets/ds/ds.dart';

class ShowcaseScreen extends StatefulWidget {
  const ShowcaseScreen({super.key});

  @override
  State<ShowcaseScreen> createState() => _ShowcaseScreenState();
}

class _ShowcaseScreenState extends State<ShowcaseScreen> {
  bool _dark = false;

  @override
  Widget build(BuildContext context) {
    return HnagThemeScope(
      dark: _dark,
      child: Builder(
        builder: (context) {
          final t = context.hnag;
          return Scaffold(
            backgroundColor: t.bg,
            appBar: HnagAppBar(
              title: '🎨 Hi-Fi Design',
              subtitle: _dark ? 'Dark mode' : 'Light mode',
              leading: HnagIconButton(
                icon: 'chevL',
                onPressed: () => Navigator.maybePop(context),
              ),
              actions: [
                HnagIconButton(
                  icon: _dark ? 'sun' : 'moon',
                  variant: IconBtnVariant.soft,
                  onPressed: () => setState(() => _dark = !_dark),
                ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader('Colors', subtitle: 'Brand ramp + warm neutrals + semantic accents'),
                  const _ColorRamps(),

                  _SectionHeader('Typography', subtitle: 'Urbanist display + Inter body'),
                  const _TypeScale(),

                  _SectionHeader('Buttons', subtitle: '5 sizes · 10 variants'),
                  const _ButtonGrid(),

                  _SectionHeader('Icon Buttons', subtitle: 'Circular, with optional badge'),
                  const _IconBtnRow(),

                  _SectionHeader('Cards', subtitle: '10 variants'),
                  const _CardGrid(),

                  _SectionHeader('Badges', subtitle: 'Pill labels — 3 sizes · 10 variants'),
                  const _BadgeGrid(),

                  _SectionHeader('Chips', subtitle: 'Filter pills, active inverts'),
                  const _ChipRow(),

                  _SectionHeader('Avatars', subtitle: 'HSL gradient hash + image fallback + status dot'),
                  const _AvatarRow(),

                  _SectionHeader('Inputs', subtitle: 'Standard input + search bar'),
                  const _InputGroup(),

                  _SectionHeader('Switch + Slider'),
                  const _ToggleSliderRow(),

                  _SectionHeader('Tabs'),
                  const _TabsDemo(),

                  _SectionHeader('Progress'),
                  const _ProgressDemo(),

                  _SectionHeader('Photo placeholders', subtitle: '16 food gradient stand-ins'),
                  const _PhotoGrid(),

                  _SectionHeader('List items'),
                  const _ListItemGroup(),

                  _SectionHeader('Frames', subtitle: 'AppBar + bottom MobileNav'),
                  const _FrameDemo(),

                  _SectionHeader('Aurora background', subtitle: 'Decorative mesh — used behind splash + premium'),
                  const _AuroraDemo(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SECTION HELPERS
// ─────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionHeader(this.title, {this.subtitle});

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 32, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: HnagType.h2.copyWith(color: t.text, fontFamily: HnagFonts.display)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),
          ],
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final Color color;
  final String label;
  final String hex;
  const _Swatch(this.label, this.color, this.hex);

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 80, height: 56,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(HnagRadius.sm),
            border: Border.all(color: t.border),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: HnagType.labelSm.copyWith(color: t.text, fontFamily: HnagFonts.body)),
        Text(hex, style: HnagType.mono.copyWith(color: t.textMuted)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// COLOR RAMPS
// ─────────────────────────────────────────────────────────────
class _ColorRamps extends StatelessWidget {
  const _ColorRamps();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('Brand', const [
            _Swatch('50', HnagColors.brand50, '#FFF4ED'),
            _Swatch('100', HnagColors.brand100, '#FFE6D5'),
            _Swatch('200', HnagColors.brand200, '#FFC9A8'),
            _Swatch('300', HnagColors.brand300, '#FFA170'),
            _Swatch('400', HnagColors.brand400, '#FF8043'),
            _Swatch('500', HnagColors.brand500, '#FF6B2B'),
            _Swatch('600', HnagColors.brand600, '#F04E0B'),
            _Swatch('700', HnagColors.brand700, '#C73C08'),
            _Swatch('800', HnagColors.brand800, '#9F310F'),
            _Swatch('900', HnagColors.brand900, '#7F2A10'),
          ]),
          const SizedBox(height: 16),
          _row('Neutrals', const [
            _Swatch('25',  HnagColors.neutral25,  '#FBFAF7'),
            _Swatch('50',  HnagColors.neutral50,  '#F7F5F1'),
            _Swatch('100', HnagColors.neutral100, '#EFECE5'),
            _Swatch('200', HnagColors.neutral200, '#E2DED5'),
            _Swatch('300', HnagColors.neutral300, '#C9C3B6'),
            _Swatch('400', HnagColors.neutral400, '#A39C8E'),
            _Swatch('500', HnagColors.neutral500, '#7A7468'),
            _Swatch('600', HnagColors.neutral600, '#5A554B'),
            _Swatch('700', HnagColors.neutral700, '#3F3A33'),
            _Swatch('900', HnagColors.neutral900, '#14120F'),
          ]),
          const SizedBox(height: 16),
          _row('Semantic', const [
            _Swatch('chili',    HnagColors.chili500,    '#E63946'),
            _Swatch('turmeric', HnagColors.turmeric500, '#F4B942'),
            _Swatch('basil',    HnagColors.basil500,    '#2D8B5C'),
            _Swatch('ai',       HnagColors.ai500,       '#A855F7'),
            _Swatch('info',     HnagColors.info500,     '#4A6FA5'),
          ]),
        ],
      ),
    );
  }

  Widget _row(String label, List<Widget> items) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: 80,
          child: Builder(builder: (context) {
            final t = context.hnag;
            return Text(label, style: HnagType.label.copyWith(color: t.textMuted, fontFamily: HnagFonts.body));
          }),
        ),
        for (final w in items) ...[const SizedBox(width: 8), w],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TYPE
// ─────────────────────────────────────────────────────────────
class _TypeScale extends StatelessWidget {
  const _TypeScale();

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    Widget row(String label, TextStyle style) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(width: 60, child: Text(label, style: HnagType.mono.copyWith(color: t.textMuted))),
          Expanded(child: Text('Hôm nay ăn gì? Hà gợi ý cho bạn', style: style.copyWith(color: t.text, fontFamily: HnagFonts.body))),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row('d1',  HnagType.d1.copyWith(fontFamily: HnagFonts.display)),
        row('d2',  HnagType.d2.copyWith(fontFamily: HnagFonts.display)),
        row('d3',  HnagType.d3.copyWith(fontFamily: HnagFonts.display)),
        row('h1',  HnagType.h1.copyWith(fontFamily: HnagFonts.display)),
        row('h2',  HnagType.h2.copyWith(fontFamily: HnagFonts.display)),
        row('h3',  HnagType.h3.copyWith(fontFamily: HnagFonts.display)),
        row('h4',  HnagType.h4.copyWith(fontFamily: HnagFonts.display)),
        row('bodyLg', HnagType.bodyLg),
        row('body', HnagType.body),
        row('bodySm', HnagType.bodySm),
        row('label', HnagType.label),
        row('caps', HnagType.caps),
        row('numLg', HnagType.numLg.copyWith(fontFamily: HnagFonts.display)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BUTTONS
// ─────────────────────────────────────────────────────────────
class _ButtonGrid extends StatelessWidget {
  const _ButtonGrid();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10, runSpacing: 10,
      children: const [
        HnagButton(label: 'Primary', variant: BtnVariant.primary),
        HnagButton(label: 'Gradient', variant: BtnVariant.gradient, iconLeading: 'sparkle'),
        HnagButton(label: 'Secondary', variant: BtnVariant.secondary),
        HnagButton(label: 'Ghost', variant: BtnVariant.ghost),
        HnagButton(label: 'Outline', variant: BtnVariant.outline),
        HnagButton(label: 'Soft', variant: BtnVariant.soft, iconLeading: 'heart'),
        HnagButton(label: 'Danger', variant: BtnVariant.danger, iconLeading: 'trash'),
        HnagButton(label: 'Success', variant: BtnVariant.success, iconLeading: 'check'),
        HnagButton(label: 'Glass', variant: BtnVariant.glass),
        HnagButton(label: 'Dark', variant: BtnVariant.dark),
        HnagButton(label: 'xs', size: BtnSize.xs, variant: BtnVariant.outline),
        HnagButton(label: 'sm', size: BtnSize.sm, variant: BtnVariant.outline),
        HnagButton(label: 'md', size: BtnSize.md, variant: BtnVariant.outline),
        HnagButton(label: 'lg', size: BtnSize.lg, variant: BtnVariant.outline),
        HnagButton(label: 'xl', size: BtnSize.xl, variant: BtnVariant.outline),
        HnagButton(label: 'Loading...', loading: true, variant: BtnVariant.primary),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ICON BUTTONS
// ─────────────────────────────────────────────────────────────
class _IconBtnRow extends StatelessWidget {
  const _IconBtnRow();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10, runSpacing: 10,
      children: const [
        HnagIconButton(icon: 'heart', variant: IconBtnVariant.ghost),
        HnagIconButton(icon: 'bookmark', variant: IconBtnVariant.soft),
        HnagIconButton(icon: 'share', variant: IconBtnVariant.outline),
        HnagIconButton(icon: 'sparkle', variant: IconBtnVariant.primary),
        HnagIconButton(icon: 'bell', variant: IconBtnVariant.soft, badge: 3),
        HnagIconButton(icon: 'chat', variant: IconBtnVariant.outline, badge: 12),
        HnagIconButton(icon: 'cam', size: IconBtnSize.xs, variant: IconBtnVariant.soft),
        HnagIconButton(icon: 'cam', size: IconBtnSize.sm, variant: IconBtnVariant.soft),
        HnagIconButton(icon: 'cam', size: IconBtnSize.md, variant: IconBtnVariant.soft),
        HnagIconButton(icon: 'cam', size: IconBtnSize.lg, variant: IconBtnVariant.soft),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CARDS
// ─────────────────────────────────────────────────────────────
class _CardGrid extends StatelessWidget {
  const _CardGrid();

  Widget _card(CardVariant v, String name) {
    return HnagCard(
      variant: v,
      width: 168,
      height: 110,
      child: Builder(builder: (context) {
        final t = context.hnag;
        final isDarkVariant = v == CardVariant.gradient || v == CardVariant.dark;
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: HnagType.h4.copyWith(
              color: isDarkVariant ? Colors.white : t.text,
              fontFamily: HnagFonts.display,
            )),
            Text(
              'CardVariant.${v.name}',
              style: HnagType.mono.copyWith(color: isDarkVariant ? Colors.white70 : t.textMuted),
            ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12, runSpacing: 12,
      children: [
        _card(CardVariant.def, 'Default'),
        _card(CardVariant.raised, 'Raised'),
        _card(CardVariant.elevated, 'Elevated'),
        _card(CardVariant.glass, 'Glass'),
        _card(CardVariant.flat, 'Flat'),
        _card(CardVariant.outline, 'Outline'),
        _card(CardVariant.dashed, 'Dashed'),
        _card(CardVariant.gradient, 'Gradient'),
        _card(CardVariant.dark, 'Dark'),
        _card(CardVariant.soft, 'Soft'),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BADGES
// ─────────────────────────────────────────────────────────────
class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: const [
        HnagBadge(label: 'Default'),
        HnagBadge(label: 'Brand', variant: BadgeVariant.brand),
        HnagBadge(label: 'Soft', variant: BadgeVariant.soft),
        HnagBadge(label: 'Outline', variant: BadgeVariant.outline),
        HnagBadge(label: 'Success', variant: BadgeVariant.success, icon: 'check'),
        HnagBadge(label: 'Warning', variant: BadgeVariant.warning, icon: 'alert'),
        HnagBadge(label: 'Danger', variant: BadgeVariant.danger, icon: 'flame'),
        HnagBadge(label: 'AI', variant: BadgeVariant.ai, icon: 'sparkle'),
        HnagBadge(label: 'Gradient', variant: BadgeVariant.gradient, icon: 'crown'),
        HnagBadge(label: 'NEW', variant: BadgeVariant.dot),
        HnagBadge(label: 'sm', size: BadgeSize.sm),
        HnagBadge(label: 'md', size: BadgeSize.md),
        HnagBadge(label: 'lg', size: BadgeSize.lg),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CHIPS
// ─────────────────────────────────────────────────────────────
class _ChipRow extends StatefulWidget {
  const _ChipRow();

  @override
  State<_ChipRow> createState() => _ChipRowState();
}

class _ChipRowState extends State<_ChipRow> {
  String _active = 'Phở';

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: [
        for (final c in ['Phở', 'Bún', 'Cơm', 'Lẩu', 'Chay', 'Cay'])
          HnagChip(
            label: c,
            active: _active == c,
            onTap: () => setState(() => _active = c),
          ),
        const HnagChip(label: 'Có icon', icon: 'leaf'),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// AVATARS
// ─────────────────────────────────────────────────────────────
class _AvatarRow extends StatelessWidget {
  const _AvatarRow();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12, runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: const [
        HnagAvatar(name: 'Nguyễn An', size: 32),
        HnagAvatar(name: 'Bích', size: 40),
        HnagAvatar(name: 'Cường', size: 48, status: HnagStatus.online),
        HnagAvatar(name: 'Diễm', size: 56, ring: true),
        HnagAvatar(name: 'Em', size: 64, status: HnagStatus.busy),
        HnagAvatar(name: 'Foo', size: 72, ring: true, status: HnagStatus.away),
        HnagAvatarStack(
          names: ['Hà', 'Mai', 'Lan', 'Khoa', 'Phương', 'Tâm', 'Linh'],
          size: 36,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// INPUTS
// ─────────────────────────────────────────────────────────────
class _InputGroup extends StatelessWidget {
  const _InputGroup();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        HnagInput(placeholder: 'Email của bạn', leading: 'email'),
        SizedBox(height: 8),
        HnagSearchBar(placeholder: 'Tìm món, quán...', voice: true),
        SizedBox(height: 8),
        HnagInput(placeholder: 'Mật khẩu', leading: 'lock', obscureText: true),
        SizedBox(height: 8),
        HnagInput(placeholder: 'Sai email', leading: 'email', errorText: 'Email không hợp lệ'),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SWITCH + SLIDER
// ─────────────────────────────────────────────────────────────
class _ToggleSliderRow extends StatefulWidget {
  const _ToggleSliderRow();

  @override
  State<_ToggleSliderRow> createState() => _ToggleSliderRowState();
}

class _ToggleSliderRowState extends State<_ToggleSliderRow> {
  bool _on = true;
  double _budget = 80;

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Thông báo', style: HnagType.body.copyWith(color: t.text, fontFamily: HnagFonts.body)),
            const Spacer(),
            HnagSwitch(value: _on, onChanged: (v) => setState(() => _on = v)),
          ],
        ),
        const SizedBox(height: 12),
        HnagSlider(
          value: _budget,
          min: 20, max: 500,
          label: 'Ngân sách',
          leading: '20k',
          trailing: '${_budget.round()}k',
          onChanged: (v) => setState(() => _budget = v),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TABS
// ─────────────────────────────────────────────────────────────
class _TabsDemo extends StatefulWidget {
  const _TabsDemo();

  @override
  State<_TabsDemo> createState() => _TabsDemoState();
}

class _TabsDemoState extends State<_TabsDemo> {
  String _u = 'Khám phá';
  String _s = 'Sáng';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HnagTabs(
          tabs: const ['Khám phá', 'Trending', 'Bạn bè', 'Tôi'],
          active: _u,
          onChanged: (v) => setState(() => _u = v),
        ),
        const SizedBox(height: 16),
        HnagTabs(
          tabs: const ['Sáng', 'Trưa', 'Tối'],
          active: _s,
          variant: TabsVariant.segmented,
          onChanged: (v) => setState(() => _s = v),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PROGRESS
// ─────────────────────────────────────────────────────────────
class _ProgressDemo extends StatelessWidget {
  const _ProgressDemo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        HnagProgress(value: 25),
        SizedBox(height: 8),
        HnagProgress(value: 60),
        SizedBox(height: 8),
        HnagProgress(value: 92),
        SizedBox(height: 12),
        Row(children: [
          HnagStatusDot(status: 'online'),
          SizedBox(width: 8),
          HnagStatusDot(status: 'away'),
          SizedBox(width: 8),
          HnagStatusDot(status: 'busy'),
          SizedBox(width: 8),
          HnagStatusDot(status: 'offline'),
        ]),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PHOTOS
// ─────────────────────────────────────────────────────────────
class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: [
        for (final slug in FoodGradients.all.keys)
          SizedBox(
            width: 88,
            child: Column(
              children: [
                HnagPhoto(width: 88, height: 88, foodSlug: slug, label: slug),
                const SizedBox(height: 4),
                Builder(builder: (context) {
                  final t = context.hnag;
                  return Text(slug, style: HnagType.mono.copyWith(color: t.textMuted));
                }),
              ],
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// LIST ITEMS
// ─────────────────────────────────────────────────────────────
class _ListItemGroup extends StatelessWidget {
  const _ListItemGroup();

  @override
  Widget build(BuildContext context) {
    return HnagCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          HnagListItem(
            leadingIcon: 'bell',
            title: 'Thông báo',
            subtitle: 'Đẩy + email',
            trailing: const HnagSwitch(value: true),
          ),
          const HnagDivider(),
          HnagListItem(
            leadingIcon: 'lock',
            title: 'Quyền riêng tư',
            trailing: const HnagIcon('chevR', size: 18),
          ),
          const HnagDivider(),
          HnagListItem(
            leadingIcon: 'logout',
            title: 'Đăng xuất',
            danger: true,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FRAMES (AppBar + MobileNav)
// ─────────────────────────────────────────────────────────────
class _FrameDemo extends StatefulWidget {
  const _FrameDemo();

  @override
  State<_FrameDemo> createState() => _FrameDemoState();
}

class _FrameDemoState extends State<_FrameDemo> {
  String _tab = 'home';

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return Container(
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: BorderRadius.circular(HnagRadius.lg),
        border: Border.all(color: t.border),
        boxShadow: t.shadow2,
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          HnagAppBar(
            title: 'Trang chủ',
            subtitle: 'Hà gợi ý 6 món cho bạn',
            leading: const HnagIconButton(icon: 'menu'),
            actions: const [
              HnagIconButton(icon: 'bell', variant: IconBtnVariant.soft, badge: 3),
            ],
          ),
          Container(
            height: 160,
            color: t.bgSunken,
            alignment: Alignment.center,
            child: Text('Body', style: HnagType.h3.copyWith(color: t.textMuted, fontFamily: HnagFonts.display)),
          ),
          HnagMobileNav(
            active: _tab,
            onTap: (k) => setState(() => _tab = k),
            onCenterTap: () => setState(() => _tab = 'ai'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// AURORA
// ─────────────────────────────────────────────────────────────
class _AuroraDemo extends StatelessWidget {
  const _AuroraDemo();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(HnagRadius.lg),
      child: Container(
        height: 160,
        color: HnagColors.neutral950,
        child: AuroraBackground(
          opacity: 0.55,
          child: Center(
            child: Text(
              'Aurora background',
              style: HnagType.h2.copyWith(color: Colors.white, fontFamily: HnagFonts.display),
            ),
          ),
        ),
      ),
    );
  }
}
