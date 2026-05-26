// OTP screen — 6-digit code, resend timer, Face ID upsell.
// Mirrors design/m-onboard.jsx#Screen_OTP.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/tokens.dart';
import '../../design/theme.dart';
import '../../widgets/ds/ds.dart';

class OtpScreen extends StatefulWidget {
  final String destination; // email or phone shown to user
  /// Returns true on success.
  final Future<bool> Function(String otp) onVerify;
  final Future<void> Function() onResend;
  final VoidCallback? onChangeDestination;
  final int initialResendSeconds;

  const OtpScreen({
    super.key,
    required this.destination,
    required this.onVerify,
    required this.onResend,
    this.onChangeDestination,
    this.initialResendSeconds = 47,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  late int _resend;
  Timer? _timer;
  bool _busy = false;
  bool _faceId = true;
  bool _verified = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _resend = widget.initialResendSeconds;
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_resend <= 0) { _timer?.cancel(); return; }
      setState(() => _resend--);
    });
  }

  Future<void> _resendCode() async {
    if (_resend > 0) return;
    await widget.onResend();
    if (!mounted) return;
    setState(() => _resend = widget.initialResendSeconds);
    _startTimer();
  }

  Future<void> _verifyNow() async {
    final code = _ctrl.text;
    if (code.length != 6) return;
    // Guard: don't fire concurrent verify calls (auto-on-fill + manual tap
    // would both call backend; second one returns 401 since OTP is consumed
    // and would overwrite the success state with a "Mã không đúng" error).
    if (_busy || _verified) return;
    setState(() { _busy = true; _error = null; });
    try {
      final ok = await widget.onVerify(code);
      if (!ok) {
        if (mounted) setState(() => _error = 'Mã không đúng. Thử lại nhé.');
      } else {
        _verified = true;
        // Pop back to the root so the StreamBuilder in _Boot can show
        // OnboardingFlow / RootScreen unblocked by the auth navigator stack.
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted && !_verified) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HnagThemeScope(
      dark: false,
      child: Builder(builder: (context) {
        final t = context.hnag;
        return Scaffold(
          backgroundColor: t.bg,
          body: SafeArea(
            child: GestureDetector(
              onTap: () => _focus.requestFocus(),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HnagIconButton(
                      icon: 'chevL',
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    const SizedBox(height: 24),
                    Text('Nhập mã 6 số',
                      style: HnagType.d3.copyWith(color: t.text, fontFamily: HnagFonts.display, letterSpacing: -0.7),
                    ),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        style: HnagType.bodyLg.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                        children: [
                          const TextSpan(text: 'Đã gửi đến '),
                          TextSpan(text: widget.destination, style: TextStyle(color: t.text, fontWeight: FontWeight.w700)),
                          if (widget.onChangeDestination != null) ...[
                            const TextSpan(text: '\n'),
                            TextSpan(
                              text: 'đổi địa chỉ',
                              style: TextStyle(color: t.brand, decoration: TextDecoration.underline),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 36),
                    _OtpBoxes(controller: _ctrl, focusNode: _focus, onChanged: (v) {
                      setState(() => _error = null);
                      if (v.length == 6) _verifyNow();
                    }),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: HnagType.bodySm.copyWith(color: t.danger, fontFamily: HnagFonts.body)),
                    ],

                    const SizedBox(height: 28),
                    Center(
                      child: Column(
                        children: [
                          Text('Không nhận được mã?',
                            style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                          ),
                          const SizedBox(height: 4),
                          if (_resend > 0)
                            Text.rich(
                              TextSpan(
                                style: HnagType.label.copyWith(color: t.text, fontFamily: HnagFonts.body),
                                children: [
                                  const TextSpan(text: 'Gửi lại sau '),
                                  TextSpan(
                                    text: '00:${_resend.toString().padLeft(2, '0')}',
                                    style: TextStyle(color: t.brand, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            )
                          else
                            HnagButton(
                              label: 'Gửi lại mã',
                              variant: BtnVariant.soft,
                              size: BtnSize.sm,
                              onPressed: _resendCode,
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),
                    HnagCard(
                      variant: CardVariant.soft,
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const HnagIcon('lock', size: 22, color: HnagColors.brand500),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Lần sau, đăng nhập bằng Face ID?',
                              style: HnagType.bodySm.copyWith(color: t.text, fontFamily: HnagFonts.body),
                            ),
                          ),
                          HnagSwitch(value: _faceId, onChanged: (v) => setState(() => _faceId = v)),
                        ],
                      ),
                    ),

                    const Spacer(),
                    if (_busy) Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: CircularProgressIndicator(color: t.brand, strokeWidth: 2.5),
                      ),
                    ),
                    HnagButton(
                      label: 'Xác minh',
                      size: BtnSize.lg,
                      fullWidth: true,
                      onPressed: _ctrl.text.length == 6 && !_busy ? _verifyNow : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _OtpBoxes extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  const _OtpBoxes({required this.controller, required this.focusNode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return Stack(
      children: [
        // Hidden real input to capture keyboard
        Opacity(
          opacity: 0,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autocorrect: false,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            onChanged: onChanged,
          ),
        ),
        // Visual boxes
        AnimatedBuilder(
          animation: controller,
          builder: (_, __) {
            final text = controller.text;
            final activeIndex = text.length.clamp(0, 5);
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (i) {
                final ch = i < text.length ? text[i] : '';
                final isActive = i == activeIndex;
                final isFilled = i < text.length;
                return Container(
                  width: 48, height: 58,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: isActive ? t.brandSoft : t.bgElev,
                    border: Border.all(
                      color: isFilled ? t.text : isActive ? t.brand : t.border,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(HnagRadius.md),
                    boxShadow: isActive ? [BoxShadow(color: t.brand.withOpacity(0.12), blurRadius: 0, spreadRadius: 4)] : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    ch,
                    style: HnagType.h2.copyWith(color: t.text, fontWeight: FontWeight.w700, fontFamily: HnagFonts.display),
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }
}
