import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatelessWidget {
  final VoidCallback onReady;
  const SplashScreen({super.key, required this.onReady});

  @override
  Widget build(BuildContext context) {
    Future.delayed(const Duration(milliseconds: 1400), onReady);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.pho),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🍜', style: TextStyle(fontSize: 96))
                  .animate()
                  .scale(begin: const Offset(0.6, 0.6), end: const Offset(1.0, 1.0), duration: 700.ms, curve: Curves.elasticOut)
                  .fadeIn(),
              const SizedBox(height: AppSpacing.x4),
              Text('Hôm Nay Ăn Gì?',
                  style: AppTypography.displayLg.copyWith(color: Colors.white, fontWeight: FontWeight.w800))
                  .animate().fadeIn(delay: 300.ms, duration: 500.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: AppSpacing.x2),
              Text('AI quyết định, bạn thưởng thức',
                  style: AppTypography.bodyMd.copyWith(color: Colors.white.withOpacity(0.85)))
                  .animate().fadeIn(delay: 600.ms),
            ],
          ),
        ),
      ),
    );
  }
}
