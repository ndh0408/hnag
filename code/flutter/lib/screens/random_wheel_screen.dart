import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class WheelOption {
  final String id;
  final String label;
  final Color color;
  const WheelOption(this.id, this.label, this.color);
}

class RandomWheelScreen extends StatefulWidget {
  final List<WheelOption> options;
  final ValueChanged<WheelOption> onResult;
  const RandomWheelScreen({super.key, required this.options, required this.onResult});

  @override
  State<RandomWheelScreen> createState() => _RandomWheelScreenState();
}

class _RandomWheelScreenState extends State<RandomWheelScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _anim;
  WheelOption? _result;
  bool _spinning = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 4500));
    _anim = Tween(begin: 0.0, end: 0.0).animate(_ctrl);
  }

  void _spin() {
    if (_spinning) return;
    setState(() { _spinning = true; _result = null; });
    final n = widget.options.length;
    final winner = math.Random().nextInt(n);
    final extraTurns = 5 + math.Random().nextDouble() * 2;
    final stopAngle = extraTurns * 2 * math.pi + (n - winner - 0.5) * (2 * math.pi / n);

    _anim = Tween(begin: 0.0, end: stopAngle).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward(from: 0).then((_) {
      HapticFeedback.heavyImpact();
      setState(() {
        _result = widget.options[winner];
        _spinning = false;
      });
      widget.onResult(widget.options[winner]);
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Quay vòng quyết định', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Column(children: [
          const Spacer(),
          if (_result != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  gradient: AppGradients.pho,
                  borderRadius: BorderRadius.circular(AppRadii.full),
                  boxShadow: AppShadows.glow(AppColors.phoOrange),
                ),
                child: Text('🎉 ${_result!.label}',
                    style: AppTypography.headingMd.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            )
          else
            const SizedBox(height: 56),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _anim,
            builder: (_, child) {
              return SizedBox(
                width: 320, height: 320,
                child: Stack(alignment: Alignment.center, children: [
                  Transform.rotate(angle: _anim.value, child: CustomPaint(painter: _WheelPainter(widget.options), size: const Size(320, 320))),
                  Positioned(top: -8, child: Icon(Icons.arrow_drop_down, size: 56, color: Colors.white.withOpacity(0.95))),
                ]),
              );
            },
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _spinning ? null : _spin,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.phoOrange,
              minimumSize: const Size(220, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.full)),
            ),
            child: Text(_spinning ? 'Đang quay...' : _result == null ? 'QUAY!' : 'Quay lại',
                style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w800, fontSize: 18)),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<WheelOption> options;
  _WheelPainter(this.options);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final n = options.length;
    final sweep = 2 * math.pi / n;

    for (int i = 0; i < n; i++) {
      final start = -math.pi / 2 + i * sweep;
      final paint = Paint()..color = options[i].color..style = PaintingStyle.fill;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, true, paint);

      // text
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(start + sweep / 2);
      final tp = TextPainter(
        text: TextSpan(text: options[i].label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: radius * 0.7);
      tp.paint(canvas, Offset(radius * 0.32, -tp.height / 2));
      canvas.restore();
    }

    // border
    canvas.drawCircle(center, radius, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 6);
    // hub
    canvas.drawCircle(center, 28, Paint()..color = Colors.white);
    canvas.drawCircle(center, 28, Paint()..color = AppColors.phoOrange..style = PaintingStyle.stroke..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(_) => false;
}
