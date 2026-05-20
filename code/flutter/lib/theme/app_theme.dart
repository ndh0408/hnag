import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// HNAG design tokens. Single source of truth for colors, type, radii, shadows.
/// Mirror values: see docs/02-DESIGN.md and docs/06-VISUAL-FEED.md.
class AppColors {
  // Primary palette
  static const phoOrange   = Color(0xFFFF6B2B);
  static const chiliRed    = Color(0xFFE63946);
  static const sesameBlack = Color(0xFF0F0F12);
  static const riceWhite   = Color(0xFFFAFAF7);
  static const turmeric    = Color(0xFFF4B942);
  static const basil       = Color(0xFF2D8B5C);

  // Semantic — Light
  static const bgLight        = riceWhite;
  static const bgElevatedLight= Color(0xFFFFFFFF);
  static const textLight      = sesameBlack;
  static const textSecondaryLight = Color(0xFF6B6B72);

  // Semantic — Dark
  static const bgDark        = sesameBlack;
  static const bgElevatedDark= Color(0xFF1A1A20);
  static const textDark      = riceWhite;
  static const textSecondaryDark = Color(0xFFA8A8B0);

  static const accent      = phoOrange;
  static const danger      = chiliRed;
  static const warning     = turmeric;
  static const success     = basil;
}

class AppGradients {
  static const pho = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFFFF6B2B), Color(0xFFE63946)],
  );

  static const premium = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFFF4B942), Color(0xFFFF6B2B), Color(0xFFE63946)],
  );

  static const lateNight = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF1A1A40), Color(0xFF4A1B5C)],
  );

  static const morning = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFFFFD166), Color(0xFFFF6B2B)],
  );

  static const ai = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFFA855F7), Color(0xFFFF6B2B)],
  );

  /// Choose a contextual gradient by [hour] 0–23 and [weather].
  static Gradient contextual({required int hour, String weather = 'clear'}) {
    if (hour >= 22 || hour < 5) return lateNight;
    if (weather == 'rain') {
      return const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF4A6FA5), Color(0xFF1A2F45)],
      );
    }
    if (hour < 11) return morning;
    if (hour < 17) return pho;
    return const LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFF6B4FA0), Color(0xFFFF6B2B)],
    );
  }
}

class AppRadii {
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const full = 999.0;
}

class AppSpacing {
  static const x1 = 4.0;
  static const x2 = 8.0;
  static const x3 = 12.0;
  static const x4 = 16.0;
  static const x5 = 24.0;
  static const x6 = 32.0;
  static const x7 = 48.0;
  static const x8 = 64.0;
}

class AppShadows {
  static const sm = [
    BoxShadow(color: Color(0x0A0F0F12), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0F0F0F12), blurRadius: 3, offset: Offset(0, 1)),
  ];

  static const md = [
    BoxShadow(color: Color(0x140F0F12), blurRadius: 12, offset: Offset(0, 4)),
  ];

  static const lg = [
    BoxShadow(color: Color(0x1F0F0F12), blurRadius: 32, offset: Offset(0, 12)),
  ];

  static List<BoxShadow> glow(Color color) => [
        BoxShadow(color: color.withOpacity(0.4), blurRadius: 32, offset: const Offset(0, 8)),
      ];
}

class AppTypography {
  // Use system font for v1. To use BeVietnamPro: add asset .ttf files and set fontFamily here.
  static const String fontFamily = 'BeVietnamPro';

  static const TextStyle display2xl = TextStyle(fontSize: 56, height: 64/56, fontWeight: FontWeight.w800);
  static const TextStyle displayXl  = TextStyle(fontSize: 40, height: 48/40, fontWeight: FontWeight.w700);
  static const TextStyle displayLg  = TextStyle(fontSize: 32, height: 40/32, fontWeight: FontWeight.w700);
  static const TextStyle headingMd  = TextStyle(fontSize: 24, height: 32/24, fontWeight: FontWeight.w600);
  static const TextStyle headingSm  = TextStyle(fontSize: 20, height: 28/20, fontWeight: FontWeight.w600);
  static const TextStyle bodyLg     = TextStyle(fontSize: 17, height: 26/17, fontWeight: FontWeight.w400);
  static const TextStyle bodyMd     = TextStyle(fontSize: 15, height: 22/15, fontWeight: FontWeight.w400);
  static const TextStyle caption    = TextStyle(fontSize: 13, height: 18/13, fontWeight: FontWeight.w500);
  static const TextStyle labelSm    = TextStyle(fontSize: 11, height: 14/11, fontWeight: FontWeight.w600, letterSpacing: 0.4);
  static const TextStyle numericLg  = TextStyle(fontSize: 28, height: 32/28, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]);
}

ThemeData buildLightTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    colorScheme: const ColorScheme.light(
      primary: AppColors.phoOrange,
      onPrimary: Colors.white,
      secondary: AppColors.turmeric,
      surface: AppColors.bgLight,
      onSurface: AppColors.textLight,
      error: AppColors.danger,
    ),
    scaffoldBackgroundColor: AppColors.bgLight,
    textTheme: GoogleFonts.beVietnamProTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textLight,
      displayColor: AppColors.textLight,
    ),
    splashFactory: InkSparkle.splashFactory,
  );
}

ThemeData buildDarkTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    colorScheme: const ColorScheme.dark(
      primary: AppColors.phoOrange,
      onPrimary: Colors.white,
      secondary: AppColors.turmeric,
      surface: AppColors.bgDark,
      onSurface: AppColors.textDark,
      error: AppColors.danger,
    ),
    scaffoldBackgroundColor: AppColors.bgDark,
    textTheme: GoogleFonts.beVietnamProTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textDark,
      displayColor: AppColors.textDark,
    ),
    splashFactory: InkSparkle.splashFactory,
  );
}
