// Resilient HTTP client wrapper.
//
// Audit hnag-audit-2026-05 §5-Flutter / §B-21: every API call in hnag_api.dart
// uses the raw `http` package with a single timeout and no retry. A flaky
// 3G burst kills the request entirely; the user sees a generic "không tải
// được" toast and bounces. This wrapper adds:
//
//   * deterministic timeout per call (default 10s; AI calls override)
//   * exponential backoff with jitter on idempotent verbs (GET / HEAD)
//   * a simple per-host circuit breaker — if 5 consecutive calls to a
//     host fail, future calls are short-circuited for 30s, sparing the
//     server from a downward spiral and the UI from a long wait stall
//   * structured logging so we can attribute failures
//
// Idempotency note: POST is NOT auto-retried by default. The caller can
// opt in via `idempotent: true` when paired with an Idempotency-Key
// header — see audit Week-3 fix on /v1/orders/intent.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ResilientHttpError implements Exception {
  final int statusCode;
  final String message;
  final String? code;
  ResilientHttpError(this.statusCode, this.message, {this.code});
  @override
  String toString() => 'HTTP $statusCode: $message${code != null ? ' (code=$code)' : ''}';
}

class _CircuitState {
  int consecutiveFailures = 0;
  DateTime? openUntil;
}

class ResilientClient {
  ResilientClient({
    http.Client? inner,
    this.defaultTimeout = const Duration(seconds: 10),
    this.maxAttempts = 3,
    this.circuitBreakerThreshold = 5,
    this.circuitBreakerCooldown = const Duration(seconds: 30),
  }) : _inner = inner ?? http.Client();

  final http.Client _inner;
  final Duration defaultTimeout;
  final int maxAttempts;
  final int circuitBreakerThreshold;
  final Duration circuitBreakerCooldown;
  final Map<String, _CircuitState> _circuits = {};
  final Random _rng = Random();

  Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) {
    return _send('GET', url, headers: headers, timeout: timeout, idempotent: true);
  }

  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
    bool idempotent = false,
  }) {
    return _send('POST', url, headers: headers, body: body, timeout: timeout, idempotent: idempotent);
  }

  Future<http.Response> _send(
    String method,
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
    bool idempotent = false,
  }) async {
    final host = url.host;
    _assertCircuitClosed(host);

    final effectiveTimeout = timeout ?? defaultTimeout;
    final attempts = idempotent ? maxAttempts : 1;
    Object? lastErr;

    for (int attempt = 1; attempt <= attempts; attempt++) {
      try {
        final req = http.Request(method, url);
        if (headers != null) req.headers.addAll(headers);
        if (body != null) {
          if (body is String) {
            req.body = body;
          } else if (body is Map || body is List) {
            req.headers.putIfAbsent('Content-Type', () => 'application/json');
            req.body = jsonEncode(body);
          } else {
            req.body = body.toString();
          }
        }
        final streamed = await _inner.send(req).timeout(effectiveTimeout);
        final res = await http.Response.fromStream(streamed);
        if (res.statusCode >= 500) {
          throw ResilientHttpError(res.statusCode, 'Upstream ${res.statusCode}');
        }
        _onSuccess(host);
        return res;
      } catch (e) {
        lastErr = e;
        // Don't retry 4xx — those are deterministic. _send catches its own
        // ResilientHttpError only for 5xx (thrown above).
        final fatal = e is ResilientHttpError && e.statusCode < 500;
        if (fatal || attempt == attempts) {
          _onFailure(host);
          if (kDebugMode) debugPrint('ResilientClient $method $url failed after $attempt: $e');
          rethrow;
        }
        await _backoff(attempt);
      }
    }
    // Unreachable, but keep the type-checker happy.
    throw lastErr ?? StateError('ResilientClient: exhausted attempts');
  }

  Future<void> _backoff(int attempt) async {
    // 200ms × 2^(attempt-1) + jitter — caps at 1.6s for attempt=4
    final base = 200 * (1 << (attempt - 1));
    final jitter = _rng.nextInt(150);
    await Future.delayed(Duration(milliseconds: base + jitter));
  }

  void _assertCircuitClosed(String host) {
    final c = _circuits[host];
    if (c?.openUntil != null && c!.openUntil!.isAfter(DateTime.now())) {
      throw ResilientHttpError(
        503,
        'Dịch vụ tạm thời gián đoạn, thử lại sau ít phút.',
        code: 'CIRCUIT_OPEN',
      );
    }
  }

  void _onSuccess(String host) {
    final c = _circuits[host];
    if (c != null) {
      c.consecutiveFailures = 0;
      c.openUntil = null;
    }
  }

  void _onFailure(String host) {
    final c = _circuits.putIfAbsent(host, () => _CircuitState());
    c.consecutiveFailures += 1;
    if (c.consecutiveFailures >= circuitBreakerThreshold) {
      c.openUntil = DateTime.now().add(circuitBreakerCooldown);
      if (kDebugMode) debugPrint('ResilientClient circuit OPEN for $host until ${c.openUntil}');
    }
  }
}
