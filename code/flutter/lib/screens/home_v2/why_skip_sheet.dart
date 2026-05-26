// Why poll bottom sheet — asks user why they skipped a card.

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/theme.dart';
import '../../widgets/ds/ds.dart';

class WhySkipSheet extends StatefulWidget {
  final String foodName;
  final Future<void> Function(String reason) onSubmit;

  static const reasons = [
    ('đắt',         '💰', 'Quá đắt'),
    ('xa',          '🚗', 'Quá xa'),
    ('vừa-ăn',     '🍽', 'Vừa ăn rồi'),
    ('không-hợp',  '🚫', 'Không hợp khẩu vị'),
    ('không-thèm', '😐', 'Không thèm lúc này'),
    ('không-lý-do',  '🤷', 'Không có lý do'),
  ];

  const WhySkipSheet({super.key, required this.foodName, required this.onSubmit});

  static Future<void> show(BuildContext context, {required String foodName, required Future<void> Function(String reason) onSubmit}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WhySkipSheet(foodName: foodName, onSubmit: onSubmit),
    );
  }

  @override
  State<WhySkipSheet> createState() => _WhySkipSheetState();
}

class _WhySkipSheetState extends State<WhySkipSheet> {
  String? _picked;
  bool _busy = false;

  Future<void> _submit() async {
    if (_picked == null) return;
    setState(() => _busy = true);
    await widget.onSubmit(_picked!);
    if (mounted) Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) {
    return HnagThemeScope(
      dark: false,
      child: Builder(builder: (context) {
        final t = context.hnag;
        return Container(
          decoration: BoxDecoration(
            color: t.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(HnagRadius.xl)),
          ),
          padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: t.borderStrong, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text('Vì sao bỏ qua ${widget.foodName}?',
                style: HnagType.h2.copyWith(color: t.text, fontFamily: HnagFonts.display),
              ),
              const SizedBox(height: 4),
              Text('Phản hồi giúp Hà gợi món chuẩn hơn',
                style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  for (final r in WhySkipSheet.reasons)
                    HnagChip(
                      label: '${r.$2} ${r.$3}',
                      active: _picked == r.$1,
                      onTap: () => setState(() => _picked = r.$1),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              HnagButton(
                label: 'Gửi phản hồi',
                size: BtnSize.lg,
                fullWidth: true,
                onPressed: _picked != null && !_busy ? _submit : null,
                loading: _busy,
              ),
            ],
          ),
        );
      }),
    );
  }
}
