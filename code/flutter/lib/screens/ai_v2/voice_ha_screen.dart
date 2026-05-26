// Voice "Hà" — dark AI orb + live waveform + transcript bubbles + mic button.
// Mirrors design/m-ai.jsx#Screen_VoiceHà.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../design/tokens.dart';
import '../../design/gradients.dart';
import '../../design/theme.dart';
import '../../widgets/ds/ds.dart';

class VoiceTurn {
  final String text;
  final bool fromUser;
  const VoiceTurn({required this.text, required this.fromUser});
}

class VoiceHaScreen extends StatefulWidget {
  /// `onListen` should toggle ASR start/stop and return the recognized transcript.
  final Future<String?> Function(bool start) onListen;
  final Future<String?> Function(String userText) onAsk;
  final VoidCallback? onClose;
  const VoiceHaScreen({super.key, required this.onListen, required this.onAsk, this.onClose});

  @override
  State<VoiceHaScreen> createState() => _VoiceHaScreenState();
}

class _VoiceHaScreenState extends State<VoiceHaScreen> {
  bool _listening = false;
  bool _thinking = false;
  final List<VoiceTurn> _turns = [
    VoiceTurn(text: 'Hello bạn! Bấm mic và hỏi Hà nha 🎙', fromUser: false),
  ];

  Future<void> _toggleListen() async {
    if (_thinking) return;
    if (!_listening) {
      setState(() => _listening = true);
      try {
        await widget.onListen(true);
      } catch (_) {}
    } else {
      setState(() => _listening = false);
      try {
        final transcript = await widget.onListen(false);
        if (transcript == null || transcript.isEmpty) return;
        setState(() {
          _turns.add(VoiceTurn(text: transcript, fromUser: true));
          _thinking = true;
        });
        final response = await widget.onAsk(transcript);
        if (!mounted) return;
        setState(() {
          _thinking = false;
          if (response != null) _turns.add(VoiceTurn(text: response, fromUser: false));
        });
      } catch (_) {
        if (mounted) setState(() => _thinking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return HnagThemeScope(
      dark: true,
      child: Builder(builder: (context) {
        return Scaffold(
          backgroundColor: HnagColors.neutral950,
          body: Stack(
            children: [
              const Positioned.fill(child: AuroraBackground(opacity: 0.35)),
              SafeArea(
                child: Column(
                  children: [
                    HnagAppBar(
                      title: 'Trợ lý Hà',
                      transparent: true,
                      leading: HnagIconButton(
                        icon: 'x',
                        variant: IconBtnVariant.glass,
                        onPressed: widget.onClose ?? () => Navigator.maybePop(context),
                      ),
                    ),

                    // AI Orb
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: SizedBox(
                        width: 180, height: 180,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 180, height: 180,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: HnagGradients.ai,
                                boxShadow: [BoxShadow(color: HnagColors.ai500.withOpacity(_listening ? 0.7 : 0.3), blurRadius: 40, spreadRadius: 6)],
                              ),
                            )
                                .animate(onPlay: (c) => c.repeat(reverse: true))
                                .scaleXY(end: _listening ? 1.08 : 1.02, duration: 800.ms),
                            // Waveform bars when listening
                            if (_listening)
                              SizedBox(
                                width: 100,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: List.generate(8, (i) => _WaveBar(seed: i)),
                                ),
                              )
                            else
                              const Text('Hà',
                                style: TextStyle(
                                  fontSize: 56, color: Colors.white, fontWeight: FontWeight.w800,
                                  fontFamily: HnagFonts.display, letterSpacing: -2,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Text(
                      _thinking ? 'Hà đang nghĩ…' : _listening ? 'Đang nghe…' : 'Bấm mic để nói',
                      style: HnagType.bodyLg.copyWith(color: Colors.white.withOpacity(0.85), fontFamily: HnagFonts.body),
                    ),
                    const SizedBox(height: 18),

                    // Transcript
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          for (final turn in _turns) _bubble(turn),
                          if (_thinking) _thinkingDots(),
                        ],
                      ),
                    ),

                    // Mic button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      child: GestureDetector(
                        onTap: _toggleListen,
                        child: Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: _listening ? null : HnagGradients.brand,
                            color: _listening ? HnagColors.chili500 : null,
                            boxShadow: [BoxShadow(color: (_listening ? HnagColors.chili500 : HnagColors.brand500).withOpacity(0.5), blurRadius: 40, spreadRadius: 8)],
                          ),
                          child: Center(
                            child: HnagIcon(_listening ? 'micOff' : 'mic', size: 32, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _bubble(VoiceTurn turn) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
        alignment: turn.fromUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: const BoxConstraints(maxWidth: 280),
          decoration: BoxDecoration(
            color: turn.fromUser ? HnagColors.brand500 : Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(HnagRadius.md),
              topRight: const Radius.circular(HnagRadius.md),
              bottomLeft: Radius.circular(turn.fromUser ? HnagRadius.md : 4),
              bottomRight: Radius.circular(turn.fromUser ? 4 : HnagRadius.md),
            ),
          ),
          child: Text(turn.text,
            style: HnagType.body.copyWith(color: Colors.white, fontFamily: HnagFonts.body),
          ),
        ),
      ),
    );
  }

  Widget _thinkingDots() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(HnagRadius.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Container(width: 6, height: 6,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn(delay: (i * 100).ms, duration: 400.ms),
          )),
        ),
      ),
    ),
  );
}

class _WaveBar extends StatefulWidget {
  final int seed;
  const _WaveBar({required this.seed});

  @override
  State<_WaveBar> createState() => _WaveBarState();
}

class _WaveBarState extends State<_WaveBar> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: Duration(milliseconds: 400 + (widget.seed * 40)))
      ..repeat(reverse: true);
    final r = math.Random(widget.seed);
    _a = Tween<double>(begin: 8 + r.nextDouble() * 10, end: 30 + r.nextDouble() * 30).animate(_c);
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) => Container(
        width: 6,
        height: _a.value,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}
