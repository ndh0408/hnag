// HNAG Hi-Fi Design System — Tokens
// Source of truth, mirrors design_handoff_hnag/design/tokens.jsx 1:1.
// Use these for any NEW component. Old `theme/app_theme.dart` is kept for
// backwards-compat with screens that already shipped.

import 'package:flutter/material.dart';

/// Raw color ramps. Always use a semantic token (`SemanticTokens`) in UI code;
/// reach for these only when defining a new semantic.
class HnagColors {
  HnagColors._();

  // Brand (PRIMARY = brand500)
  static const brand50  = Color(0xFFFFF4ED);
  static const brand100 = Color(0xFFFFE6D5);
  static const brand200 = Color(0xFFFFC9A8);
  static const brand300 = Color(0xFFFFA170);
  static const brand400 = Color(0xFFFF8043);
  static const brand500 = Color(0xFFFF6B2B);
  static const brand600 = Color(0xFFF04E0B);
  static const brand700 = Color(0xFFC73C08);
  static const brand800 = Color(0xFF9F310F);
  static const brand900 = Color(0xFF7F2A10);
  static const brand950 = Color(0xFF451104);

  // Chili — heat / urgent / danger
  static const chili400 = Color(0xFFF26271);
  static const chili500 = Color(0xFFE63946);
  static const chili600 = Color(0xFFD02434);

  // Turmeric — premium accent / warning
  static const turmeric400 = Color(0xFFFFC93D);
  static const turmeric500 = Color(0xFFF4B942);
  static const turmeric600 = Color(0xFFD49520);

  // Basil — success / healthy
  static const basil400 = Color(0xFF3DB374);
  static const basil500 = Color(0xFF2D8B5C);
  static const basil600 = Color(0xFF1F6A45);

  // AI / premium (purple)
  static const ai400 = Color(0xFFC084FC);
  static const ai500 = Color(0xFFA855F7);
  static const ai600 = Color(0xFF8B3FE0);

  // Cool info
  static const info500 = Color(0xFF4A6FA5);
  static const info600 = Color(0xFF385A8C);

  // Warm neutrals (slight warm tint, NOT pure grey)
  static const neutral0    = Color(0xFFFFFFFF);
  static const neutral25   = Color(0xFFFBFAF7); // light bg primary
  static const neutral50   = Color(0xFFF7F5F1);
  static const neutral100  = Color(0xFFEFECE5);
  static const neutral200  = Color(0xFFE2DED5);
  static const neutral300  = Color(0xFFC9C3B6);
  static const neutral400  = Color(0xFFA39C8E);
  static const neutral500  = Color(0xFF7A7468);
  static const neutral600  = Color(0xFF5A554B);
  static const neutral700  = Color(0xFF3F3A33);
  static const neutral800  = Color(0xFF26231F);
  static const neutral850  = Color(0xFF1A1814);
  static const neutral900  = Color(0xFF14120F); // light text primary
  static const neutral950  = Color(0xFF0E0B08); // dark bg primary
  static const neutral1000 = Color(0xFF000000);
}

/// Semantic tokens. The whole UI references these — switching theme just
/// re-binds these to the right palette swatch.
class SemanticTokens {
  // Surfaces
  final Color bg;
  final Color bgRaised;
  final Color bgSunken;
  final Color bgElev;
  final Color bgGlass;
  final Color bgMuted;

  // Text
  final Color text;
  final Color textMuted;
  final Color textFaint;
  final Color textInv;

  // Borders
  final Color border;
  final Color borderStrong;
  final Color divider;

  // Brand
  final Color brand;
  final Color brandFg;
  final Color brandSoft;

  // Semantic
  final Color success;
  final Color warning;
  final Color danger;
  final Color ai;

  // Shadows (BoxShadow lists for direct use)
  final List<BoxShadow> shadow1;
  final List<BoxShadow> shadow2;
  final List<BoxShadow> shadow3;
  final List<BoxShadow> shadow4;
  final List<BoxShadow> glow;
  final List<BoxShadow> glowAi;

  final bool isDark;

  const SemanticTokens({
    required this.bg,
    required this.bgRaised,
    required this.bgSunken,
    required this.bgElev,
    required this.bgGlass,
    required this.bgMuted,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.textInv,
    required this.border,
    required this.borderStrong,
    required this.divider,
    required this.brand,
    required this.brandFg,
    required this.brandSoft,
    required this.success,
    required this.warning,
    required this.danger,
    required this.ai,
    required this.shadow1,
    required this.shadow2,
    required this.shadow3,
    required this.shadow4,
    required this.glow,
    required this.glowAi,
    required this.isDark,
  });

