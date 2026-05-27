import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:synchronized/synchronized.dart';
import 'package:uuid/uuid.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../observability/crash_reporter.dart';
import 'api_exception.dart';

class AuthUser {
  final String id;
  final String username;
  final String? displayName;
  final bool isPremium;
  const AuthUser({required this.id, required this.username, this.displayName, this.isPremium = false});
  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: j['id'] as String,
        username: (j['username'] as String?) ?? 'foodie',
        displayName: j['displayName'] as String?,
        isPremium: (j['isPremium'] as bool?) ?? false,
      );
}

class AuthService {
  static const _baseUrl = 'https://api.tothanhthuy.cloud';
  static const _kAccess = 'hnag_access';
  static const _kRefresh = 'hnag_refresh';
  static const _kDevice = 'hnag_device_id';
  static const _kUser = 'hnag_user';

  static final AuthService instance = AuthService._();
  AuthService._();

  /// Audit #7: lock iOS Keychain storage to `first_unlock_this_device` +
  /// no iCloud sync. The defaults (`whenUnlocked` + sync) include refresh
  /// tokens in iCloud Keychain backup, so an attacker restoring a stolen
  /// iPhone backup onto a new device inherits the user's logged-in session.
  /// Android uses EncryptedSharedPreferences (Keystore-backed), which is
  /// already device-bound by default.
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,
    ),
  );
  final _userController = StreamController<AuthUser?>.broadcast();
  AuthUser? _user;
  String? _accessToken;
  String? _refreshToken;
  String? _deviceId;

  Stream<AuthUser?> get userChanges => _userController.stream;
  AuthUser? get currentUser => _user;
  String? get accessToken => _accessToken;
  bool get isAuthed => _accessToken != null && _user != null;

  Future<void> init() async {
    _accessToken = await _storage.read(key: _kAccess);
    _refreshToken = await _storage.read(key: _kRefresh);
    _deviceId = await _storage.read(key: _kDevice);
    final userJson = await _storage.read(key: _kUser);
    if (userJson != null) {
      try { _user = AuthUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>); } catch (_) {}
    }
    if (_deviceId == null) {
      _deviceId = const Uuid().v4();
      await _storage.write(key: _kDevice, value: _deviceId);
    }
    if (_user != null && _accessToken != null) {
      // Verify token still works; refresh if needed.
      final ok = await _validateOrRefresh();
      if (!ok) await signOut();
    }
    _userController.add(_user);
  }

  /// Send a 6-digit login code to [email]. Throws `ApiException` on failure
  /// — the message is user-safe Vietnamese, so UI sites can do
  /// `_error = e.toString()` and surface it as-is.
  Future<void> sendEmailOtp(String email) async {
    final r = await _safePost(
      '/v1/auth/email-otp/send',
      body: {'email': email.trim()},
      timeout: const Duration(seconds: 15),
    );
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
  }

  /// Verify the emailed code and persist the returned tokens.
  /// Returns false when the code is wrong/expired (401).
  /// Throws `ApiException` on network / server failure.
  Future<bool> verifyEmailOtp(String email, String code) async {
    final r = await _safePost(
      '/v1/auth/email-otp/verify',
      body: {
        'email': email.trim(),
        'code': code,
        'device': _deviceInfo(),
      },
      timeout: const Duration(seconds: 12),
    );
    if (r.statusCode == 401) return false;
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return _ingestSession(r);
  }

  /// Verify a phone OTP, persist tokens. Same contract as [verifyEmailOtp].
  Future<bool> verifyPhoneOtp(String phone, String code) async {
    final r = await _safePost(
      '/v1/auth/phone-otp/verify',
      body: {
        'phone': phone.trim(),
        'code': code,
        'device': _deviceInfo(),
      },
      timeout: const Duration(seconds: 12),
    );
    if (r.statusCode == 401) return false;
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return _ingestSession(r);
  }

  /// Sign in with Apple. Returns true on success, false on user cancel or
  /// any failure. Network failures are swallowed (caller doesn't get to
  /// distinguish "user pressed Cancel" from "DNS down"). UI surfacing
  /// the failure should show a generic "Đăng nhập Apple thất bại" toast.
  Future<bool> signInWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      );
      final idToken = credential.identityToken;
      if (idToken == null) return false;
      final r = await _safePost(
        '/v1/auth/apple',
        body: {
          'identityToken': idToken,
          if (credential.authorizationCode != null) 'authorizationCode': credential.authorizationCode,
          if (credential.givenName != null || credential.familyName != null)
            'fullName': '${credential.givenName ?? ''} ${credential.familyName ?? ''}'.trim(),
          if (credential.email != null) 'email': credential.email,
          'device': _deviceInfo(),
        },
        timeout: const Duration(seconds: 15),
      );
      if (r.statusCode != 200 && r.statusCode != 201) return false;
      return _ingestSession(r);
    } on ApiException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _deviceInfo() => {
        'deviceId': _deviceId,
        'platform': kIsWeb
            ? 'web'
            : (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android'),
        'appVersion': '1.0.0',
        'osVersion': '',
        'locale': 'vi-VN',
      };

  /// Mutex over `_validateOrRefresh` so two parallel callers on cold start
  /// (e.g. `init()` + a tab-init API call hitting 401) don't both POST
  /// `/v1/auth/refresh`. The first one consumes the refresh token, the
  /// second sees `revoked_at` set → backend revokes the WHOLE family →
  /// user kicked out. Audit workflow-trace §4.
  final Lock _refreshLock = Lock();

  Future<bool> _validateOrRefresh() async {
    if (_refreshToken == null) return _accessToken != null;
    return _refreshLock.synchronized<bool>(() async {
      // Re-check inside the critical section: if a peer just finished
      // refreshing, our cached _accessToken is fresh now → no need to fire
      // another refresh.
      final tokenAtStart = _refreshToken;
      try {
        final r = await _safePost(
          '/v1/auth/refresh',
          body: {'refreshToken': tokenAtStart},
          timeout: const Duration(seconds: 8),
        );
        if (r.statusCode != 200) return false;
        return _ingestSession(r);
      } on ApiException catch (e) {
        // Hot-start ran with no network → keep the cached session intact so
        // the user isn't kicked back to login on a momentary signal drop.
        if (e.code == 'OFFLINE' || e.code == 'TIMEOUT') return true;
        return false;
      } catch (e, st) {
        CrashReporter.capture(e, stack: st, tag: 'auth:refresh');
        return false;
      }
    });
  }

  Future<void> _persistTokens({required String access, required String refresh, required AuthUser user}) async {
    _accessToken = access;
    _refreshToken = refresh;
    _user = user;
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
    await _storage.write(key: _kUser, value: jsonEncode({
      'id': user.id, 'username': user.username,
      'displayName': user.displayName, 'isPremium': user.isPremium,
    }));
    _userController.add(_user);
    // Wire Sentry user scope so crashes attach to the signed-in identity.
    CrashReporter.identify(user.id);
  }

  Future<void> signOut() async {
    _accessToken = null;
    _refreshToken = null;
    _user = null;
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kUser);
    _userController.add(null);
    CrashReporter.identify(null);
  }

  static const _kOnboarded = 'hnag_onboarded';
  static const _kWelcomeDone = 'hnag_welcome_done';
  Future<bool> isOnboarded() async => (await _storage.read(key: _kOnboarded)) == '1';
  Future<void> setOnboarded() async => _storage.write(key: _kOnboarded, value: '1');

  /// Whether the user has already passed the welcome + permissions
  /// pre-auth screens. Audit workflow-trace §2: previously local-only,
  /// every cold boot re-showed the welcome flow.
  Future<bool> isWelcomeDone() async => (await _storage.read(key: _kWelcomeDone)) == '1';
  Future<void> setWelcomeDone() async => _storage.write(key: _kWelcomeDone, value: '1');

  /// Fire-and-forget refresh used by `_Boot` on app resume after a long
  /// background. Audit workflow-trace §15. Goes through the same mutex
  /// as on-demand refresh so it can't race with an in-flight API retry.
  Future<void> proactiveRefresh() async {
    try { await _validateOrRefresh(); } catch (_) {/* best-effort */}
  }

  Map<String, String> authHeaders() {
    if (_accessToken == null) return const {};
    return {'Authorization': 'Bearer $_accessToken'};
  }

  /// Wraps an authenticated request and auto-refreshes on 401 once.
  Future<http.Response> authedRequest(Future<http.Response> Function(Map<String, String> headers) call) async {
    var r = await call(authHeaders());
    if (r.statusCode == 401 && _refreshToken != null) {
      final ok = await _validateOrRefresh();
      if (ok) r = await call(authHeaders());
    }
    return r;
  }

  // ── Internal helpers ────────────────────────────────────────────────

  /// POST JSON to the API and translate every transport-layer failure into
  /// a user-friendly `ApiException`. Callers can inspect `.code` for branch
  /// logic and surface `.toString()` directly to the UI.
  ///
  /// Audit follow-up (2026-05-27 emulator test): the previous bare
  /// `http.post(...).timeout(...)` chain rethrew `SocketException` /
  /// `ClientException` / `TimeoutException` raw — and the screens did
  /// `_error = e.toString()`, so the user saw "ClientException with
  /// SocketException: Failed host lookup: 'api.tothanhthuy.cloud' …".
  Future<http.Response> _safePost(
    String path, {
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 15),
    Map<String, String>? headers,
  }) async {
    try {
      return await http
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: {
              'Content-Type': 'application/json',
              ...?headers,
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  /// Parses a 2xx auth response, persists tokens + user, returns true.
  /// Returns false (without throwing) when the response shape is unexpected
  /// — the controller already verified status==200 before calling this.
  Future<bool> _ingestSession(http.Response r) async {
    try {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>;
      await _persistTokens(
        access: data['accessToken'] as String,
        refresh: data['refreshToken'] as String,
        user: AuthUser.fromJson(data['user'] as Map<String, dynamic>),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
