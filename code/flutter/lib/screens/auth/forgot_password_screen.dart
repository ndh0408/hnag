// Forgot password — SMS / Email reset chooser.
// Mirrors design/m-extra1.jsx#Screen_ForgotPassword.

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/theme.dart';
import '../../widgets/ds/ds.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final Future<void> Function(String channel, String value) onSend;
  const ForgotPasswordScreen({super.key, required this.onSend});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  String _channel = 'email';
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _info;

  Future<void> _submit() async {
    final v = _ctrl.text.trim();
    if (v.isEmpty) {
      setState(() => _error = 'Nhập email hoặc SĐT đã đăng ký');
      return;
    }
    setState(() { _busy = true; _error = null; _info = null; });
    try {
      await widget.onSend(_channel, v);
      if (!mounted) return;
      setState(() => _info = _channel == 'email'
          ? 'Đã gửi link reset tới $v'
          : 'Đã gửi mã reset qua SMS tới $v');
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
          appBar: HnagAppBar(
            title: 'Quên mật khẩu?',
            leading: HnagIconButton(icon: 'chevL', onPressed: () => Navigator.maybePop(context)),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Không sao — chọn cách reset bên dưới và Hà sẽ gửi mã.',
                    style: HnagType.bodyLg.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                  ),
                  const SizedBox(height: 24),
                  HnagTabs(
                    tabs: const ['Email', 'SMS'],
                    active: _channel == 'email' ? 'Email' : 'SMS',
                    variant: TabsVariant.segmented,
                    onChanged: (v) => setState(() {
                      _channel = v == 'Email' ? 'email' : 'sms';
                      _ctrl.clear(); _error = null; _info = null;
                    }),
                  ),
                  const SizedBox(height: 16),
                  HnagInput(
                    controller: _ctrl,
                    leading: _channel == 'email' ? 'email' : 'phone',
                    placeholder: _channel == 'email' ? 'Email đã đăng ký' : '0901234567',
                    keyboardType: _channel == 'email' ? TextInputType.emailAddress : TextInputType.phone,
                    onChanged: (_) => setState(() { _error = null; _info = null; }),
                    errorText: _error,
                  ),
                  const SizedBox(height: 12),
                  HnagButton(
                    label: _channel == 'email' ? 'Gửi link reset' : 'Gửi mã SMS',
                    size: BtnSize.lg,
                    fullWidth: true,
                    onPressed: _busy ? null : _submit,
                    loading: _busy,
                  ),
                  if (_info != null) ...[
                    const SizedBox(height: 16),
                    HnagCard(
                      variant: CardVariant.soft,
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          HnagIcon('check', color: t.success),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_info!, style: HnagType.body.copyWith(color: t.text, fontFamily: HnagFonts.body))),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
