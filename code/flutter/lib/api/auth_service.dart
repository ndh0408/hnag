import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

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

  final _storage = const FlutterSecureStorage();
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

  Future<String?> sendOtp(String phone) async {
    final r = await http.post(
      Uri.parse('$_baseUrl/v1/auth/otp/send'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone}),
    ).timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) {
      throw _httpError(r);
    }
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>? ?? {};
    return data['devCode'] as String?;
  }

  /// Send OTP to an email. Returns devCode when backend is in dev mode (no SMTP).
  Future<String?> sendEmailOtp(String email) async {
    final r = await http.post(
      Uri.parse('$_baseUrl/v1/auth/email-otp/send'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim()}),
    ).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw _httpError(r);
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>? ?? {};
    return data['devCode'] as String?;
  }

  Future<bool> verifyEmailOtp(String email, String code) async {
    final r = await http.post(
      Uri.parse('$_baseUrl/v1/auth/email-otp/verify'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim(),
        'code': code,
        'device': {
          'deviceId': _deviceId,
          'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        },
      }),
    ).timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) {
      if (r.statusCode == 401) return false;
      throw _httpError(r);
    }
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    await _persistTokens(
      access: data['accessToken'] as String,
      refresh: data['refreshToken'] as String,
      user: AuthUser.fromJson(data['user'] as Map<String, dynamic>),
    );
    return true;
  }

  Future<bool> verifyOtp(String phone, String code) async {
    final r = await http.post(
      Uri.parse('$_baseUrl/v1/auth/otp/verify'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'code': code,
        'device': {
          'deviceId': _deviceId,
          'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        },
      }),
    ).timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) {
      if (r.statusCode == 401) return false;
      throw _httpError(r);
    }
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    await _persistTokens(
      access: data['accessToken'] as String,
      refresh: data['refreshToken'] as String,
      user: AuthUser.fromJson(data['user'] as Map<String, dynamic>),
    );
    return true;
  }

  Future<bool> _validateOrRefresh() async {
    if (_refreshToken == null) return _accessToken != null;
    try {
      final r = await http.post(
        Uri.parse('$_baseUrl/v1/auth/refresh'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': _refreshToken}),
      ).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return false;
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
  }

  Future<void> signOut() async {
    _accessToken = null;
    _refreshToken = null;
    _user = null;
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kUser);
    _userController.add(null);
  }

  static const _kOnboarded = 'hnag_onboarded';
  Future<bool> isOnboarded() async => (await _storage.read(key: _kOnboarded)) == '1';
  Future<void> setOnboarded() async => _storage.write(key: _kOnboarded, value: '1');

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

  Exception _httpError(http.Response r) {
    try {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final err = body['error'] as Map<String, dynamic>?;
      return Exception(err?['message'] ?? 'HTTP ${r.statusCode}');
    } catch (_) {
      return Exception('HTTP ${r.statusCode}');
    }
  }
}
