// Login v2 — email-first, with Email / Phone segmented tabs.
// SSO Apple + Google + guest. Mirrors design/m-onboard.jsx#Screen_Login.
//
// API-compat with the existing LoginScreen widget so it drops into main.dart.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/tokens.dart';
import '../../design/theme.dart';
import '../../widgets/ds/ds.dart';

class LoginScreenV2 extends StatefulWidget {
  /// Called when user taps "Gửi mã OTP". The caller fires the OTP and shoves
  /// the user onto the OTP screen.
  final Future<void> Function(String emailOrPhone) onSendOtp;
  final VoidCallback? onApple;
  final VoidCallback? onGoogle;
  final VoidCallback? onGuest;

  const LoginScreenV2({
    super.key,
    required this.onSendOtp,
    this.onApple,
    this.onGoogle,
    this.onGuest,
  });

  @override
  State<LoginScreenV2> createState() => _LoginScreenV2State();
}

class _LoginScreenV2State extends State<LoginScreenV2> {
  String _mode = 'email'; // 'email' | 'phone'
  final _ctrl = TextEditingController();
  String? _error;
  bool _busy = false;

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _phoneRe = RegExp(r'^0\d{9}$');

  bool get _valid {
    final v = _ctrl.text.trim();
    if (_mode == 'email') return _emailRe.hasMatch(v);
    return _phoneRe.hasMatch(v);
  }

  Future<void> _submit() async {
    final v = _ctrl.text.trim();
    if (!_valid) {
      setState(() => _error = _mode == 'email'
          ? 'Email không hợp lệ'
          : 'Số điện thoại sai định dạng (0xxxxxxxxx)');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await widget.onSendOtp(v);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return HnagThemeScope(
      dark: false,
      child: Builder(builder: (context) {
        final t = context.hnag;
        return Scaffold(
          backgroundColor: t.bg,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HnagIconButton(
                    icon: 'chevL',
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Chào bạn 👋',
                    style: HnagType.d2.copyWith(color: t.text, fontFamily: HnagFonts.display, letterSpacing: -1.2),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Đăng nhập để Hà nhớ khẩu vị của bạn',
                    style: HnagType.bodyLg.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                  ),

                  const SizedBox(height: 28),
                  HnagTabs(
                    tabs: const ['Email', 'Số điện thoại'],
                    active: _mode == 'email' ? 'Email' : 'Số điện thoại',
                    variant: TabsVariant.segmented,
                    onChanged: (v) {
                      setState(() {
                        _mode = v == 'Email' ? 'email' : 'phone';
                        _ctrl.clear();
                        _error = null;
                      });
                    },
                  ),

                  const SizedBox(height: 16),
                  HnagInput(
                    controller: _ctrl,
                    leading: _mode == 'email' ? 'email' : 'phone',
                    placeholder: _mode == 'email' ? 'ban@hnag.app' : '0901234567',
                    keyboardType: _mode == 'email' ? TextInputType.emailAddress : TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() => _error = null),
                    onSubmitted: (_) => _submit(),
                    errorText: _error,
                    maxLength: _mode == 'email' ? 80 : 10,
                  ),

                  const SizedBox(height: 12),
                  HnagButton(
                    label: 'Gửi mã OTP',
                    size: BtnSize.lg,
                    fullWidth: true,
                    onPressed: _busy ? null : _submit,
                    loading: _busy,
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: HnagDivider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text('hoặc',
                          style: HnagType.labelSm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                        ),
                      ),
                      Expanded(child: HnagDivider()),
                    ],
                  ),
                  const SizedBox(height: 12),

                  HnagButton(
                    label: 'Tiếp tục với Apple',
                    iconLeading: 'apple',
                    variant: BtnVariant.secondary,
                    size: BtnSize.lg,
                    fullWidth: true,
                    onPressed: widget.onApple,
                  ),
                  const SizedBox(height: 8),
                  HnagButton(
                    label: 'Tiếp tục với Google',
                    iconLeading: 'google',
                    variant: BtnVariant.secondary,
                    size: BtnSize.lg,
                    fullWidth: true,
                    onPressed: widget.onGoogle,
                  ),

                  if (widget.onGuest != null) ...[
                    const SizedBox(height: 8),
                    HnagButton(
                      label: 'Tiếp tục dưới dạng khách',
                      variant: BtnVariant.ghost,
                      size: BtnSize.md,
                      fullWidth: true,
                      onPressed: widget.onGuest,
                    ),
                  ],

                  const Spacer(),

                  Text.rich(
                    TextSpan(
                      style: HnagType.bodySm.copyWith(color: t.textFaint, fontFamily: HnagFonts.body),
                      children: const [
                        TextSpan(text: 'Tiếp tục = đồng ý '),
                        TextSpan(text: 'ToS', style: TextStyle(decoration: TextDecoration.underline)),
                        TextSpan(text: ' và '),
                        TextSpan(text: 'Privacy Policy', style: TextStyle(decoration: TextDecoration.underline)),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
