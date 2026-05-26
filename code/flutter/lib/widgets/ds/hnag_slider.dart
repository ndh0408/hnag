// HnagSlider — horizontal slider matching design `Slider`.

import 'package:flutter/material.dart';
import '../../design/tokens.dart';

class HnagSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final String? label;
  final String? leading;
  final String? trailing;
  final ValueChanged<double>? onChanged;
  final int? divisions;

  const HnagSlider({
    super.key,
    required this.value,
    this.min = 0,
    this.max = 100,
    this.label,
    this.leading,
    this.trailing,
    this.onChanged,
    this.divisions,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(label!, style: HnagType.labelSm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),
          ),
        Row(
          children: [
            if (leading != null) ...[
              Text(leading!, style: HnagType.body.copyWith(color: t.text, fontFamily: HnagFonts.body)),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  activeTrackColor: t.brand,
                  inactiveTrackColor: t.bgMuted,
                  thumbColor: Colors.white,
                  overlayColor: t.brand.withOpacity(0.1),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 2),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                  trackShape: const RoundedRectSliderTrackShape(),
                ),
                child: Slider(
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  divisions: divisions,
                  onChanged: onChanged,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              Text(trailing!, style: HnagType.body.copyWith(color: t.text, fontFamily: HnagFonts.body)),
            ],
          ],
        ),
      ],
    );
  }
}
