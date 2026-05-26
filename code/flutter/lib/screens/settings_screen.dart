import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '_showcase/showcase_screen.dart';

class SettingsScreen extends StatefulWidget {
  final Future<void> Function()? onSignOut;
  const SettingsScreen({super.key, this.onSignOut});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ThemeMode _theme = ThemeMode.system;
  bool _push = true;
  bool _email = false;
  bool _zalo = true;
  bool _voiceWake = true;
  String _voiceAccent = 'bac';
  String _language = 'vi';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt'), elevation: 0),
      body: ListView(children: [
        _section('Tài khoản', [
          _item(Icons.person_outline, 'Hồ sơ', onTap: () {}),
          _item(Icons.lock_outline, 'Bảo mật', onTap: () {}),
          _item(Icons.phone_outlined, 'Đổi số điện thoại', onTap: () {}),
          _item(Icons.email_outlined, 'Email', onTap: () {}),
        ]),
        _section('Khẩu vị & Sức khoẻ', [
          _item(Icons.warning_amber_outlined, 'Dị ứng & Diet', onTap: () {}),
          _item(Icons.attach_money_outlined, 'Ngân sách', onTap: () {}),
          _item(Icons.fitness_center, 'Mục tiêu sức khoẻ', onTap: () {}),
          _item(Icons.psychology_outlined, 'Reset Taste Memory', onTap: () => _confirmReset(context),
              subtitle: 'Bắt đầu lại từ đầu — AI sẽ học lại'),
        ]),
        _section('Thông báo', [
          SwitchListTile(value: _push, onChanged: (v) => setState(() => _push = v),
              activeColor: AppColors.phoOrange, title: const Text('Push notifications'),
              subtitle: const Text('Gợi ý món + social activity')),
          SwitchListTile(value: _email, onChanged: (v) => setState(() => _email = v),
              activeColor: AppColors.phoOrange, title: const Text('Email weekly recap')),
          SwitchListTile(value: _zalo, onChanged: (v) => setState(() => _zalo = v),
              activeColor: AppColors.phoOrange, title: const Text('Zalo broadcast')),
        ]),
        _section('Trợ lý Hà', [
          SwitchListTile(value: _voiceWake, onChanged: (v) => setState(() => _voiceWake = v),
              activeColor: AppColors.phoOrange, title: const Text('Wake word "Hey Hà"'),
              subtitle: const Text('On-device — mic chỉ stream sau khi nhận diện')),
          _item(Icons.record_voice_over_outlined, 'Giọng Hà',
              subtitle: _voiceAccent == 'bac' ? 'Bắc — ấm áp' : _voiceAccent == 'trung' ? 'Trung — Huế' : 'Nam — vui tươi',
              onTap: _pickAccent),
        ]),
        _section('Tích hợp', [
          _item(Icons.local_shipping_outlined, 'GrabFood / ShopeeFood / beFood', subtitle: 'Liên kết tài khoản delivery'),
          _item(Icons.health_and_safety_outlined, 'Apple Health / Google Fit'),
          _item(Icons.calendar_today_outlined, 'Google Calendar'),
        ]),
        _section('Giao diện', [
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('Giao diện'),
            subtitle: Text(_theme == ThemeMode.system ? 'Theo hệ thống' : _theme == ThemeMode.dark ? 'Tối' : 'Sáng'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickTheme,
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Ngôn ngữ'),
            subtitle: Text(_language == 'vi' ? 'Tiếng Việt' : 'English'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickLanguage,
          ),
        ]),
        _section('Pháp lý & quyền riêng tư', [
          _item(Icons.privacy_tip_outlined, 'Chính sách bảo mật', onTap: () {}),
          _item(Icons.description_outlined, 'Điều khoản dịch vụ', onTap: () {}),
          _item(Icons.download_outlined, 'Tải dữ liệu của tôi', subtitle: 'GDPR / Nghị định 13'),
          _item(Icons.delete_outline, 'Xoá tài khoản', danger: true, onTap: () {}),
        ]),
        _section('Khác', [
          _item(Icons.feedback_outlined, 'Gửi phản hồi'),
          _item(Icons.info_outline, 'Về HNAG', subtitle: 'Version 1.0.0+1'),
          _item(Icons.palette_outlined, '🎨 Design Showcase',
              subtitle: 'Xem tất cả primitives hi-fi (dev)',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ShowcaseScreen(),
              ))),
          _item(Icons.logout, 'Đăng xuất', danger: true, onTap: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Đăng xuất'),
                content: const Text('Bạn chắc muốn đăng xuất chứ?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Huỷ')),
                  TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Đăng xuất')),
                ],
              ),
            );
            if (ok == true && widget.onSignOut != null) await widget.onSignOut!();
          }),
        ]),
        const SizedBox(height: 40),
      ]),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(title.toUpperCase(),
            style: AppTypography.labelSm.copyWith(color: Colors.grey.shade600, letterSpacing: 0.6)),
      ),
      ...children,
    ]);
  }

  Widget _item(IconData icon, String title, {String? subtitle, VoidCallback? onTap, bool danger = false}) {
    return ListTile(
      leading: Icon(icon, color: danger ? AppColors.danger : null),
      title: Text(title, style: TextStyle(color: danger ? AppColors.danger : null)),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _pickAccent() {
    showModalBottomSheet(context: context, builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
      RadioListTile<String>(value: 'bac', groupValue: _voiceAccent, activeColor: AppColors.phoOrange,
          title: const Text('Bắc — ấm áp'), onChanged: (v) { setState(() => _voiceAccent = v!); Navigator.pop(context); }),
      RadioListTile<String>(value: 'trung', groupValue: _voiceAccent, activeColor: AppColors.phoOrange,
          title: const Text('Trung — Huế'), onChanged: (v) { setState(() => _voiceAccent = v!); Navigator.pop(context); }),
      RadioListTile<String>(value: 'nam', groupValue: _voiceAccent, activeColor: AppColors.phoOrange,
          title: const Text('Nam — vui tươi'), onChanged: (v) { setState(() => _voiceAccent = v!); Navigator.pop(context); }),
    ]));
  }

  void _pickTheme() {
    showModalBottomSheet(context: context, builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
      RadioListTile<ThemeMode>(value: ThemeMode.light, groupValue: _theme, activeColor: AppColors.phoOrange,
          title: const Text('Sáng'), onChanged: (v) { setState(() => _theme = v!); Navigator.pop(context); }),
      RadioListTile<ThemeMode>(value: ThemeMode.dark, groupValue: _theme, activeColor: AppColors.phoOrange,
          title: const Text('Tối'), onChanged: (v) { setState(() => _theme = v!); Navigator.pop(context); }),
      RadioListTile<ThemeMode>(value: ThemeMode.system, groupValue: _theme, activeColor: AppColors.phoOrange,
          title: const Text('Theo hệ thống'), onChanged: (v) { setState(() => _theme = v!); Navigator.pop(context); }),
    ]));
  }

  void _pickLanguage() {
    showModalBottomSheet(context: context, builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
      RadioListTile<String>(value: 'vi', groupValue: _language, activeColor: AppColors.phoOrange,
          title: const Text('Tiếng Việt'), onChanged: (v) { setState(() => _language = v!); Navigator.pop(context); }),
      RadioListTile<String>(value: 'en', groupValue: _language, activeColor: AppColors.phoOrange,
          title: const Text('English'), onChanged: (v) { setState(() => _language = v!); Navigator.pop(context); }),
    ]));
  }

  void _confirmReset(BuildContext ctx) {
    showDialog(context: ctx, builder: (_) => AlertDialog(
      title: const Text('Reset Taste Memory?'),
      content: const Text('Hà sẽ quên hết khẩu vị bạn đã học, bắt đầu lại từ Food DNA ban đầu.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Reset', style: TextStyle(color: AppColors.danger))),
      ],
    ));
  }
}
