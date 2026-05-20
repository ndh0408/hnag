import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class MoodOption {
  final String id;
  final String emoji;
  final String label;
  final Color color;
  const MoodOption(this.id, this.emoji, this.label, this.color);
}

const kMoods = <MoodOption>[
  MoodOption('happy',      '😊', 'Vui',      Color(0xFFFFD166)),
  MoodOption('sad',        '😢', 'Buồn',     Color(0xFF4A6FA5)),
  MoodOption('tired',      '😴', 'Mệt',      Color(0xFF8E7B9A)),
  MoodOption('stress',     '🤯', 'Stress',   Color(0xFFE63946)),
  MoodOption('chill',      '😎', 'Chill',    Color(0xFF26A69A)),
  MoodOption('lonely',     '🥺', 'Cô đơn',   Color(0xFFC79DD9)),
  MoodOption('late_night', '🌙', 'Khuya',    Color(0xFF1A1A40)),
  MoodOption('celebrate',  '🎉', 'Ăn mừng',  Color(0xFFFF6B2B)),
];

class MoodSelectorScreen extends StatefulWidget {
  final ValueChanged<String> onMoodPicked;
  const MoodSelectorScreen({super.key, required this.onMoodPicked});

  @override
  State<MoodSelectorScreen> createState() => _MoodSelectorScreenState();
}

class _MoodSelectorScreenState extends State<MoodSelectorScreen> {
  MoodOption? _selected;

  @override
  Widget build(BuildContext context) {
    final bgColor = _selected?.color ?? AppColors.phoOrange;
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [bgColor.withOpacity(0.7), bgColor],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.x4),
                child: Row(children: [
                  IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                  const Spacer(),
                ]),
              ),
              const SizedBox(height: AppSpacing.x4),
              Text('Bạn đang thấy?',
                  style: AppTypography.displayLg.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(height: AppSpacing.x2),
              Text(_selected == null ? 'Tap mood — Hà gợi món theo cảm xúc' : 'Hà hiểu rồi, đang tìm món...',
                  style: AppTypography.bodyMd.copyWith(color: Colors.white.withOpacity(0.85))),
              const Spacer(),
              _wheel(),
              const Spacer(),
              if (_selected != null)
                ElevatedButton(
                  onPressed: () => widget.onMoodPicked(_selected!.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: bgColor,
                    minimumSize: const Size(260, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.full)),
                  ),
                  child: Text('Xem gợi ý cho "${_selected!.label}"',
                      style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w700)),
                ),
              const SizedBox(height: AppSpacing.x6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wheel() {
    return SizedBox(
      width: 340, height: 340,
      child: Stack(alignment: Alignment.center, children: [
        // Center
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.15),
            border: Border.all(color: Colors.white.withOpacity(0.35), width: 2),
          ),
          child: Center(child: Text(_selected?.emoji ?? '🍜', style: const TextStyle(fontSize: 40))),
        ),
        // 8 moods around the wheel
        ...List.generate(kMoods.length, (i) {
          final mood = kMoods[i];
          final angle = (i / kMoods.length) * 2 * math.pi - math.pi / 2;
          final r = 130.0;
          final dx = math.cos(angle) * r;
          final dy = math.sin(angle) * r;
          final isSel = _selected?.id == mood.id;
          return Transform.translate(
            offset: Offset(dx, dy),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _selected = mood);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: isSel ? 84 : 72, height: isSel ? 84 : 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(isSel ? 0.95 : 0.18),
                  border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
                  boxShadow: isSel ? [BoxShadow(color: Colors.white.withOpacity(0.4), blurRadius: 24)] : null,
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(mood.emoji, style: TextStyle(fontSize: isSel ? 30 : 24)),
                  Text(mood.label,
                      style: AppTypography.caption.copyWith(
                          color: isSel ? mood.color : Colors.white, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          );
        }),
      ]),
    );
  }
}
