// Haptic feedback + animation-timing primitives.
//
// Audit production-killer §7 ("Frontend micro-polish — haptic feel,
// motion consistency"). Consumer apps win on feel; the cheapest feel
// upgrades are:
//   1. Tap-to-confirm haptic on every Primary CTA
//   2. Consistent animation durations across screens
//   3. Predictable easing curves
//
// This file centralises those constants so future-you doesn't sprinkle
// magic `Duration(milliseconds: 200)` and `Curves.easeOut` throughout the
// app, then refactor when the brand guidelines change.
//
// Adoption pattern:
//
//     // before:
//     onTap: () { _doThing(); }
//     AnimatedSwitcher(duration: const Duration(milliseconds: 300), …)
//
//     // after:
//     onTap: () { HnagFeedback.tap(); _doThing(); }
//     AnimatedSwitcher(duration: HnagMotion.medium, switchInCurve: HnagCurves.standard, …)

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class HnagFeedback {
  HnagFeedback._();

  /// Light tap haptic. Use on every Primary CTA, swipe, card add.
  /// Costs ~0 (system call). No-op silently when haptics aren't available
  /// (web, some older Androids without the vibrator service).
  static Future<void> tap() async {
    if (kIsWeb) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {/* swallow */}
  }

  /// Medium impact — for state-flipping actions (like, save, follow).
  static Future<void> tapMedium() async {
    if (kIsWeb) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {/* swallow */}
  }

  /// Selection click — for tab switches, segmented controls, picker
  /// reels. Distinct from `tap` so users get a different feel.
  static Future<void> selection() async {
    if (kIsWeb) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {/* swallow */}
  }

  /// Success — for completed checkout, successful claim, etc.
  static Future<void> success() async {
    if (kIsWeb) return;
    try {
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 60));
      await HapticFeedback.lightImpact();
    } catch (_) {/* swallow */}
  }

  /// Error — for form validation fails, payment rejections.
  static Future<void> error() async {
    if (kIsWeb) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {/* swallow */}
  }
}

/// Animation durations — used in `AnimatedContainer`, `AnimatedSwitcher`,
/// `Hero` transitions, etc. Three tiers; pick the one that matches the
/// emotional weight of the change.
///
/// Tuned to the Material 3 motion spec but kept slightly snappier:
/// consumer apps tend to feel faster than enterprise SaaS.
class HnagMotion {
  HnagMotion._();

  /// Micro-interactions — toggle, ripple finish, icon flip. ~120ms.
  static const Duration fast = Duration(milliseconds: 120);

  /// Page transitions, expand/collapse, sheet slide. ~240ms.
  /// This is the default — when in doubt, use this.
  static const Duration medium = Duration(milliseconds: 240);

  /// Hero transitions, big context switches, splash-to-home. ~400ms.
  static const Duration slow = Duration(milliseconds: 400);

  /// Toast / banner enter — long enough to draw attention without
  /// stealing flow. ~180ms.
  static const Duration toast = Duration(milliseconds: 180);
}

/// Easing curves — one per emotional intent.
class HnagCurves {
  HnagCurves._();

  /// Standard enter/exit — Material's `easeInOut`. Use for everything
  /// unless you have a specific reason.
  static const Curve standard = Curves.easeInOutCubic;

  /// Enter with a small overshoot — adds personality on hero / FAB.
  /// Don't overuse; it gets annoying.
  static const Curve enterBouncy = Curves.elasticOut;

  /// Exit / dismiss — fast at first, slow at end, like the user is
  /// "throwing it away".
  static const Curve exit = Curves.easeInQuart;

  /// Sheet drag-to-dismiss — naturalistic.
  static const Curve drag = Curves.easeOutCubic;
}
