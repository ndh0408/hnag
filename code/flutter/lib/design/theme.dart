// HNAG Hi-Fi ThemeData — wires SemanticTokens into Material 3 ThemeData so
// platform widgets (NavigationBar, Switch, etc.) also follow the design.
//
// This is the NEW theme. Existing `theme/app_theme.dart` keeps powering the
// already-shipped screens; new screens should pull from `design/` instead.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tokens.dart';

ThemeData buildHnagLightTheme() => _buildTheme(SemanticTokens.light);
ThemeData buildHnagDarkTheme() => _buildTheme(SemanticTokens.dark);

ThemeData _buildTheme(SemanticTokens t) {
  final isDark = t.isDark;
  final base = isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);

  final displayText = GoogleFonts.urbanistTextTheme(base.textTheme);
  final bodyText    = GoogleFonts.interTextTheme(base.textTheme);

  return base.copyWith(
    colorScheme: (isDark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
      primary: t.brand,
      onPrimary: t.brandFg,
      secondary: t.warning,
      surface: t.bgRaised,
      onSurface: t.text,
      error: t.danger,
      outline: t.border,
      brightness: isDark ? Brightness.dark : Brightness.light,
    ),
    scaffoldBackgroundColor: t.bg,
    canvasColor: t.bg,
    dividerColor: t.divider,

    // Type — body uses Inter, headlines use Urbanist
    textTheme: TextTheme(
      displayLarge:   HnagType.d1.copyWith(color: t.text, fontFamily: displayText.displayLarge?.fontFamily),
      displayMedium:  HnagType.d2.copyWith(color: t.text, fontFamily: displayText.displayMedium?.fontFamily),
      displaySmall:   HnagType.d3.copyWith(color: t.text, fontFamily: displayText.displaySmall?.fontFamily),
      headlineLarge:  HnagType.h1.copyWith(color: t.text, fontFamily: displayText.headlineLarge?.fontFamily),
      headlineMedium: HnagType.h2.copyWith(color: t.text, fontFamily: displayText.headlineMedium?.fontFamily),
      headlineSmall:  HnagType.h3.copyWith(color: t.text, fontFamily: displayText.headlineSmall?.fontFamily),
      titleLarge:     HnagType.h3.copyWith(color: t.text, fontFamily: displayText.titleLarge?.fontFamily),
      titleMedium:    HnagType.h4.copyWith(color: t.text, fontFamily: displayText.titleMedium?.fontFamily),
      bodyLarge:      HnagType.bodyLg.copyWith(color: t.text, fontFamily: bodyText.bodyLarge?.fontFamily),
      bodyMedium:     HnagType.body.copyWith(color: t.text, fontFamily: bodyText.bodyMedium?.fontFamily),
      bodySmall:      HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: bodyText.bodySmall?.fontFamily),
      labelLarge:     HnagType.label.copyWith(color: t.text, fontFamily: bodyText.labelLarge?.fontFamily),
      labelMedium:    HnagType.labelSm.copyWith(color: t.text, fontFamily: bodyText.labelMedium?.fontFamily),
      labelSmall:     HnagType.micro.copyWith(color: t.textMuted, fontFamily: bodyText.labelSmall?.fontFamily),
    ),

    iconTheme: IconThemeData(color: t.text, size: 20),

    appBarTheme: AppBarTheme(
      backgroundColor: t.bg,
      foregroundColor: t.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: HnagType.h3.copyWith(color: t.text, fontFamily: HnagFonts.display),
    ),

    cardTheme: CardThemeData(
      color: t.bgElev,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HnagRadius.lg),
        side: BorderSide(color: t.border),
      ),
    ),

    splashFactory: InkSparkle.splashFactory,
  );
}

/// Wraps `child` in both `Theme` AND `HnagDesign` so `context.hnag` resolves to
/// the matching token set. Use this in `MaterialApp.builder` or around tests.
class HnagThemeScope extends StatelessWidget {
  final bool dark;
  final Widget child;
  const HnagThemeScope({super.key, required this.dark, required this.child});

  @override
  Widget build(BuildContext context) {
    final tokens = dark ? SemanticTokens.dark : SemanticTokens.light;
    return HnagDesign(
      tokens: tokens,
      child: Theme(
        data: dark ? buildHnagDarkTheme() : buildHnagLightTheme(),
        child: child,
      ),
    );
  }
}
