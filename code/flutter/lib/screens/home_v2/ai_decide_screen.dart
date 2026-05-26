// AI Decide quick mode — mode picker grid + 3 questions (hunger/time/budget).
// Mirrors design/m-home.jsx#Screen_AIDecide.

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/gradients.dart';
import '../../design/theme.dart';
import '../../widgets/ds/ds.dart';

enum AiDecideMode { quick, detail, mood, voice, fridge, group }

class AiDecideSession {
  final AiDecideMode mode;
  final double hunger;     // 0..100
  final String timeBucket; // "5p" | "15p" | "30p" | "1h+"
  final double budget;     // x1000 VND
  final String location;
  const AiDecideSession({
    required this.mode,
    required this.hunger,
    required this.timeBucket,
    required this.budget,
    required this.location,
  });
}

class AiDecideScreen extends StatefulWidget {
  final Future<void> Function(AiDecideSession session) onDecide;
  final ValueChanged<AiDecideMode>? onModeChange;
  const AiDecideScreen({super.key, required this.onDecide, this.onModeChange});

  @override
  State<AiDecideScreen> createState() => _AiDecideScreenState();
}

class _AiDecideScreenState extends State<AiDecideScreen> {
  AiDecideMode _mode = AiDecideMode.quick;
  double _hunger = 65;
  String _time = '15p';
  double _budget = 65;
  int _radiusM = 600;
  String get _location => 'Q.3, TP.HCM · bán kính ${_radiusM < 1000 ? "${_radiusM}m" : "${(_radiusM / 1000).toStringAsFixed(1)}km"}';
  bool _busy = false;

