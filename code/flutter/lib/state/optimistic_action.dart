// Optimistic-update helper.
//
// Audit production-killer §7 ("Frontend micro-polish — optimistic
// updates"). Consumer apps win on feel; the largest single feel-improvement
// is collapsing the "tap → wait spinner → state changes" delay.
//
// This helper inverts the order: apply the new state locally NOW, then
// fire the server call. If the server fails, automatically rollback the
// state and surface a friendly error.
//
// Usage:
//
//     await OptimisticAction.run<bool>(
//       apply:   () { setState(() => liked = true; likeCount++; }); },
//       rollback:() { setState(() => liked = false; likeCount--; }); },
//       commit:  () => api.likePost(postId),
//       onError: (e) => showSnack(context, e.toString()),
//     );
//
// Notes:
//   - `apply` runs synchronously; the UI updates before the await.
//   - `commit` is the real server call. If it throws or returns falsy,
//     `rollback` fires and `onError` is invoked with the captured error.
//   - The helper is generic over the commit return type, so non-bool
//     calls (returning an order id, etc.) work the same.
//   - Concurrent applies are NOT batched here — wrap the call site in
//     a debounce / loading-guard if double-tap matters. The audit-flagged
//     case (like button mash) is already covered by the server-side
//     post-like race fix in posts.service.ts (createMany skipDuplicates).
//
// This is intentionally just a pattern, not a framework — no providers,
// no state-management library coupling. Drop in anywhere.

import 'package:flutter/foundation.dart';

class OptimisticActionResult<T> {
  final bool ok;
  final T? value;
  final Object? error;
  const OptimisticActionResult.success(this.value)
      : ok = true,
        error = null;
  const OptimisticActionResult.failure(this.error)
      : ok = false,
        value = null;
}

class OptimisticAction {
  OptimisticAction._();

  /// Run an optimistic action.
  ///
  /// [apply] runs first — synchronous local UI update.
  /// [commit] runs second — the real server call (await'd).
  /// [rollback] runs only if [commit] throws or its result is `false`/null
  /// (for nullable returns we don't rollback if the value is a non-null
  /// `0`, empty list, or other falsy-but-OK value — caller controls the
  /// success contract via [isSuccess]).
  static Future<OptimisticActionResult<T>> run<T>({
    required void Function() apply,
    required void Function() rollback,
    required Future<T> Function() commit,
    void Function(Object error)? onError,
    bool Function(T value)? isSuccess,
  }) async {
    // 1. Optimistically apply the new state.
    apply();

    // 2. Fire the server call.
    try {
      final result = await commit();
      final ok = isSuccess?.call(result) ?? _defaultIsSuccess(result);
      if (!ok) {
        rollback();
        if (kDebugMode) debugPrint('OptimisticAction rolled back (commit returned false): $result');
        return OptimisticActionResult.failure(StateError('commit returned non-success'));
      }
      return OptimisticActionResult.success(result);
    } catch (e, st) {
      rollback();
      if (kDebugMode) debugPrint('OptimisticAction rolled back (commit threw): $e\n$st');
      onError?.call(e);
      return OptimisticActionResult.failure(e);
    }
  }

  static bool _defaultIsSuccess(Object? v) {
    if (v == null) return false;
    if (v is bool) return v;
    return true;
  }
}
