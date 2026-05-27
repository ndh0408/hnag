// Friendly, UI-surfaceable API errors.
//
// Audit follow-up after the 2026-05-27 emulator test: the auth screens were
// rendering raw Dart exception text to the user when offline. Example seen:
//
//   "ClientException with SocketException: Failed host lookup:
//    'api.tothanhthuy.cloud' (OS Error: No address associated with hostname,
//    errno = 7), uri=https://api.tothanhthuy.cloud/v1/auth/email-otp/send"
//
// The fix is twofold:
//   1. Service classes catch `SocketException`, `ClientException`,
//      `TimeoutException`, etc. and rethrow as `ApiException` carrying a
//      short Vietnamese message + a stable `code`.
//   2. Existing UI sites that already do `_error = e.toString()` keep
//      working — `ApiException.toString()` IS the Vietnamese message.
//
// `code` is stable for client logic (`OFFLINE`, `TIMEOUT`, `RATE_LIMITED`,
// `UNAUTHORIZED`, `SERVER_ERROR`, `UPSTREAM`, `UNKNOWN`) so screens can
// branch on it without parsing text.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'resilient_client.dart';

class ApiException implements Exception {
  /// Stable machine-readable code. Use this for branching in UI logic;
  /// the message changes with copy iterations, the code does not.
  final String code;

  /// Localized message safe to surface as-is to the end user.
  final String messageVi;

  /// HTTP status when applicable (0 for network-layer failures).
  final int statusCode;

  /// Optional original cause, kept for debug builds / Sentry breadcrumbs.
  final Object? cause;

  const ApiException(this.code, this.messageVi, {this.statusCode = 0, this.cause});

  /// UIs that already do `_error = e.toString()` get a friendly Vietnamese
  /// line out-of-the-box, no refactor required.
  @override
  String toString() => messageVi;

  // ── Factories ────────────────────────────────────────────────────────

  factory ApiException.offline() => const ApiException(
        'OFFLINE',
        'Không có kết nối mạng. Vui lòng kiểm tra Wi-Fi / 4G và thử lại.',
      );

  factory ApiException.timeout() => const ApiException(
        'TIMEOUT',
        'Máy chủ trả lời chậm. Vui lòng thử lại sau ít giây.',
      );

  factory ApiException.serverDown() => const ApiException(
        'UPSTREAM',
        'Dịch vụ tạm thời gián đoạn. Vui lòng thử lại sau ít phút.',
        statusCode: 503,
      );

  factory ApiException.rateLimited() => const ApiException(
        'RATE_LIMITED',
        'Bạn thao tác hơi nhanh. Vui lòng thử lại sau 1 phút.',
        statusCode: 429,
      );

  factory ApiException.unauthorized() => const ApiException(
        'UNAUTHORIZED',
        'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.',
        statusCode: 401,
      );

  /// Map any thrown exception into the closest ApiException. Use inside a
  /// generic `catch (e)` so the caller can rethrow with friendly copy:
  ///
  ///     try { await http.post(...); }
  ///     on ApiException { rethrow; }
  ///     catch (e) { throw ApiException.from(e); }
  static ApiException from(Object e) {
    if (e is ApiException) return e;
    if (e is SocketException) return ApiException.offline();
    if (e is TimeoutException) return ApiException.timeout();
    if (e is http.ClientException) {
      final msg = e.message.toLowerCase();
      if (msg.contains('failed host lookup') || msg.contains('socketexception')) {
        return ApiException.offline();
      }
      if (msg.contains('connection') && msg.contains('refused')) {
        return ApiException.serverDown();
      }
      return ApiException('NETWORK', 'Lỗi kết nối: ${_short(e.message)}', cause: e);
    }
    if (e is ResilientHttpError) {
      if (e.statusCode == 503 && e.code == 'CIRCUIT_OPEN') return ApiException.serverDown();
      if (e.statusCode >= 500) return ApiException.serverDown();
      if (e.statusCode == 429) return ApiException.rateLimited();
      if (e.statusCode == 401) return ApiException.unauthorized();
    }
    return ApiException('UNKNOWN', 'Có lỗi xảy ra. Vui lòng thử lại.', cause: e);
  }

  /// Build an ApiException from an HTTP response body (`{ error: { code, message } }`).
  /// Falls back to status-based default when the body isn't JSON.
  static ApiException fromResponse(http.Response r) {
    final status = r.statusCode;
    try {
      if (r.body.isNotEmpty && r.body.startsWith('{')) {
        final json = jsonDecode(r.body);
        if (json is Map) {
          // HNAG backend wraps errors as `{ error: { code, message } }` or
          // sometimes `{ code, message }` at the top level. Accept both.
          final err = json['error'] is Map ? json['error'] as Map : json;
          final code = (err['code'] as String?) ?? 'HTTP_$status';
          final msg = (err['message'] as String?) ?? _byStatus(status).messageVi;
          return ApiException(code, msg, statusCode: status);
        }
      }
    } catch (_) {/* fall through */}
    return _byStatus(status);
  }

  static ApiException _byStatus(int status) {
    if (status == 401) return ApiException.unauthorized();
    if (status == 429) return ApiException.rateLimited();
    if (status >= 500) return ApiException.serverDown();
    if (status == 0) return ApiException.offline();
    return ApiException('HTTP_$status', 'Yêu cầu thất bại (HTTP $status). Vui lòng thử lại.', statusCode: status);
  }

  static String _short(String s) => s.length > 80 ? '${s.substring(0, 80)}…' : s;
}
