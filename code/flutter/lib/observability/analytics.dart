// Front-end product analytics.
//
// Audit production-killer §6 ("event-driven analytics"). Backend already
// has `analytics_events` table + `AnalyticsService` writing
// `ai:suggest` / `order:intent` / `auth:otp_*`. Those cover server-side
// events. Front-end events (app_open, screen_view, swipe_skip,
// onboarding step, deep_link_open) only exist if Flutter posts them up.
//
// This SDK provides:
//   - `Analytics.track(name, properties)` — non-blocking; batched +
//     buffered to survive offline / app-background.
//   - `Analytics.screen(name)` — auto-name from route observer.
//   - `Analytics.identify(userId)` — attach the current session so
//     events have a stable join key.
//   - In-memory buffer (max 50) + 10s flush + at-most-50-per-batch
//     drain → POST /v1/analytics/batch.
//
// Why a custom layer instead of a vendor SDK like PostHog Flutter:
//   - Our backend already has the storage + admin view; sending the
//     same events to a third party just doubles cost.
//   - We can route events to PostHog server-side later via Kafka /
//     queue if a real funnel tool is needed.
//   - Zero new deps; debug build prints to console so devs see events
//     locally without a dashboard.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../api/auth_service.dart';

class _AnalyticsEvent {
  final String event;
  final Map<String, dynamic> properties;
  final DateTime occurredAt;
  _AnalyticsEvent(this.event, this.properties) : occurredAt = DateTime.now();

  Map<String, dynamic> toJson() => {
        'event': event,
        'properties': properties,
        'occurredAt': occurredAt.toIso8601String(),
      };
}

class Analytics {
  Analytics._();

  static const _baseUrl = 'https://api.tothanhthuy.cloud';
  static const _maxBuffer = 50;
  static const _flushInterval = Duration(seconds: 10);

  static final List<_AnalyticsEvent> _buffer = [];
  static Timer? _flushTimer;
  static String? _userId;
  static bool _enabled = true;

  /// One-time init from main(). Starts the periodic flush timer.
  static void init() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(_flushInterval, (_) => _flush());
  }

  /// Disable analytics entirely (settings toggle / test environment).
  static void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  /// Attach the authenticated userId to every subsequent event.
  static void identify(String? userId) {
    _userId = userId;
  }

  /// Track a generic event. Non-blocking — appends to buffer, returns
  /// immediately. Errors are dropped (analytics must never break the app).
  static void track(String event, [Map<String, dynamic>? properties]) {
    if (!_enabled) return;
    if (event.isEmpty) return;
    final props = <String, dynamic>{
      ...?properties,
      if (_userId != null) 'userId': _userId,
      'platform': defaultTargetPlatform.name,
      'appVersion': '1.0.0',
    };
    _buffer.add(_AnalyticsEvent(event, props));
    if (kDebugMode) debugPrint('Analytics: $event ${props.isEmpty ? '' : props}');
    if (_buffer.length >= _maxBuffer) _flush();
  }

  /// Convenience for screen-view events. Use with the NavigatorObserver
  /// below for automatic capture.
  static void screen(String name, {Map<String, dynamic>? properties}) {
    track('screen:view', {'screen': name, ...?properties});
  }

  /// Drain the buffer to the backend. Idempotent on retry: even if the
  /// POST partially succeeds, replaying the same batch is OK (server
  /// stores by surrogate id, no client-driven dedup needed at this stage).
  static Future<void> _flush() async {
    if (_buffer.isEmpty) return;
    final batch = _buffer.take(_maxBuffer).toList();
    _buffer.removeRange(0, batch.length);
    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      headers.addAll(AuthService.instance.authHeaders());
      await http
          .post(
            Uri.parse('$_baseUrl/v1/analytics/batch'),
            headers: headers,
            body: jsonEncode({'events': batch.map((e) => e.toJson()).toList()}),
          )
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      // On failure, push events back to the head — they'll retry on
      // the next flush. Don't refill if buffer already overflowed.
      final reinsertCount = (_maxBuffer - _buffer.length).clamp(0, batch.length);
      if (reinsertCount > 0) {
        _buffer.insertAll(0, batch.take(reinsertCount));
      }
      if (kDebugMode) debugPrint('Analytics flush failed: $e');
    }
  }
}

/// NavigatorObserver that auto-emits `screen:view` events on every
/// route push. Wire into MaterialApp.navigatorObservers.
class AnalyticsRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    if (name != null && name.isNotEmpty) Analytics.screen(name);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final name = newRoute?.settings.name;
    if (name != null && name.isNotEmpty) Analytics.screen(name);
  }
}
