import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Phone OTP login. Two states: enter phone → enter OTP.
class LoginScreen extends StatefulWidget {
  final Future<void> Function(String phone) onSendOtp;
  final Future<bool> Function(String phone, String otp) onVerifyOtp;
  final VoidCallback? onGoogle;
  final VoidCallback? onApple;
  const LoginScreen({super.key, required this.onSendOtp, required this.onVerifyOtp, this.onGoogle, this.onApple});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _otpSent = false;
  bool _busy = false;
  String _email = '';
  String _otp = '';
  String? _error;
  final _otpCtrl = TextEditingController();

  @override
  void dispose() { _otpCtrl.dispose(); super.dispose(); }

  bool get _emailValid => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.trim());

  // Force the code field to digits-only, max 6 — catches iOS autofill that
  // bypasses inputFormatters by writing the field value directly.
  void _onOtpChanged(String v) {
    var digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 6) digits = digits.substring(0, 6);
    if (digits != _otpCtrl.text) {
      _otpCtrl.value = TextEditingValue(
        text: digits,
        selection: TextSelection.collapsed(offset: digits.length),
      );
    }
    setState(() => _otp = digits);
    if (digits.length == 6 && !_busy) _verify();
  }

  Future<void> _send() async {
    if (!_emailValid) { setState(() => _error = 'Email chưa đúng định dạng'); return; }
    setState(() { _busy = true; _error = null; });
    try {
      await widget.onSendOtp(_email.trim());
      setState(() => _otpSent = true);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    setState(() { _busy = true; _error = null; });
    try {
      final ok = await widget.onVerifyOtp(_email.trim(), _otp);
      if (!ok) setState(() => _error = 'Mã không đúng hoặc hết hạn');
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.x6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Center(child: Text('🍜', style: TextStyle(fontSize: 64))),
              const SizedBox(height: AppSpacing.x4),
              Center(child: Text('Chào mừng đến HNAG', style: AppTypography.displayLg, textAlign: TextAlign.center)),
              const SizedBox(height: AppSpacing.x2),
              Center(child: Text(_otpSent ? 'Nhập mã 6 số gửi tới\n$_email' : 'Đăng nhập bằng email',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMd.copyWith(color: Colors.grey.shade600))),
              const SizedBox(height: AppSpacing.x5),
              if (!_otpSent) _phoneInput() else _otpInput(),
              if (_error != null) Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: const TextStyle(color: AppColors.danger), textAlign: TextAlign.center),
              ),
              const SizedBox(height: AppSpacing.x4),
              ElevatedButton(
                onPressed: _busy ? null : (_otpSent ? _verify : _send),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.phoOrange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.full)),
                ),
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : Text(_otpSent ? 'Xác nhận' : 'Gửi mã qua email',
                        style: AppTypography.bodyLg.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
              if (_otpSent) ...[
                const SizedBox(height: AppSpacing.x3),
                Center(child: TextButton(
                  onPressed: () => setState(() { _otpSent = false; _otp = ''; }),
                  child: const Text('Đổi email'),
                )),
              ],
              const SizedBox(height: AppSpacing.x6),
              Text(
                'Bằng việc tiếp tục, bạn đồng ý với Điều khoản & Chính sách bảo mật',
                style: AppTypography.caption.copyWith(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _phoneInput() {
    return TextField(
      keyboardType: TextInputType.emailAddress,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.none,
      autofillHints: const [AutofillHints.email],
      style: AppTypography.bodyLg,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.email_outlined),
        hintText: 'email@example.com',
        filled: true,
        fillColor: Colors.grey.withOpacity(0.06),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.lg), borderSide: BorderSide.none),
      ),
      onChanged: (v) => setState(() => _email = v),
      onSubmitted: (_) => _send(),
    );
  }

  Widget _otpInput() {
    return TextField(
      controller: _otpCtrl,
      autofocus: true,
      keyboardType: TextInputType.number,
      maxLength: 6,
      autofillHints: null,            // do NOT let iOS autofill email/contact here
      autocorrect: false,
      enableSuggestions: false,
      enableInteractiveSelection: false,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
      textAlign: TextAlign.center,
      style: AppTypography.displayLg.copyWith(letterSpacing: 12, fontWeight: FontWeight.w800),
      decoration: InputDecoration(
        counterText: '',
        hintText: '------',
        hintStyle: AppTypography.displayLg.copyWith(letterSpacing: 12, color: Colors.grey.shade300),
        filled: true,
        fillColor: Colors.grey.withOpacity(0.06),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.lg), borderSide: BorderSide.none),
      ),
      onChanged: _onOtpChanged,
    );
  }

  Widget _socialButton(String label, IconData icon, VoidCallback? onTap) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.full)),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 24),
      label: Text(label, style: AppTypography.bodyLg),
    );
  }
}
