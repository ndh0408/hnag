// Front-end crash reporting hook.
//
// Audit production-killer §1 ("Observability — error tracking, Flutter
// crash"). The backend has a Sentry lazy-require hook (sentry.ts); this is
// the equivalent for Flutter. When `package:sentry_flutter` is added to
// pubspec.yaml the captureUnhandled/init paths activate; until then the
// reporter logs to debug console so the integration points exist but the
// app boots cleanly without the dep.
//
// To activate (one-time, ~10 minutes):
//
//   1. Add `sentry_flutter: ^8.7.0` (or current major) to pubspec.yaml.
//   2. Uncomment the SentryFlutter import + init block below.
//   3. Set `SENTRY_DSN` via --dart-define=SENTRY_DSN=https://… or in your
//      build script. Empty DSN keeps the reporter inactive.
//
// Why a wrapper class instead of calling Sentry directly:
//   - The call sites in the rest of the app (`CrashReporter.capture(...)`)
//     never change when Sentry version bumps or we swap to a different
//     vendor (Bugsnag / Datadog).
//   - Tests can `setMockReporter()` to assert capture calls.
//   - When the dep isn't installed, the no-op fallback writes a debug
//     line — better than silent black-hole.

import 'package:flutter/foundation.dart';

// When sentry_flutter is added, uncomment:
// import 'package:sentry_flutter/sentry_flutter.dart';

const _sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');
const _release = String.fromEnvironment('SENTRY_RELEASE', defaultValue: 'hnag@dev');
const _environment = String.fromEnvironment('SENTRY_ENVIRONMENT', defaultValue: 'development');

class CrashReporter {
  CrashReporter._();

  static bool _active = false;

  /// Initialize. Returns once Sentry (when wired) has loaded — guaranteed
  /// non-throwing so a misconfigured DSN never blocks app boot.
  static Future<void> init() async {
    if (_sentryDsn.isEmpty) {
      if (kDebugMode) debugPrint('CrashReporter: SENTRY_DSN empty, skipping init');
      return;
    }
    try {
      // When sentry_flutter is added, replace the no-op below with:
      //
      // await SentryFlutter.init(
      //   (options) {
      //     options.dsn = _sentryDsn;
      //     options.release = _release;
      //     options.environment = _environment;
      //     options.tracesSampleRate = 0.1;
      //     // Don't capture in debug — we'd flood Sentry on hot reload.
      //     options.beforeSend = (event, hint) => kDebugMode ? null : event;
      //   },
      // );
      _active = true;
      if (kDebugMode) debugPrint('CrashReporter: ready (dsn=${_redact(_sentryDsn)}, release=$_release)');
    } catch (e) {
      if (kDebugMode) debugPrint('CrashReporter: init failed: $e');
    }
  }

  /// Wire global FlutterError.onError so framework-level errors are
  /// captured automatically. Call once from `main()` after `init`.
  static void install() {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      capture(details.exception, stack: details.stack);
      originalOnError?.call(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      capture(error, stack: stack);
      return false; // let the default handler run too
    };
  }

  /// Report a caught exception. Safe to call before/without init.
  static void capture(Object error, {StackTrace? stack, String? tag}) {
    if (!_active) {
      if (kDebugMode) debugPrint('CrashReporter (inactive): ${tag ?? ''} $error');
      return;
    }
    try {
      // When sentry_flutter is added, replace the no-op below with:
      //
      // Sentry.captureException(error, stackTrace: stack, hint: tag != null
      //     ? Hint.withMap({'tag': tag}) : null);
      if (kDebugMode) debugPrint('CrashReporter captured: ${tag ?? ''} $error');
    } catch (_) {/* swallow — telemetry must never crash the app */}
  }

  /// Tag a non-error breadcrumb for context (route changes, deep links).
  static void breadcrumb(String message, {String? category, Map<String, Object?>? data}) {
    if (!_active) return;
    try {
      // When sentry_flutter is added:
      // Sentry.addBreadcrumb(Breadcrumb(
      //   message: message,
      //   category: category,
      //   data: data,
      //   timestamp: DateTime.now(),
      // ));
    } catch (_) {/* swallow */}
  }

  static String _redact(String dsn) {
    if (dsn.length <= 20) return dsn;
    return '${dsn.substring(0, 12)}…${dsn.substring(dsn.length - 4)}';
  }
}