  static const light = SemanticTokens(
    bg: HnagColors.neutral25,
    bgRaised: HnagColors.neutral0,
    bgSunken: HnagColors.neutral50,
    bgElev: HnagColors.neutral0,
    bgGlass: Color(0xB8FFFFFF), // 72% opacity white
    bgMuted: HnagColors.neutral100,

    text: HnagColors.neutral900,
    textMuted: HnagColors.neutral600,
    textFaint: HnagColors.neutral400,
    textInv: HnagColors.neutral0,

    border: HnagColors.neutral200,
    borderStrong: HnagColors.neutral300,
    divider: HnagColors.neutral100,

    brand: HnagColors.brand500,
    brandFg: HnagColors.neutral0,
    brandSoft: HnagColors.brand50,

    success: HnagColors.basil500,
    warning: HnagColors.turmeric500,
    danger: HnagColors.chili500,
    ai: HnagColors.ai500,

    shadow1: [
      BoxShadow(color: Color(0x0A14120F), blurRadius: 2,  offset: Offset(0, 1)),
      BoxShadow(color: Color(0x0814120F), blurRadius: 3,  offset: Offset(0, 1)),
    ],
    shadow2: [
      BoxShadow(color: Color(0x0F14120F), blurRadius: 8,  offset: Offset(0, 4), spreadRadius: -2),
      BoxShadow(color: Color(0x0A14120F), blurRadius: 4,  offset: Offset(0, 2), spreadRadius: -1),
    ],
    shadow3: [
      BoxShadow(color: Color(0x1A14120F), blurRadius: 24, offset: Offset(0, 12), spreadRadius: -8),
      BoxShadow(color: Color(0x0F14120F), blurRadius: 8,  offset: Offset(0, 4),  spreadRadius: -2),
    ],
    shadow4: [
      BoxShadow(color: Color(0x2414120F), blurRadius: 48, offset: Offset(0, 24), spreadRadius: -12),
      BoxShadow(color: Color(0x1414120F), blurRadius: 16, offset: Offset(0, 8),  spreadRadius: -4),
    ],
    glow: [
      BoxShadow(color: Color(0x59FF6B2B), blurRadius: 40), // 0.35 alpha
      BoxShadow(color: Color(0x33FF6B2B), blurRadius: 16), // 0.20 alpha
    ],
    glowAi: [
      BoxShadow(color: Color(0x59A855F7), blurRadius: 40),
      BoxShadow(color: Color(0x33A855F7), blurRadius: 16),
    ],
    isDark: false,
  );

  static const dark = SemanticTokens(
    bg: HnagColors.neutral950,
    bgRaised: HnagColors.neutral900,
    bgSunken: HnagColors.neutral1000,
    bgElev: HnagColors.neutral850,
    bgGlass: Color(0xA614120F), // 65% opacity dark
    bgMuted: HnagColors.neutral850,

    text: Color(0xFFF5F2EC),
    textMuted: Color(0xFFA39C8E),
    textFaint: Color(0xFF5A554B),
    textInv: HnagColors.neutral950,

    border: Color(0x14FFFFFF), // rgba(255,255,255,0.08)
    borderStrong: Color(0x24FFFFFF), // 0.14
    divider: Color(0x0FFFFFFF), // 0.06

    brand: HnagColors.brand400,
    brandFg: HnagColors.neutral0,
    brandSoft: Color(0x1FFF6B2B), // 12% alpha

    success: HnagColors.basil400,
    warning: HnagColors.turmeric400,
    danger: HnagColors.chili400,
    ai: HnagColors.ai400,

    shadow1: [BoxShadow(color: Color(0x66000000), blurRadius: 2, offset: Offset(0, 1))],
    shadow2: [BoxShadow(color: Color(0x80000000), blurRadius: 8, offset: Offset(0, 4), spreadRadius: -2)],
    shadow3: [BoxShadow(color: Color(0x99000000), blurRadius: 24, offset: Offset(0, 12), spreadRadius: -8)],
    shadow4: [BoxShadow(color: Color(0xB3000000), blurRadius: 48, offset: Offset(0, 24), spreadRadius: -12)],
    glow: [
      BoxShadow(color: Color(0x73FF6B2B), blurRadius: 60),
      BoxShadow(color: Color(0x4DFF6B2B), blurRadius: 24),
    ],
    glowAi: [
      BoxShadow(color: Color(0x73A855F7), blurRadius: 60),
      BoxShadow(color: Color(0x4DA855F7), blurRadius: 24),
    ],
    isDark: true,
  );
}

/// Reads the current semantic tokens off the BuildContext. Bound via
/// `HnagDesign.of(context)` in `theme.dart`.
extension HnagSemanticOf on BuildContext {
  SemanticTokens get hnag => HnagDesign.of(this);
}

class HnagDesign extends InheritedWidget {
  final SemanticTokens tokens;
  const HnagDesign({super.key, required this.tokens, required super.child});

  static SemanticTokens of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<HnagDesign>();
    if (w != null) return w.tokens;
    final brightness = MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light;
    return brightness == Brightness.dark ? SemanticTokens.dark : SemanticTokens.light;
  }

  @override
  bool updateShouldNotify(HnagDesign oldWidget) => oldWidget.tokens != tokens;
}

