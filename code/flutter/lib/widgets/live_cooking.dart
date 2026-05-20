import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:wakelock_plus/wakelock_plus.dart' as wl show WakelockPlus;

import '../theme/app_theme.dart';

class CookingStep {
  final int index;
  final String title;
  final String description;
  final int durationMin;
  final List<String> ingredientsUsed;
  final String? imageUrl;
  final List<String> tips;
  final int? timerSeconds;
  const CookingStep({
    required this.index,
    required this.title,
    required this.description,
    required this.durationMin,
    this.ingredientsUsed = const [],
    this.imageUrl,
    this.tips = const [],
    this.timerSeconds,
  });
}

class CookingRecipe {
  final String name;
  final List<CookingStep> steps;
  const CookingRecipe({required this.name, required this.steps});
}

/// Live Cooking Mode — see docs/12-LIVE-COOKING-VOICE.md PART B.
class LiveCookingScreen extends StatefulWidget {
  final CookingRecipe recipe;
  const LiveCookingScreen({super.key, required this.recipe});

  @override
  State<LiveCookingScreen> createState() => _LiveCookingScreenState();
}

class _LiveCookingScreenState extends State<LiveCookingScreen> with TickerProviderStateMixin {
  int _currentIdx = 0;
  bool _paused = false;
  final List<_CookTimer> _timers = [];
  Timer? _tick;

  final _stt = stt.SpeechToText();
  final _tts = FlutterTts();
  bool _voiceEnabled = false;

  @override
  void initState() {
    super.initState();
    _enableWakelock();
    _setupTts();
    _setupStt();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    _maybeStartStepTimer();
    _speakStep();
  }

  Future<void> _enableWakelock() async {
    try {
      await wl.WakelockPlus.enable();
    } catch (_) {}
  }

  Future<void> _setupTts() async {
    await _tts.setLanguage('vi-VN');
    await _tts.setSpeechRate(0.5);
  }

  Future<void> _setupStt() async {
    _voiceEnabled = await _stt.initialize(onError: (_) {});
    if (_voiceEnabled) _startListeningLoop();
  }

  void _startListeningLoop() {
    if (!_voiceEnabled || _paused) return;
    _stt.listen(
      localeId: 'vi-VN',
      partialResults: false,
      listenFor: const Duration(seconds: 8),
      onResult: (r) {
        final cmd = r.recognizedWords.toLowerCase().trim();
        if (_handleVoiceCommand(cmd)) {
          HapticFeedback.mediumImpact();
        }
        Future.delayed(const Duration(seconds: 1), _startListeningLoop);
      },
    );
  }

  bool _handleVoiceCommand(String cmd) {
    if (cmd.contains('tiếp') || cmd.contains('next')) { _next(); return true; }
    if (cmd.contains('quay lại') || cmd.contains('lùi')) { _prev(); return true; }
    if (cmd.contains('lặp lại')) { _speakStep(); return true; }
    if (cmd.contains('dừng') || cmd.contains('tạm dừng')) { _togglePause(); return true; }
    if (cmd.contains('tiếp tục')) { _togglePause(); return true; }
    final m = RegExp(r'(?:đặt timer|hẹn giờ)\s+(\d+)\s*phút').firstMatch(cmd);
    if (m != null) { _addTimer(int.parse(m.group(1)!) * 60, 'Timer ${m.group(1)} phút'); return true; }
    return false;
  }

  void _onTick() {
    bool changed = false;
    for (final t in _timers) {
      if (t.remaining > 0) {
        t.remaining--;
        if (t.remaining == 0) {
          HapticFeedback.heavyImpact();
          _tts.speak('Timer ${t.name} đã xong nhé');
        }
        changed = true;
      }
    }
    if (changed) setState(() {});
  }

  void _maybeStartStepTimer() {
    final step = widget.recipe.steps[_currentIdx];
    if (step.timerSeconds != null) _addTimer(step.timerSeconds!, step.title);
  }

  void _addTimer(int seconds, String name) {
    if (_timers.length >= 4) return;
    setState(() => _timers.add(_CookTimer(name: name, total: seconds, remaining: seconds)));
  }