  Future<void> _pickRadius(BuildContext context) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final t = ctx.hnag;
        Widget row(int m, String label) => ListTile(
          leading: HnagIcon(_radiusM == m ? 'check' : 'pin', size: 22, color: _radiusM == m ? t.brand : t.textMuted),
          title: Text(label, style: HnagType.bodyLg.copyWith(color: t.text, fontFamily: HnagFonts.body)),
          onTap: () => Navigator.pop(ctx, m),
        );
        return Container(
          decoration: BoxDecoration(color: t.bgRaised, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: t.divider, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Bán kính tìm món', style: HnagType.h3.copyWith(color: t.text, fontFamily: HnagFonts.display)),
              ),
            ),
            const SizedBox(height: 8),
            row(300, '300m — đi bộ'),
            row(600, '600m — gần văn phòng'),
            row(1500, '1.5km — đi xe'),
            row(3000, '3km — quận lân cận'),
          ]),
        );
      },
    );
    if (picked != null) setState(() => _radiusM = picked);
  }

  static const _times = ['5p', '15p', '30p', '1h+'];

  String _hungerLabel() {
    final v = (_hunger / 10).round();
    final desc = switch (v) {
      <= 2 => 'còn no',
      <= 5 => 'hơi đói',
      <= 7 => 'đói kha khá',
      _    => 'rất đói',
    };
    return 'Mức $v — $desc';
  }

  String _budgetLabel() {
    final lo = (_budget * 0.7).round();
    final hi = (_budget * 1.3).round();
    return '${lo}.000₫ – ${hi}.000₫';
  }

  Future<void> _decide() async {
    setState(() => _busy = true);
    try {
      await widget.onDecide(AiDecideSession(
        mode: _mode,
        hunger: _hunger,
        timeBucket: _time,
        budget: _budget,
        location: _location,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HnagThemeScope(
      dark: false,
      child: Builder(builder: (context) {
        final t = context.hnag;
        return Scaffold(
          backgroundColor: t.bg,
          body: Stack(
            children: [
              // Radial brand background
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.9),
                      radius: 1,
                      colors: [
                        t.brand.withOpacity(0.16),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    HnagAppBar(
                      title: 'AI Decide',
                      transparent: true,
                      leading: HnagIconButton(
                        icon: 'x',
                        variant: IconBtnVariant.soft,
                        onPressed: () => Navigator.maybePop(context),
                      ),
                      actions: const [
                        HnagIconButton(icon: 'settings', variant: IconBtnVariant.soft),
                      ],
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('CHẾ ĐỘ',
                              style: HnagType.caps.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                            ),
                            const SizedBox(height: 10),
                            _ModeGrid(
                              active: _mode,
                              onChange: (m) {
                                setState(() => _mode = m);
                                widget.onModeChange?.call(m);
                              },
                            ),

                            const SizedBox(height: 24),
                            _Question(num: '①', title: 'Đói mức nào?'),
                            const SizedBox(height: 10),
                            HnagCard(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  HnagSlider(
                                    value: _hunger,
                                    leading: '🍃',
                                    trailing: '🔥',
                                    onChanged: (v) => setState(() => _hunger = v),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(_hungerLabel(),
                                    style: HnagType.label.copyWith(color: t.brand, fontWeight: FontWeight.w600, fontFamily: HnagFonts.body),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),
                            _Question(num: '②', title: 'Có bao nhiêu thời gian?'),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8, runSpacing: 8,
                              children: [
                                for (final tm in _times)
                                  HnagChip(
                                    label: tm,
                                    active: _time == tm,
                                    onTap: () => setState(() => _time = tm),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 20),
                            _Question(num: '③', title: 'Ngân sách?'),
                            const SizedBox(height: 10),
                            HnagCard(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  HnagSlider(
                                    value: _budget,
                                    min: 20, max: 500,
                                    leading: '20k',
                                    trailing: '500k',
                                    onChanged: (v) => setState(() => _budget = v),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(_budgetLabel(),
                                    style: HnagType.label.copyWith(color: t.brand, fontWeight: FontWeight.w600, fontFamily: HnagFonts.body),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),
                            HnagCard(
                              variant: CardVariant.outline,
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  HnagIcon('pin', size: 18, color: t.textMuted),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(_location,
                                    style: HnagType.label.copyWith(color: t.text, fontFamily: HnagFonts.body),
                                  )),
                                  HnagButton(label: 'Đổi', variant: BtnVariant.ghost, size: BtnSize.sm, iconTrailing: 'chevR', onPressed: () => _pickRadius(context)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      decoration: BoxDecoration(
                        color: t.bg.withOpacity(0.95),
                        border: Border(top: BorderSide(color: t.divider)),
                      ),
                      child: HnagButton(
                        label: 'Hà ơi, chọn giúp!',
                        variant: BtnVariant.gradient,
                        size: BtnSize.xl,
                        fullWidth: true,
                        iconLeading: 'sparkle',
                        loading: _busy,
                        onPressed: _decide,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _Question extends StatelessWidget {
  final String num;
  final String title;
  const _Question({required this.num, required this.title});

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        HnagBadge(label: num, variant: BadgeVariant.brand, size: BadgeSize.sm),
        const SizedBox(width: 8),
        Text(title, style: HnagType.h3.copyWith(color: t.text, fontFamily: HnagFonts.display)),
      ],
    );
  }
}

class _ModeGrid extends StatelessWidget {
  final AiDecideMode active;
  final ValueChanged<AiDecideMode> onChange;
  const _ModeGrid({required this.active, required this.onChange});

  static const _modes = [
    (AiDecideMode.quick,  'Quick',  'bolt'),
    (AiDecideMode.detail, 'Detail', 'settings'),
    (AiDecideMode.mood,   'Mood',   'smile'),
    (AiDecideMode.voice,  'Voice',  'mic'),
    (AiDecideMode.fridge, 'Fridge', 'cam'),
    (AiDecideMode.group,  'Group',  'users'),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _modes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8, mainAxisExtent: 96,
      ),
      itemBuilder: (_, i) {
        final m = _modes[i];
        final isActive = active == m.$1;
        return Builder(builder: (context) {
          final t = context.hnag;
          return HnagCard(
            variant: isActive ? CardVariant.soft : CardVariant.def,
            padding: const EdgeInsets.all(12),
            onTap: () => onChange(m.$1),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    gradient: isActive ? HnagGradients.brand : null,
                    color: isActive ? null : t.bgMuted,
                    borderRadius: BorderRadius.circular(HnagRadius.sm),
                  ),
                  child: Center(child: HnagIcon(m.$3, size: 18, color: isActive ? Colors.white : t.text)),
                ),
                const SizedBox(height: 6),
                Text(m.$2,
                  style: HnagType.labelSm.copyWith(
                    color: isActive ? t.brand : t.text,
                    fontWeight: FontWeight.w600,
                    fontFamily: HnagFonts.body,
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }
}
