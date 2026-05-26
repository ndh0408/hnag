// HNAG signature gradients — match design_handoff_hnag/design/tokens.jsx
// All gradients here render via `LinearGradient` / `RadialGradient`; for the
// aurora mesh we layer 3 radials in a `Stack`.

import 'package:flutter/material.dart';
import 'tokens.dart';

class HnagGradients {
  HnagGradients._();

  /// Primary brand gradient — used on CTAs, hero cards.
  /// 135° from #FF8043 → #FF6B2B → #E63946
  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF8043), HnagColors.brand500, HnagColors.chili500],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient brandSoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [HnagColors.brand100, HnagColors.brand200],
  );

  /// Premium tier accent.
  static const LinearGradient premium = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [HnagColors.turmeric500, HnagColors.brand500, HnagColors.chili500],
    stops: [0.0, 0.5, 1.0],
  );

  /// AI engine accent (purple → orange).
  static const LinearGradient ai = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [HnagColors.ai500, HnagColors.brand500],
  );

  /// Vivid AI (more saturated).
  static const LinearGradient aiVivid = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B5CF6), Color(0xFFEC4899), HnagColors.brand500],
    stops: [0.0, 0.5, 1.0],
  );

  /// Late night mode background.
  static const LinearGradient night = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1A1A40), Color(0xFF4A1B5C)],
  );

  static const LinearGradient morning = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFD166), HnagColors.brand500],
  );

  static const LinearGradient basil = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [HnagColors.basil400, HnagColors.basil500],
  );

  /// Picks a contextual hero gradient by time of day / weather.
  static LinearGradient contextual({required int hour, String weather = 'clear'}) {
    if (hour >= 22 || hour < 5) return night;
    if (weather == 'rain') {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF4A6FA5), Color(0xFF1A2F45)],
      );
    }
    if (hour < 11) return morning;
    if (hour < 17) return brand;
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF6B4FA0), HnagColors.brand500],
    );
  }
}

/// Decorative aurora mesh — three radial gradients layered. Use as a Stack
/// background; opaque parent recommended.
class AuroraBackground extends StatelessWidget {
  final double opacity;
  final Widget? child;
  const AuroraBackground({super.key, this.opacity = 0.5, this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.4, -0.6),
                radius: 0.9,
                colors: [HnagColors.brand400.withOpacity(opacity), Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.6, 0.0),
                radius: 0.9,
                colors: [HnagColors.ai500.withOpacity(opacity), Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.2, 0.8),
                radius: 0.9,
                colors: [HnagColors.turmeric500.withOpacity(opacity), Colors.transparent],
              ),
            ),
          ),
        ),
        if (child != null) child!,
      ],
    );
  }
}
