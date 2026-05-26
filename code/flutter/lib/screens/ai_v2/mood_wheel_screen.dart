// Mood Wheel — 8 mood circles arranged radially on dark gradient bg.
// Mirrors design/m-ai.jsx#Screen_MoodWheel.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/gradients.dart';
import '../../design/theme.dart';
import '../../widgets/ds/ds.dart';

class MoodOption {
  final String key;
  final String emoji;
  final String label;
  final Color color;
  const MoodOption({required this.key, required this.emoji, required this.label, required this.color});
}

class MoodWheelScreen extends StatefulWidget {
  final ValueChanged<String> onPicked;
  final VoidCallback? onClose;
  const MoodWheelScreen({super.key, required this.onPicked, this.onClose});

  static const moods = <MoodOption>[
    MoodOption(key: 'happy',      emoji: '😊', label: 'Vui',     color: Color(0xFFFFD166)),
    MoodOption(key: 'sad',        emoji: '😔', label: 'Buồn',    color: Color(0xFF4A6FA5)),
    MoodOption(key: 'tired',      emoji: '😴', label: 'Mệt',     color: Color(0xFF8E7B9A)),
    MoodOption(key: 'stress',     emoji: '😤', label: 'Stress',  color: Color(0xFFE63946)),
    MoodOption(key: 'chill',      emoji: '😎', label: 'Chill',   color: Color(0xFF26A69A)),
    MoodOption(key: 'lonely',     emoji: '🥺', label: 'Cô đơn',  color: Color(0xFFC79DD9)),
    MoodOption(key: 'late_night', emoji: '🌙', label: 'Khuya',   color: Color(0xFF1A1A40)),
    MoodOption(key: 'celebrate',  emoji: '🥳', label: 'Vui chơi',color: Color(0xFFFF6B2B)),
  ];

  @override
  State<MoodWheelScreen> createState() => _MoodWheelScreenState();
}

class _MoodWheelScreenState extends State<MoodWheelScreen> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return HnagThemeScope(
      dark: true,
      child: Builder(builder: (context) {
        final t = context.hnag;
        return Scaffold(
          backgroundColor: HnagColors.neutral950,
          body: Stack(
            children: [
              const Positioned.fill(child: AuroraBackground(opacity: 0.4)),
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          HnagIconButton(
                            icon: 'x',
                            variant: IconBtnVariant.glass,
                            onPressed: widget.onClose ?? () => Navigator.maybePop(context),
                          ),
                          Text('Bạn đang thế nào?',
                            style: HnagType.h3.copyWith(color: Colors.white, fontFamily: HnagFonts.display),
                          ),
                          const SizedBox(width: 40),
                        ],
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final size = math.min(constraints.maxWidth, constraints.maxHeight) - 24;
                          final radius = size / 2 - 50;
                          return Center(
                            child: SizedBox(
                              width: size, height: size,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Center "Hà" core
                                  Container(
                                    width: 80, height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: HnagGradients.brand,
                                      boxShadow: [BoxShadow(color: HnagColors.brand500.withOpacity(0.5), blurRadius: 40)],
                                    ),
                                    child: const Center(
                                      child: Text('Hà',
                                        style: TextStyle(
                                          fontSize: 32, color: Colors.white,
                                          fontWeight: FontWeight.w800, fontFamily: HnagFonts.display, letterSpacing: -1,
                                        ),
                                      ),
                                    ),
                                  ),
                                  for (var i = 0; i < MoodWheelScreen.moods.length; i++)
                                    _MoodCircle(
                                      mood: MoodWheelScreen.moods[i],
                                      angle: (i / MoodWheelScreen.moods.length) * 2 * math.pi - math.pi / 2,
                                      radius: radius,
                                      isSelected: _selected == MoodWheelScreen.moods[i].key,
                                      onTap: () {
                                        setState(() => _selected = MoodWheelScreen.moods[i].key);
                                      },
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: HnagButton(
                        label: _selected == null ? 'Chọn một mood' : 'Hà gợi ý theo mood này',
                        variant: BtnVariant.gradient,
                        size: BtnSize.xl,
                        fullWidth: true,
                        iconTrailing: 'arrowR',
                        onPressed: _selected == null ? null : () => widget.onPicked(_selected!),
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

class _MoodCircle extends StatelessWidget {
  final MoodOption mood;
  final double angle;
  final double radius;
  final bool isSelected;
  final VoidCallback onTap;
  const _MoodCircle({required this.mood, required this.angle, required this.radius, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dx = math.cos(angle) * radius;
    final dy = math.sin(angle) * radius;
    return Transform.translate(
      offset: Offset(dx, dy),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: HnagMotion.fast,
          curve: HnagMotion.spring,
          width: isSelected ? 88 : 76,
          height: isSelected ? 88 : 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: mood.color.withOpacity(isSelected ? 1.0 : 0.85),
            border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
            boxShadow: [
              BoxShadow(color: mood.color.withOpacity(isSelected ? 0.6 : 0.3), blurRadius: isSelected ? 30 : 16, spreadRadius: isSelected ? 4 : 0),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(mood.emoji, style: TextStyle(fontSize: isSelected ? 32 : 28)),
              Text(mood.label,
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white,
                  fontFamily: HnagFonts.body,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
