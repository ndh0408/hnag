// "Hà đang nghĩ" — loading state with animated AI orb + checklist.
// Mirrors design/m-home.jsx#Screen_AIThinking.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../design/tokens.dart';
import '../../design/gradients.dart';
import '../../design/theme.dart';
import '../../widgets/ds/ds.dart';

class AiThinkingScreen extends StatefulWidget {
  /// Caller resolves with the result; the screen pops itself on success.
  final Future<T?> Function<T>() runDecision;
  final void Function(dynamic result) onDone;
  const AiThinkingScreen({super.key, required this.runDecision, required this.onDone});

  @override
  State<AiThinkingScreen> createState() => _AiThinkingScreenState();
}

class _AiThinkingScreenState extends State<AiThinkingScreen> {
  int _step = 0;
  static const _steps = [
    'Đọc Food DNA',
    'Check thời tiết & giờ',
    'Filter ngân sách',
    'Sắp xếp theo trending',
  ];

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    // Animate through steps in 1.5s while the real call happens
    for (var i = 0; i < _steps.length; i++) {
      await Future.delayed(Duration(milliseconds: 350));
      if (!mounted) return;
      setState(() => _step = i + 1);
    }
    try {
      final r = await widget.runDecision<dynamic>();
      if (!mounted) return;
      widget.onDone(r);
    } catch (e) {
      if (!mounted) return;
      widget.onDone(null);
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
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1,
                      colors: [
                        HnagColors.ai500.withOpacity(0.18),
                        HnagColors.brand500.withOpacity(0.10),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.4, 0.7],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    HnagAppBar(
                      title: '',
                      transparent: true,
                      leading: HnagIconButton(
                        icon: 'x',
                        variant: IconBtnVariant.soft,
                        onPressed: () => Navigator.maybePop(context),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // AI Orb
                            const _AiOrb(),
                            const SizedBox(height: 24),
                            Text('Hà đang nghĩ...',
                              style: HnagType.d3.copyWith(color: t.text, fontFamily: HnagFonts.display),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: 280,
                              child: Text(
                                'Đang khớp 86 món × 14,319 quán × Food DNA của bạn',
                                textAlign: TextAlign.center,
                                style: HnagType.bodyLg.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                              ),
                            ),
                            const SizedBox(height: 32),
                            HnagCard(
                              variant: CardVariant.outline,
                              width: 320,
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                children: [
                                  for (var i = 0; i < _steps.length; i++)
                                    _ChecklistRow(
                                      label: _steps[i],
                                      done: i < _step,
                                      loading: i == _step,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
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

class _AiOrb extends StatelessWidget {
  const _AiOrb();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200, height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow blur
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: HnagGradients.ai,
              boxShadow: [BoxShadow(color: HnagColors.ai500.withOpacity(0.15), blurRadius: 30, spreadRadius: 10)],
            ),
          ).animate(onPlay: (c) => c.repeat()).fadeIn(duration: 600.ms, curve: Curves.easeOut),

          // Dashed orbit
          Container(
            width: 140, height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: HnagColors.ai500.withOpacity(0.4), width: 2, style: BorderStyle.solid),
            ),
          ).animate(onPlay: (c) => c.repeat()).rotate(duration: 4000.ms),

          // Inner circle
          Container(
            width: 100, height: 100,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              border: Border.fromBorderSide(BorderSide(color: HnagColors.brand500, width: 1)),
            ),
          ).animate(onPlay: (c) => c.repeat()).rotate(duration: 8000.ms, begin: 1, end: 0),

          // Core
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: HnagGradients.ai,
              boxShadow: [BoxShadow(color: HnagColors.ai500.withOpacity(0.6), blurRadius: 60)],
            ),
          ),

          // Label
          const Text('Hà',
            style: TextStyle(
              fontSize: 64, height: 1, fontWeight: FontWeight.w800,
              color: Colors.white, letterSpacing: -2.56,
              fontFamily: HnagFonts.display,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  final String label;
  final bool done;
  final bool loading;
  const _ChecklistRow({required this.label, required this.done, required this.loading});

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 16, height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? t.success : Colors.transparent,
              border: done ? null : Border.all(color: loading ? t.brand : t.borderStrong, width: 1.5),
            ),
            child: done
                ? const Center(child: Icon(Icons.check, size: 11, color: Colors.white))
                : loading
                    ? Center(child: Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(color: t.brand, shape: BoxShape.circle),
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(end: 1.3, duration: 600.ms))
                    : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
              style: HnagType.bodySm.copyWith(color: done ? t.textMuted : t.text, fontFamily: HnagFonts.body),
            ),
          ),
          if (loading)
            Text('processing',
              style: HnagType.mono.copyWith(color: t.brand, fontSize: 10),
            ),
        ],
      ),
    );
  }
}
