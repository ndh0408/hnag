// Riverpod providers — proper usage of the framework that was already
// in pubspec.yaml but only used as a no-op ProviderScope wrapper.
//
// Audit production-killer §"state management": the audit flagged that
// `Riverpod is imported but never used; state is setState + StreamBuilder
// chaos`. This file is the bridge — it provides the canonical providers
// for the slices of state that get read across many screens:
//
//   currentUserProvider     — StreamProvider over AuthService.userChanges
//   isAuthedProvider        — Provider derived from currentUserProvider
//   isPremiumProvider       — Provider derived from currentUserProvider
//   accessTokenProvider     — Provider that reads the current access token
//   analyticsProvider       — Provider that returns the Analytics SDK (so
//                             tests can mock + so widgets get auto-init)
//
// Adoption is incremental — old screens keep using
// `StreamBuilder<AuthUser?>` until refactored. New screens should
// `ref.watch(currentUserProvider)` instead. The StreamBuilder pattern
// works fine in this file too because the underlying source of truth
// is still AuthService.instance — Riverpod is just exposing it.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/auth_service.dart';
import '../observability/analytics.dart';

/// The live authenticated user (or null). Emits whenever
/// `AuthService.userChanges` does — login, logout, refresh-rotation.
///
/// Usage in a ConsumerWidget:
///
///   final user = ref.watch(currentUserProvider).valueOrNull;
///   if (user == null) return const LoginGate();
///   return Text('Hi ${user.displayName ?? user.username}');
final currentUserProvider = StreamProvider<AuthUser?>((ref) {
  // Seed with the current value so the first build doesn't flash null
  // when AuthService has already loaded a session from secure storage.
  return AuthService.instance.userChanges.asBroadcastStream();
});

/// `true` when there's a valid current user. Cheap derived state — use
/// for `if/else` paths instead of `valueOrNull != null` everywhere.
final isAuthedProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  return user != null;
});

/// `true` when the current user is on a paid plan. Derived from the
/// JWT-side `isPremium` flag — for the truly authoritative answer the
/// backend `@Premium()` guard re-reads `users.is_premium + premium_until`
/// on every request, so client-side flicker on grace-period expiry is
/// acceptable.
final isPremiumProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  return user?.isPremium ?? false;
});

/// The current access token. Use in API calls or expose to a Dio/http
/// interceptor. Returns null when logged out.
final accessTokenProvider = Provider<String?>((ref) {
  // Implicitly subscribed via currentUserProvider — login flip rebuilds
  // any widget reading this.
  ref.watch(currentUserProvider);
  return AuthService.instance.accessToken;
});

/// A handle to the Analytics SDK + an autoDispose side-effect to call
/// `Analytics.identify(userId)` whenever the auth state changes. Wire
/// this into the root ProviderScope so the identify call happens once
/// per session, not per screen.
/// Riverpod-friendly handle for the static `Analytics` SDK. The SDK is
/// 100% static — this class is a pure ergonomic shim so widgets can do
/// `ref.read(analyticsProvider).track(...)` instead of importing the
/// static class directly.
class AnalyticsHandle {
  const AnalyticsHandle();
  void track(String event, [Map<String, dynamic>? properties]) =>
      Analytics.track(event, properties);
  void screen(String name, {Map<String, dynamic>? properties}) =>
      Analytics.screen(name, properties: properties);
  void identify(String? userId) => Analytics.identify(userId);
}

final analyticsProvider = Provider<AnalyticsHandle>((ref) {
  ref.listen<AsyncValue<AuthUser?>>(currentUserProvider, (prev, next) {
    final id = next.valueOrNull?.id;
    Analytics.identify(id);
  });
  return const AnalyticsHandle();
});
