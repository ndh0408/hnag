// Front-end crash reporting — REAL Sentry wiring.
//
// Activated 2026-05-27 audit follow-up: package:sentry_flutter is now in
// pubspec; the previous stub (debugPrint only) is gone. Set the DSN at
// build time:
//
//   flutter build apk --dart-define=SENTRY_DSN=https://<key>@<org>.ingest.sentry.io/<project> \
//                     --dart-define=SENTRY_RELEASE=hnag@$(git rev-parse --short HEAD) \
//                     --dart-define=SENTRY_ENVIRONMENT=production
//
// When SENTRY_DSN is empty (e.g. dev builds), the reporter degrades to
// debugPrint cleanly — no silent black-hole.

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

const _sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');
const _release = String.fromEnvironment('SENTRY_RELEASE', defaultValue: 'hnag@dev');
const _environment = String.fromEnvironment('SENTRY_ENVIRONMENT', defaultValue: 'development');

class CrashReporter {
  CrashReporter._();

  static bool _active = false;

  /// Initialize. Returns once Sentry has loaded. Non-throwing — a
  /// misconfigured DSN must never block app boot.
  static Future<void> init() async {
    if (_sentryDsn.isEmpty) {
      if (kDebugMode) debugPrint('CrashReporter: SENTRY_DSN empty, skipping init');
      return;
    }
    try {
      await SentryFlutter.init((options) {
        options.dsn = _sentryDsn;
        options.release = _release;
        options.environment = _environment;
        // 10% sampling on traces — enough to spot p95 blowups without
        // breaking the bank on a free-tier project.
        options.tracesSampleRate = 0.1;
        // Skip debug-mode errors (would flood Sentry on hot reload).
        options.beforeSend = (event, hint) => kDebugMode ? null : event;
        // Always attach screenshots + view hierarchy on crash for
        // UI-state postmortem.
        options.attachScreenshot = true;
        options.attachViewHierarchy = true;
      });
      _active = true;
      if (kDebugMode) debugPrint('CrashReporter: ready (release=$_release env=$_environment)');
    } catch (e) {
      if (kDebugMode) debugPrint('CrashReporter: init failed: $e');
    }
  }

  /// Wire framework error handlers. Call once from `main()` after `init`.
  /// SentryFlutter.init already installs handlers internally; this is the
  /// belt-and-braces pre-wrap for any handler that ran before init.
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
      Sentry.captureException(
        error,
        stackTrace: stack,
        hint: tag != null ? Hint.withMap({'tag': tag}) : null,
      );
    } catch (_) {/* telemetry must never crash the app */}
  }

  /// Tag a non-error breadcrumb (route changes, deep links, queue depth).
  static void breadcrumb(String message, {String? category, Map<String, Object?>? data}) {
    if (!_active) return;
    try {
      Sentry.addBreadcrumb(Breadcrumb(
        message: message,
        category: category,
        data: data,
        timestamp: DateTime.now(),
      ));
    } catch (_) {/* swallow */}
  }

  /// Attach user identity for crash grouping. Called from AuthService on
  /// session ingest / sign-out.
  static void identify(String? userId, {String? email}) {
    if (!_active) return;
    try {
      if (userId == null) {
        Sentry.configureScope((scope) => scope.setUser(null));
      } else {
        Sentry.configureScope((scope) => scope.setUser(SentryUser(id: userId, email: email)));
      }
    } catch (_) {/* swallow */}
  }
}
