import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'auth_service.dart';

/// Connects to the HNAG realtime gateway (Socket.IO) for live group polls.
///
/// Audit workflow-trace §7/§8: the ack from `subscribe:group` was ignored
/// (server returns `{ok:false, error:'not_a_member'|'rate_limited'}` on
/// failure). Now we surface errors via [errors] stream and stop hammering
/// the gateway on permanent failure.
class GroupRealtime {
  static const _wsUrl = 'https://api.tothanhthuy.cloud';
  io.Socket? _socket;
  bool _disposed = false;
  String? _pendingGroupId;
  String? _lastSubscribeError;

  final _pollUpdates = StreamController<({String pollId, List<int> tally})>.broadcast();
  Stream<({String pollId, List<int> tally})> get pollUpdates => _pollUpdates.stream;

  final _memberJoined = StreamController<String>.broadcast();
  Stream<String> get memberJoined => _memberJoined.stream;

  final _errors = StreamController<String>.broadcast();
  Stream<String> get errors => _errors.stream;
  String? get lastSubscribeError => _lastSubscribeError;

  void connect(String groupId) {
    final token = AuthService.instance.accessToken;
    if (token == null) {
      _errors.add('not_signed_in');
      return;
    }
    _pendingGroupId = groupId;
    _socket = io.io(_wsUrl, io.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .setAuth({'token': token})
        .build());

    _socket!.onConnect((_) {
      final gid = _pendingGroupId;
      if (gid == null) return;
      // Use ack callback to detect server-side rejection (not_a_member,
      // rate_limited, bad_request). socket_io_client supports a final
      // function arg as the ack callback.
      _socket!.emitWithAck('subscribe:group', {'groupId': gid}, ack: (data) {
        try {
          final ok = (data is Map) ? (data['ok'] as bool? ?? false) : false;
          if (!ok) {
            final err = (data is Map) ? (data['error'] as String? ?? 'unknown') : 'unknown';
            _lastSubscribeError = err;
            _errors.add(err);
            // Permanent rejection — don't keep reconnecting against a wall.
            if (err == 'not_a_member' || err == 'bad_request') {
              _pendingGroupId = null;
              _socket?.dispose();
            }
          } else {
            _lastSubscribeError = null;
          }
        } catch (e) {
          if (kDebugMode) debugPrint('subscribe ack parse error: $e');
        }
      });
    });
    _socket!.on('group.poll.updated', (data) {
      try {
        final pollId = data['pollId'] as String;
        final tally = ((data['tally'] as List?) ?? []).cast<int>();
        _pollUpdates.add((pollId: pollId, tally: tally));
      } catch (_) {}
    });
    _socket!.on('group.member.joined', (data) {
      try { _memberJoined.add(data['userId'] as String); } catch (_) {}
    });
    _socket!.onDisconnect((_) {
      if (kDebugMode) debugPrint('GroupRealtime disconnected (will auto-reconnect)');
    });
    _socket!.onConnectError((err) {
      _errors.add('connect_error: $err');
    });
    _socket!.connect();
  }

  void dispose() {
    _disposed = true;
    _pendingGroupId = null;
    _socket?.dispose();
    _pollUpdates.close();
    _memberJoined.close();
    _errors.close();
  }
}
