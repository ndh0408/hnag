// HnagSwitch — iOS-style 44×26 toggle. Mirrors design `Switch`.

import 'package:flutter/material.dart';
import '../../design/tokens.dart';

class HnagSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const HnagSwitch({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: HnagMotion.fast,
        curve: HnagMotion.out,
        width: 44, height: 26,
        decoration: BoxDecoration(
          color: value ? t.brand : t.bgMuted,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: HnagMotion.fast,
              curve: HnagMotion.out,
              top: 2,
              left: value ? 20 : 2,
              child: Container(
                width: 22, height: 22,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2))],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
