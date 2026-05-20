import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

import '../theme/app_theme.dart';

/// Full-screen Voice Assistant ("Hà") — see docs/12-LIVE-COOKING-VOICE.md §8.
/// Visual states: IDLE → LISTENING → THINKING → SPEAKING.
class VoiceAssistantScreen extends StatefulWidget {
  final Future<HaResponse> Function(String transcript) onTranscript;
  const VoiceAssistantScreen({super.key, required this.onTranscript});

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

enum HaState { idle, listening, thinking, speaking }

class HaResponse {
  final String speech;
  final List<String> suggestedActions;
  final String emotion;
  const HaResponse({required this.speech, this.suggestedActions = const [], this.emotion = 'warm'});
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen> with TickerProviderStateMixin {
  final _stt = stt.SpeechToText();
  final _tts = FlutterTts();
  String _transcript = '';
  String _reply = '';
  HaState _state = HaState.idle;
  bool _sttAvailable = false;
  String _emotion = 'warm';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _sttAvailable = await _stt.initialize(
      onStatus: (s) {
        if (s == 'notListening' && _state == HaState.listening && _transcript.isNotEmpty) {
          _onUserDoneSpeaking();
        }
      },
      onError: (_) => setState(() => _state = HaState.idle),
    );
    await _tts.setLanguage('vi-VN');
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    _tts.setCompletionHandler(() => setState(() => _state = HaState.idle));
  }

  @override
  void dispose() {
    _stt.stop();
    _tts.stop();
    super.dispose();
  }

  Future<void> _startListening() async {
    if (!_sttAvailable) return;
    setState(() {
      _state = HaState.listening;
      _transcript = '';
      _reply = '';
    });
    _stt.listen(
      localeId: 'vi-VN',
      partialResults: true,
      listenFor: const Duration(seconds: 12),
      pauseFor: const Duration(seconds: 2),
      onResult: (r) => setState(() => _transcript = r.recognizedWords),
    );
  }

  Future<void> _onUserDoneSpeaking() async {
    await _stt.stop();
    if (_transcript.trim().isEmpty) {
      setState(() => _state = HaState.idle);
      return;
    }
    setState(() => _state = HaState.thinking);
    try {
      final resp = await widget.onTranscript(_transcript);
      setState(() {
        _reply = resp.speech;
        _emotion = resp.emotion;
        _state = HaState.speaking;
      });
      await _adaptVoice(resp.emotion);
      await _tts.speak(resp.speech);
    } catch (_) {
      setState(() {
        _reply = 'Hà bị nghẽn tí, thử lại nha';
        _state = HaState.speaking;
      });
      await _tts.speak(_reply);
    }
  }

  Future<void> _adaptVoice(String emotion) async {
    switch (emotion) {
      case 'calming': await _tts.setSpeechRate(0.45); await _tts.setPitch(0.95); break;
      case 'playful': await _tts.setSpeechRate(0.55); await _tts.setPitch(1.08); break;
      default:        await _tts.setSpeechRate(0.5);  await _tts.setPitch(1.0);  break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = _state == HaState.idle
        ? AppGradients.ai
        : LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [
              const Color(0xFFA855F7).withOpacity(0.6),
              AppColors.phoOrange.withOpacity(0.4),
            ],
          );

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        decoration: BoxDecoration(gradient: bg),
        child: SafeArea(
          child: Column(
            children: [
              _header(),
              const Spacer(),
              _orb(),
              const SizedBox(height: AppSpacing.x5),
              _stateLabel(),
              const SizedBox(height: AppSpacing.x6),
              if (_transcript.isNotEmpty) _bubble(_transcript, isUser: true),
              if (_reply.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.x3),
                _bubble(_reply, isUser: false),
              ],
              const Spacer(),
              _bottomControls(),
              const SizedBox(height: AppSpacing.x4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.x3, AppSpacing.x3, AppSpacing.x3, 0),
      child: Row(
        children: [
          IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.close, color: Colors.white)),
          const Spacer(),
          Text('Hà — Trợ lý ẩm thực', style: AppTypography.headingSm.copyWith(color: Colors.white)),
          const Spacer(),
          IconButton(onPressed: () {}, icon: const Icon(Icons.settings, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _orb() {
    final isActive = _state != HaState.idle;
    return Container(
      width: 192, height: 192,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFF6B2B), Color(0xFFA855F7)],
          stops: [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFA855F7).withOpacity(isActive ? 0.7 : 0.3),
            blurRadius: 60,
            spreadRadius: isActive ? 20 : 8,
          ),
        ],
      ),
      child: Center(
        child: Text(
          _state == HaState.listening ? '🎤' :
          _state == HaState.thinking  ? '✨' :
          _state == HaState.speaking  ? '🗣' : '🍜',
          style: const TextStyle(fontSize: 56),
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(begin: const Offset(1, 1), end: Offset(isActive ? 1.06 : 1.02, isActive ? 1.06 : 1.02), duration: isActive ? 1.seconds : 3.seconds);
  }

  Widget _stateLabel() {
    final label = switch (_state) {
      HaState.idle => 'Bấm để nói với Hà',
      HaState.listening => 'Hà đang nghe...',
      HaState.thinking => 'Hà đang nghĩ...',
      HaState.speaking => 'Hà đang trả lời...',
    };
    return Text(label, style: AppTypography.bodyLg.copyWith(color: Colors.white.withOpacity(0.92)));
  }

  Widget _bubble(String text, {required bool isUser}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x5),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              constraints: const BoxConstraints(maxWidth: 320),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(isUser ? 0.18 : 0.3),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
              child: Text(
                text,
                style: AppTypography.bodyMd.copyWith(color: Colors.white, height: 1.5),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomControls() {
    return GestureDetector(
      onTap: () {
        if (_state == HaState.listening) {
          _onUserDoneSpeaking();
        } else if (_state == HaState.idle) {
          _startListening();
        }
      },
      child: Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppGradients.pho,
          boxShadow: AppShadows.glow(AppColors.phoOrange),
        ),
        child: Icon(
          _state == HaState.listening ? Icons.stop_rounded : Icons.mic_rounded,
          color: Colors.white, size: 36,
        ),
      ),
    );
  }
}