// ─────────────────────────────────────────────────────────────
// SPACING (px values match design tokens 0..12)
// ─────────────────────────────────────────────────────────────
class HnagSpacing {
  HnagSpacing._();
  static const double s0  = 0;
  static const double s1  = 4;
  static const double s2  = 8;
  static const double s3  = 12;
  static const double s4  = 16;
  static const double s5  = 20;
  static const double s6  = 24;
  static const double s7  = 32;
  static const double s8  = 40;
  static const double s9  = 48;
  static const double s10 = 64;
  static const double s11 = 80;
  static const double s12 = 96;
}

// ─────────────────────────────────────────────────────────────
// RADIUS
// ─────────────────────────────────────────────────────────────
class HnagRadius {
  HnagRadius._();
  static const double xs   = 6;
  static const double sm   = 10;
  static const double md   = 14;
  static const double lg   = 20;
  static const double xl   = 28;
  static const double r2xl = 36;
  static const double full = 9999;
}

// ─────────────────────────────────────────────────────────────
// MOTION
// ─────────────────────────────────────────────────────────────
class HnagMotion {
  HnagMotion._();
  // Curves (cubic-bezier approximations using Flutter's Cubic)
  static const Curve spring = Cubic(0.34, 1.56, 0.64, 1);
  static const Curve out    = Cubic(0.16, 1, 0.3, 1);
  static const Curve inOut  = Cubic(0.65, 0, 0.35, 1);

  // Durations
  static const Duration fast   = Duration(milliseconds: 150);
  static const Duration base   = Duration(milliseconds: 220);
  static const Duration slow   = Duration(milliseconds: 380);
  static const Duration reveal = Duration(milliseconds: 600);
}

// ─────────────────────────────────────────────────────────────
// TYPOGRAPHY — font stacks
// ─────────────────────────────────────────────────────────────
class HnagFonts {
  HnagFonts._();
  // Resolved via google_fonts in theme.dart; this is the name used by GoogleFonts.
  static const String display = 'Urbanist';
  static const String body    = 'Inter';
  static const String mono    = 'JetBrainsMono';
}

/// Lightweight type token set; `theme.dart` wires these to a TextTheme so any
/// `Theme.of(context).textTheme.headlineLarge` etc still works for legacy code.
class HnagType {
  HnagType._();
  // Display (Urbanist, tight)
  static const TextStyle d1 = TextStyle(fontSize: 56, height: 1.05, fontWeight: FontWeight.w800, letterSpacing: -1.4);
  static const TextStyle d2 = TextStyle(fontSize: 42, height: 1.08, fontWeight: FontWeight.w800, letterSpacing: -1.0);
  static const TextStyle d3 = TextStyle(fontSize: 32, height: 1.12, fontWeight: FontWeight.w700, letterSpacing: -0.7);
  // Headings
  static const TextStyle h1 = TextStyle(fontSize: 26, height: 1.18, fontWeight: FontWeight.w700, letterSpacing: -0.52);
  static const TextStyle h2 = TextStyle(fontSize: 22, height: 1.22, fontWeight: FontWeight.w700, letterSpacing: -0.4);
  static const TextStyle h3 = TextStyle(fontSize: 18, height: 1.28, fontWeight: FontWeight.w600, letterSpacing: -0.25);
  static const TextStyle h4 = TextStyle(fontSize: 16, height: 1.32, fontWeight: FontWeight.w600, letterSpacing: -0.19);
  // Body (Inter)
  static const TextStyle bodyLg = TextStyle(fontSize: 16, height: 1.5, fontWeight: FontWeight.w400, letterSpacing: -0.08);
  static const TextStyle body   = TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w400, letterSpacing: -0.04);
  static const TextStyle bodySm = TextStyle(fontSize: 13, height: 1.5, fontWeight: FontWeight.w400);
  // Label / micro / caps
  static const TextStyle label   = TextStyle(fontSize: 13, height: 1.3, fontWeight: FontWeight.w500, letterSpacing: -0.03);
  static const TextStyle labelSm = TextStyle(fontSize: 12, height: 1.3, fontWeight: FontWeight.w500);
  static const TextStyle micro   = TextStyle(fontSize: 11, height: 1.2, fontWeight: FontWeight.w500, letterSpacing: 0.22);
  static const TextStyle caps    = TextStyle(fontSize: 11, height: 1.0, fontWeight: FontWeight.w600, letterSpacing: 0.88);
  // Numeric (tabular figures)
  static const TextStyle numLg = TextStyle(
    fontSize: 32, height: 1.0, fontWeight: FontWeight.w700, letterSpacing: -0.64,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const TextStyle num = TextStyle(
    fontSize: 18, height: 1.0, fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const TextStyle mono = TextStyle(fontSize: 12, height: 1.4, fontWeight: FontWeight.w500);
}

// Helper for alpha mixing matching the design system's `alpha(hex, a)`.
Color alpha(Color c, double a) => c.withOpacity(a);
