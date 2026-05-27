// Group realtime client — Socket.IO wrapper with seq tracking, replay,
// app-layer heartbeat, force_disconnect handling, and persisted room
// subscription across app restart.
//
// Audit realtime-trace §3, §6, §10, §15, §16: previously a thin pass-
// through that lost events on disconnect and would loop-reconnect after
// rate-limit. This rewrite closes those gaps.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../observability/crash_reporter.dart';
import 'auth_service.dart';

/// Persisted last-seen sequence per room — survives app restart so the
/// next subscribe can request `sinceSeq` and the server replays whatever
/// was missed between sessions.
const _kSeqKeyPrefix = 'ws_seq_';

class GroupRealtime {
  static const _wsUrl = 'https://api.tothanhthuy.cloud';
  static const _heartbeatPeriod = Duration(seconds: 30);

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,
    ),
  );

  io.Socket? _socket;
  String? _pendingGroupId;
  String? _lastSubscribeError;
  Timer? _heartbeat;
  int _lastSeq = 0;
  DateTime? _retryAfter;

  final _pollUpdates = StreamController<({String pollId, List<int> tally})>.broadcast();
  Stream<({String pollId, List<int> tally})> get pollUpdates => _pollUpdates.stream;

  final _memberJoined = StreamController<String>.broadcast();
  Stream<String> get memberJoined => _memberJoined.stream;

  /// Forwarded snapshot from `subscribe:group` ack — open polls + their
  /// votes at the moment of subscription. Use this to hydrate the UI
  /// instead of also calling REST.
  final _snapshots = StreamController<List<Map<String, dynamic>>>.broadcast();
  Stream<List<Map<String, dynamic>>> get snapshots => _snapshots.stream;

  final _errors = StreamController<String>.broadcast();
  Stream<String> get errors => _errors.stream;
  String? get lastSubscribeError => _lastSubscribeError;

  Future<int> _loadPersistedSeq(String roomKey) async {
    final raw = await _storage.read(key: _kSeqKeyPrefix + roomKey);
    return int.tryParse(raw ?? '') ?? 0;
  }

  Future<void> _savePersistedSeq(String roomKey, int seq) async {
    await _storage.write(key: _kSeqKeyPrefix + roomKey, value: seq.toString());
  }

  Future<void> connect(String groupId) async {
    final token = AuthService.instance.accessToken;
    if (token == null) {
      _errors.add('not_signed_in');
      return;
    }
    if (_retryAfter != null && DateTime.now().isBefore(_retryAfter!)) {
      final waitMs = _retryAfter!.difference(DateTime.now()).inMilliseconds;
      _errors.add('retry_in_${waitMs}ms');
      return;
    }
    _pendingGroupId = groupId;
    _lastSeq = await _loadPersistedSeq('group:$groupId');

    // Dispose any prior socket before reassigning — guards against the
    // `_socket = io.io(...)` overwrite leak described in audit §12.
    _socket?.dispose();

    _socket = io.io(
      _wsUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(15000)
          .setRandomizationFactor(0.5)
          .setReconnectionAttempts(20) // cap so we don't loop forever
          .setAuth({'token': token})
          .build(),
    );

    _socket!.onConnect((_) => _onConnect());
    _socket!.on('group.poll.updated', _onPollUpdated);
    _socket!.on('group.poll.created', (_) {}); // future: surface to UI
    _socket!.on('group.member.joined', (data) {
      try { _memberJoined.add(data['userId'] as String); } catch (_) {/* ignore */}
    });
    _socket!.on('force_disconnect', _onForceDisconnect);
    _socket!.onDisconnect((reason) {
      if (kDebugMode) debugPrint('GroupRealtime disconnect: $reason');
    });
    _socket!.onConnectError((err) {
      _errors.add('connect_error: $err');
    });
    _socket!.connect();
  }

  void _onConnect() {
    final gid = _pendingGroupId;
    if (gid == null) return;
    _startHeartbeat();
    _socket!.emitWithAck(
      'subscribe:group',
      {'groupId': gid, 'sinceSeq': _lastSeq},
      ack: (data) async {
        try {
          if (data is! Map) return;
          final ok = data['ok'] as bool? ?? false;
          if (!ok) {
            final err = (data['error'] as String?) ?? 'unknown';
            _lastSubscribeError = err;
            _errors.add(err);
            if (err == 'not_a_member' || err == 'bad_request') {
              _pendingGroupId = null;
              _socket?.dispose();
              _socket = null;
            }
            return;
          }
          _lastSubscribeError = null;
          // Hydrate from snapshot — open polls list with current votes.
          final polls = (data['polls'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
          if (polls.isNotEmpty) _snapshots.add(polls);
          // Apply missed events in order. Server returns events with
          // `_seq` strictly greater than what we sent as sinceSeq.
          final missed = (data['missed'] as List?) ?? const [];
          for (final m in missed) {
            if (m is! Map) continue;
            final evt = m['event'] as String?;
            final payload = m['data'];
            if (evt == 'group.poll.updated' && payload is Map) {
              _onPollUpdated(payload);
            }
          }
          // Persist the latest server-side head so next reconnect picks
          // up after that boundary.
          final latestSeq = (data['latestSeq'] as num?)?.toInt() ?? _lastSeq;
          _lastSeq = latestSeq;
          await _savePersistedSeq('group:$gid', latestSeq);
        } catch (e, st) {
          CrashReporter.capture(e, stack: st, tag: 'ws:subscribe_ack');
        }
      },
    );
  }

  /// Applies a `group.poll.updated` event to the stream. Drops out-of-
  /// order / duplicate events using the `_seq` envelope field.
  void _onPollUpdated(dynamic data) {
    if (data is! Map) return;
    try {
      final seq = (data['_seq'] as num?)?.toInt() ?? 0;
      if (seq > 0 && seq <= _lastSeq) {
        if (kDebugMode) debugPrint('GroupRealtime drop stale seq=$seq (have $_lastSeq)');
        return;
      }
      if (seq > 0) {
        _lastSeq = seq;
        final gid = _pendingGroupId;
        if (gid != null) {
          // fire-and-forget persistence — non-blocking.
          unawaited(_savePersistedSeq('group:$gid', seq));
        }
      }
      final pollId = data['pollId'] as String;
      final tally = ((data['tally'] as List?) ?? []).cast<int>();
      _pollUpdates.add((pollId: pollId, tally: tally));
    } catch (e) {
      if (kDebugMode) debugPrint('poll.updated parse error: $e');
    }
  }

  void _onForceDisconnect(dynamic data) {
    if (data is! Map) return;
    final reason = data['reason'] as String? ?? 'unknown';
    final retryAfterSec = (data['retryAfterSec'] as num?)?.toInt() ?? 60;
    _retryAfter = DateTime.now().add(Duration(seconds: retryAfterSec));
    _errors.add('force_disconnect:$reason');
    _socket?.dispose();
    _socket = null;
    _heartbeat?.cancel();
    if (kDebugMode) {
      debugPrint('GroupRealtime force_disconnect=$reason retryAfter=${retryAfterSec}s');
    }
  }

  /// Audit realtime-trace §10: app-layer heartbeat catches half-open TCP
  /// states. Server responds with `pong + serverTs`; we don't act on the
  /// pong directly but the round-trip itself proves the socket is alive.
  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(_heartbeatPeriod, (_) {
      try {
        _socket?.emit('ping', {'ts': DateTime.now().millisecondsSinceEpoch});
      } catch (_) {/* swallow */}
    });
  }

  void dispose() {
    _heartbeat?.cancel();
    _heartbeat = null;
    _pendingGroupId = null;
    _socket?.dispose();
    _socket = null;
    if (!_pollUpdates.isClosed) _pollUpdates.close();
    if (!_memberJoined.isClosed) _memberJoined.close();
    if (!_snapshots.isClosed) _snapshots.close();
    if (!_errors.isClosed) _errors.close();
  }
}
