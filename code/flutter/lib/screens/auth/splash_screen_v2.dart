// Splash v2 — dark aurora bg + logo bloom + 3-dot loader.
// Mirrors design/m-onboard.jsx#Screen_Splash.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../design/tokens.dart';
import '../../design/gradients.dart';

class SplashScreenV2 extends StatefulWidget {
  final VoidCallback onReady;
  final Duration delay;
  const SplashScreenV2({super.key, required this.onReady, this.delay = const Duration(milliseconds: 1400)});

  @override
  State<SplashScreenV2> createState() => _SplashScreenV2State();
}

class _SplashScreenV2State extends State<SplashScreenV2> {
  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, widget.onReady);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HnagColors.neutral950,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Aurora bg
          const AuroraBackground(opacity: 0.6),
          // Radial fade
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.7,
                colors: [Colors.transparent, Color(0xF20E0B08)],
                stops: [0.3, 0.85],
              ),
            ),
          ),
          // Center logo + text
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    gradient: HnagGradients.brand,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: const [
                      BoxShadow(color: Color(0x99FF6B2B), blurRadius: 80),
                      BoxShadow(color: Color(0x66000000), blurRadius: 40, offset: Offset(0, 20)),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'Ă',
                      style: TextStyle(
                        fontSize: 70, height: 1, fontWeight: FontWeight.w800,
                        color: Colors.white, letterSpacing: -2.8,
                        fontFamily: HnagFonts.display,
                      ),
                    ),
                  ),
                )
                    .animate()
                    .scale(begin: const Offset(0.5, 0.5), end: const Offset(1.0, 1.0), duration: 700.ms, curve: Curves.elasticOut)
                    .fadeIn(),
                const SizedBox(height: 28),
                const Text(
                  'Hôm Nay Ăn Gì?',
                  style: TextStyle(
                    fontSize: 42, height: 1.08, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: -1.0,
                    fontFamily: HnagFonts.display,
                  ),
                ).animate().fadeIn(delay: 300.ms, duration: 500.ms).slideY(begin: 0.15, end: 0),
                const SizedBox(height: 8),
                const Text(
                  'AI chọn bữa ăn cho người Việt',
                  style: TextStyle(
                    fontSize: 14, height: 1.5, fontWeight: FontWeight.w400,
                    color: Color(0x80FFFFFF),
                    fontFamily: HnagFonts.body,
                  ),
                ).animate().fadeIn(delay: 600.ms),
              ],
            ),
          ),
          // 3-dot loader
          Align(
            alignment: const Alignment(0, 0.85),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) => Container(
                width: 6, height: 6, margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(i == 1 ? 0.7 : 0.3),
                  shape: BoxShape.circle,
                ),
              )),
            ),
          ),
        ],
      ),
    );
  }
}
