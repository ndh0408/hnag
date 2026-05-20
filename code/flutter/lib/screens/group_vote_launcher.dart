import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../api/hnag_api.dart';
import '../api/group_realtime.dart';
import 'group_voting_screen.dart';

/// Sets up a real group + poll from AI-suggested foods, connects WebSocket,
/// then renders GroupVotingScreen backed by live tally updates.
class GroupVoteLauncher extends StatefulWidget {
  const GroupVoteLauncher({super.key});

  @override
  State<GroupVoteLauncher> createState() => _GroupVoteLauncherState();
}

class _GroupVoteLauncherState extends State<GroupVoteLauncher> {
  final _api = HnagApi();
  final _rt = GroupRealtime();
  final _controller = StreamController<List<PollOption>>.broadcast();

  String? _groupId;
  String? _pollId;
  String? _inviteCode;
  List<Map<String, dynamic>> _foods = [];
  List<int> _tally = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    try {
      // 1. Random foods as poll options
      final foods = await _api.aiRandom(n: 4);
      if (foods.length < 2) {
        setState(() { _error = 'Không tải được món để vote'; _loading = false; });
        return;
      }
      _foods = foods;

      // 2. Create group + poll
      final group = await _api.createGroup('Nhóm ăn ${DateTime.now().hour}h');
      if (group == null) { setState(() { _error = 'Không tạo được nhóm'; _loading = false; }); return; }
      _groupId = group['id'] as String;
      _inviteCode = group['invite_code'] as String?;

      final ids = foods.map((f) => f['id'] as String).toList();
      final poll = await _api.createPoll(_groupId!, ids, closesInMinutes: 30);
      if (poll == null) { setState(() { _error = 'Không tạo được poll'; _loading = false; }); return; }
      _pollId = poll['id'] as String;
      _tally = List.filled(foods.length, 0);

      // 3. Connect WS for live updates
      _rt.connect(_groupId!);
      _rt.pollUpdates.listen((u) {
        if (u.pollId == _pollId) {
          _tally = u.tally;
          _emit();
        }
      });

      setState(() => _loading = false);
      _emit();
    } catch (e) {
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  void _emit() {
    final opts = <PollOption>[];
    for (var i = 0; i < _foods.length; i++) {
      final f = _foods[i];
      final votes = (i < _tally.length ? _tally[i] : 0);
      opts.add(PollOption(
        id: '$i',
        foodName: f['name_vi'] as String? ?? 'Món',
        imageUrl: f['primary_image'] as String?,
        priceVnd: (f['avg_price_vnd'] as int?) ?? 0,
        distanceM: 800,
        voters: [for (var v = 0; v < votes; v++) (id: 'v$v', name: 'M$v', avatar: null)],
      ));
    }
    _controller.add(opts);
  }

  Future<void> _vote(String optionId) async {
    if (_groupId == null || _pollId == null) return;
    final idx = int.tryParse(optionId) ?? 0;
    final tally = await _api.votePoll(_groupId!, _pollId!, idx);
    if (tally != null) { _tally = tally; _emit(); }
  }

  @override
  void dispose() {
    _rt.dispose();
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.phoOrange)));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vote nhóm')),
        body: Center(child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('😕', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: AppTypography.bodyMd),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: () { setState(() { _loading = true; _error = null; }); _setup(); }, child: const Text('Thử lại')),
          ]),
        )),
      );
    }
    return GroupVotingScreen(
      groupName: _inviteCode != null ? 'Nhóm · mã ${_inviteCode}' : 'Nhóm ăn',
      memberCount: 1,
      optionsStream: _controller.stream,
      onVote: _vote,
    );
  }
}
