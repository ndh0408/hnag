// Welcome v2 — stacked food cards hero + gradient "Hà sẽ chọn cho bạn" headline.
// Mirrors design/m-onboard.jsx#Screen_Welcome.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../design/tokens.dart';
import '../../design/gradients.dart';
import '../../design/food_gradients.dart';
import '../../design/theme.dart';
import '../../widgets/ds/ds.dart';

class WelcomeScreen extends StatelessWidget {
  final VoidCallback onStart;
  final VoidCallback? onSignIn;
  const WelcomeScreen({super.key, required this.onStart, this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return HnagThemeScope(
      dark: false,
      child: Builder(builder: (context) {
        final t = context.hnag;
        return Scaffold(
          backgroundColor: t.bg,
          body: SafeArea(
            child: Column(
              children: [
                // Top "Bỏ qua"
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      HnagButton(label: 'Bỏ qua', size: BtnSize.sm, variant: BtnVariant.ghost, onPressed: onSignIn ?? onStart),
                    ],
                  ),
                ),

                // Visual — stacked cards
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: 260, height: 320,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          // Back left
                          Positioned(
                            top: 10, left: -28,
                            child: Transform.rotate(
                              angle: -0.14,
                              child: _heroCard(FoodGradients.bySlug('goicuon'), width: 200, height: 270),
                            ),
                          ).animate().fadeIn(delay: 100.ms, duration: 500.ms).slideY(begin: 0.1, end: 0),

                          // Back right
                          Positioned(
                            top: 14, right: -16,
                            child: Transform.rotate(
                              angle: 0.10,
                              child: _heroCard(FoodGradients.bySlug('bunbo'), width: 200, height: 270),
                            ),
                          ).animate().fadeIn(delay: 250.ms, duration: 500.ms).slideY(begin: 0.1, end: 0),

                          // Front center
                          Positioned(
                            top: 0,
                            child: _frontHero(),
                          ).animate().fadeIn(delay: 400.ms, duration: 600.ms).slideY(begin: 0.1, end: 0),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom copy + CTA
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Headline with gradient on second line
                      RichText(
                        text: TextSpan(
                          style: HnagType.d2.copyWith(color: t.text, fontFamily: HnagFonts.display, letterSpacing: -1.2),
                          children: [
                            const TextSpan(text: 'Đừng đắn đo nữa,\n'),
                            WidgetSpan(
                              child: ShaderMask(
                                shaderCallback: (b) => HnagGradients.brand.createShader(b),
                                child: Text(
                                  'Hà sẽ chọn cho bạn.',
                                  style: HnagType.d2.copyWith(color: Colors.white, fontFamily: HnagFonts.display, letterSpacing: -1.2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'AI hiểu khẩu vị, ngân sách, và tâm trạng. 14.000 quán thật, 86 món Việt curated.',
                        style: HnagType.bodyLg.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                      ),

                      // Dot indicator (1/7)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(7, (i) => Container(
                            width: i == 0 ? 24 : 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: i == 0 ? t.brand : t.bgMuted,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          )),
                        ),
                      ),

                      HnagButton(
                        label: 'Bắt đầu',
                        variant: BtnVariant.gradient,
                        size: BtnSize.xl,
                        fullWidth: true,
                        iconTrailing: 'arrowR',
                        onPressed: onStart,
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: GestureDetector(
                          onTap: onSignIn,
                          child: RichText(
                            text: TextSpan(
                              style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                              children: [
                                const TextSpan(text: 'Đã có tài khoản? '),
                                TextSpan(
                                  text: 'Đăng nhập',
                                  style: TextStyle(color: t.text, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _heroCard(LinearGradient gradient, {required double width, required double height}) {
    return Container(
      width: width, height: height,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.4),
            blurRadius: 40,
            offset: const Offset(0, 20),
            spreadRadius: -10,
          ),
        ],
      ),
    );
  }

  Widget _frontHero() {
    return Container(
      width: 220, height: 290,
      decoration: BoxDecoration(
        gradient: FoodGradients.bySlug('pho'),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: HnagColors.brand500.withOpacity(0.5),
            blurRadius: 60,
            offset: const Offset(0, 30),
            spreadRadius: -20,
          ),
          BoxShadow(color: Colors.white.withOpacity(0.6), blurRadius: 0, spreadRadius: 6),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('SAU 15 PHÚT',
            style: HnagType.caps.copyWith(color: Colors.white.withOpacity(0.85), fontFamily: HnagFonts.body),
          ),
          const SizedBox(height: 4),
          Text('Phở bò tái',
            style: HnagType.h2.copyWith(color: Colors.white, fontFamily: HnagFonts.display),
          ),
          const SizedBox(height: 4),
          Text('45.000 ₫ · 480 cal · ⭐ 4.8',
            style: HnagType.bodySm.copyWith(color: Colors.white.withOpacity(0.85), fontFamily: HnagFonts.body),
          ),
          const SizedBox(height: 10),
          const HnagBadge(label: 'Hà chọn', variant: BadgeVariant.glass, icon: 'sparkle'),
        ],
      ),
    );
  }
}