  void _speakStep() {
    final s = widget.recipe.steps[_currentIdx];
    _tts.speak('Bước ${s.index + 1}: ${s.description}');
  }

  void _next() {
    if (_currentIdx >= widget.recipe.steps.length - 1) {
      _tts.speak('Đã xong rồi đó, nấu ngon nha');
      return;
    }
    setState(() => _currentIdx++);
    _maybeStartStepTimer();
    _speakStep();
  }

  void _prev() {
    if (_currentIdx <= 0) return;
    setState(() => _currentIdx--);
    _speakStep();
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (!_paused) _startListeningLoop();
    else _stt.stop();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _stt.stop();
    _tts.stop();
    wl.WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.recipe.steps[_currentIdx];
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            if (step.imageUrl != null) _heroImage(step.imageUrl!),
            _stepBody(step),
            const Spacer(),
            ..._timers.map(_timerBar),
            _controlBar(),
            const SizedBox(height: AppSpacing.x3),
            _voiceHint(),
            const SizedBox(height: AppSpacing.x4),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final total = widget.recipe.steps.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.x4, AppSpacing.x3, AppSpacing.x4, AppSpacing.x2),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
          Expanded(
            child: Center(
              child: Column(children: [
                Text(widget.recipe.name, style: AppTypography.headingSm.copyWith(color: Colors.white)),
                const SizedBox(height: 2),
                Text('Bước ${_currentIdx + 1} / $total', style: AppTypography.caption.copyWith(color: Colors.white70)),
              ]),
            ),
          ),
          IconButton(icon: const Icon(Icons.replay_rounded, color: Colors.white), onPressed: _speakStep),
        ],
      ),
    );
  }

  Widget _heroImage(String url) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _stepBody(CookingStep step) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(step.title, style: AppTypography.headingMd.copyWith(color: Colors.white)),
          const SizedBox(height: AppSpacing.x3),
          Text(step.description, style: AppTypography.bodyLg.copyWith(color: Colors.white.withOpacity(0.9), height: 1.55)),
          if (step.tips.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('✨', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(step.tips.first,
                      style: AppTypography.bodyMd.copyWith(color: AppColors.turmeric, fontStyle: FontStyle.italic)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _timerBar(_CookTimer t) {
    final progress = t.total == 0 ? 0.0 : (1 - t.remaining / t.total).clamp(0.0, 1.0);
    final mm = (t.remaining ~/ 60).toString().padLeft(2, '0');
    final ss = (t.remaining % 60).toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4, vertical: AppSpacing.x2),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: AppColors.phoOrange),
              const SizedBox(width: 8),
              Expanded(child: Text(t.name, style: AppTypography.bodyMd.copyWith(color: Colors.white))),
              Text('$mm:$ss', style: AppTypography.numericLg.copyWith(color: AppColors.phoOrange)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation(AppColors.phoOrange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ctrlButton(icon: Icons.skip_previous_rounded, label: 'Quay lại', onTap: _prev),
          _ctrlButton(icon: _paused ? Icons.play_arrow_rounded : Icons.pause_rounded, label: _paused ? 'Tiếp' : 'Dừng', onTap: _togglePause),
          _ctrlButton(icon: Icons.skip_next_rounded, label: 'Tiếp', onTap: _next, primary: true),
        ],
      ),
    );
  }

  Widget _ctrlButton({required IconData icon, required String label, required VoidCallback onTap, bool primary = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        decoration: BoxDecoration(
          gradient: primary ? AppGradients.pho : null,
          color: primary ? null : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppRadii.full),
          boxShadow: primary ? AppShadows.glow(AppColors.phoOrange) : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: AppTypography.bodyMd.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _voiceHint() {
    if (!_voiceEnabled) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.mic_rounded, color: Colors.white54, size: 16),
        const SizedBox(width: 6),
        Text('"Hey Hà, tiếp"', style: AppTypography.caption.copyWith(color: Colors.white54)),
      ],
    );
  }
}

class _CookTimer {
  final String name;
  final int total;
  int remaining;
  _CookTimer({required this.name, required this.total, required this.remaining});
}
