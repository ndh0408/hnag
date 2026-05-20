import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'auth_service.dart';

/// Connects to the HNAG realtime gateway (Socket.IO) for live group polls.
class GroupRealtime {
  static const _wsUrl = 'https://api.tothanhthuy.cloud';
  io.Socket? _socket;

  final _pollUpdates = StreamController<({String pollId, List<int> tally})>.broadcast();
  Stream<({String pollId, List<int> tally})> get pollUpdates => _pollUpdates.stream;

  final _memberJoined = StreamController<String>.broadcast();
  Stream<String> get memberJoined => _memberJoined.stream;

  void connect(String groupId) {
    final token = AuthService.instance.accessToken;
    if (token == null) return;
    _socket = io.io(_wsUrl, io.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .setAuth({'token': token})
        .build());

    _socket!.onConnect((_) {
      _socket!.emit('subscribe:group', {'groupId': groupId});
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
    _socket!.connect();
  }

  void dispose() {
    _socket?.dispose();
    _pollUpdates.close();
    _memberJoined.close();
  }
}
