// Settings v2 — clean sectioned list on new DS.
// Mirrors design/m-settings.jsx structure.

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/theme.dart';
import '../../widgets/ds/ds.dart';

class SettingsSection {
  final String title;
  final List<SettingsRow> rows;
  const SettingsSection({required this.title, required this.rows});
}

class SettingsRow {
  final String icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;
  const SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
  });
}

class SettingsScreenV2 extends StatefulWidget {
  final String? userName;
  final String? userEmail;
  final bool initialPush;
  final bool initialEmail;
  final bool initialVoiceWake;
  final String initialTheme; // 'light' | 'dark' | 'system'
  final String initialLanguage; // 'vi' | 'en'
  final Future<void> Function()? onSignOut;
  final VoidCallback? onResetTaste;
  final VoidCallback? onDeleteAccount;
  final ValueChanged<bool>? onPushChanged;
  final ValueChanged<bool>? onEmailChanged;
  final ValueChanged<bool>? onVoiceWakeChanged;
  final ValueChanged<String>? onThemeChanged;
  final ValueChanged<String>? onLanguageChanged;

  const SettingsScreenV2({
    super.key,
    this.userName,
    this.userEmail,
    this.initialPush = true,
    this.initialEmail = false,
    this.initialVoiceWake = true,
    this.initialTheme = 'system',
    this.initialLanguage = 'vi',
    this.onSignOut,
    this.onResetTaste,
    this.onDeleteAccount,
    this.onPushChanged,
    this.onEmailChanged,
    this.onVoiceWakeChanged,
    this.onThemeChanged,
    this.onLanguageChanged,
  });

  @override
  State<SettingsScreenV2> createState() => _SettingsScreenV2State();
}

class _SettingsScreenV2State extends State<SettingsScreenV2> {
  late bool _push;
  late bool _email;
  late bool _voiceWake;
  late String _theme;
  late String _language;

  @override
  void initState() {
    super.initState();
    _push = widget.initialPush;
    _email = widget.initialEmail;
    _voiceWake = widget.initialVoiceWake;
    _theme = widget.initialTheme;
    _language = widget.initialLanguage;
  }

  @override
  Widget build(BuildContext context) {
    return HnagThemeScope(
      dark: false,
      child: Builder(builder: (context) {
        final t = context.hnag;
        return Scaffold(
          backgroundColor: t.bg,
          appBar: HnagAppBar(
            title: 'Cài đặt',
            leading: HnagIconButton(icon: 'chevL', onPressed: () => Navigator.maybePop(context)),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              // User card
              if (widget.userName != null || widget.userEmail != null)
                HnagCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      HnagAvatar(name: widget.userName ?? 'Bạn', size: 48, ring: true),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.userName ?? 'Tài khoản',
                              style: HnagType.h4.copyWith(color: t.text, fontFamily: HnagFonts.display),
                            ),
                            if (widget.userEmail != null)
                              Text(widget.userEmail!,
                                style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                              ),
                          ],
                        ),
                      ),
                      const HnagIcon('chevR'),
                    ],
                  ),
                ),

              _section('Tài khoản', [
                SettingsRow(icon: 'user',  title: 'Hồ sơ'),
                SettingsRow(icon: 'lock',  title: 'Bảo mật & 2FA'),
                SettingsRow(icon: 'email', title: 'Email'),
              ]),

              _section('Khẩu vị & Sức khoẻ', [
                SettingsRow(icon: 'alert', title: 'Dị ứng & Diet'),
                SettingsRow(icon: 'wallet', title: 'Ngân sách'),
                SettingsRow(icon: 'leaf', title: 'Mục tiêu sức khoẻ'),
                SettingsRow(
                  icon: 'refresh',
                  title: 'Reset Taste Memory',
                  subtitle: 'Bắt đầu lại từ đầu — AI sẽ học lại',
                  onTap: widget.onResetTaste,
                ),
              ]),

              _section('Thông báo', [
                SettingsRow(
                  icon: 'bell',
                  title: 'Push notifications',
                  subtitle: 'Gợi ý món + social activity',
                  trailing: HnagSwitch(value: _push, onChanged: (v) {
                    setState(() => _push = v);
                    widget.onPushChanged?.call(v);
                  }),
                ),
                SettingsRow(
                  icon: 'email',
                  title: 'Email weekly recap',
                  trailing: HnagSwitch(value: _email, onChanged: (v) {
                    setState(() => _email = v);
                    widget.onEmailChanged?.call(v);
                  }),
                ),
              ]),

              _section('Trợ lý Hà', [
                SettingsRow(
                  icon: 'mic',
                  title: 'Wake word "Hey Hà"',
                  subtitle: 'On-device — mic chỉ stream sau khi nhận diện',
                  trailing: HnagSwitch(value: _voiceWake, onChanged: (v) {
                    setState(() => _voiceWake = v);
                    widget.onVoiceWakeChanged?.call(v);
                  }),
                ),
                SettingsRow(icon: 'headset', title: 'Giọng Hà', subtitle: 'Bắc — ấm áp'),
              ]),

              _section('Giao diện', [
                SettingsRow(
                  icon: _theme == 'dark' ? 'moon' : 'sun',
                  title: 'Giao diện',
                  subtitle: _theme == 'system' ? 'Theo hệ thống' : (_theme == 'dark' ? 'Tối' : 'Sáng'),
                  onTap: _pickTheme,
                ),
                SettingsRow(
                  icon: 'globe',
                  title: 'Ngôn ngữ',
                  subtitle: _language == 'vi' ? 'Tiếng Việt' : 'English',
                  onTap: _pickLanguage,
                ),
              ]),

              _section('Tích hợp', [
                SettingsRow(icon: 'truck', title: 'GrabFood / ShopeeFood / beFood'),
                SettingsRow(icon: 'heart', title: 'Apple Health / Google Fit'),
                SettingsRow(icon: 'cal',   title: 'Google Calendar'),
              ]),

              _section('Pháp lý & quyền riêng tư', [
                SettingsRow(icon: 'lock', title: 'Chính sách bảo mật'),
                SettingsRow(icon: 'book', title: 'Điều khoản dịch vụ'),
                SettingsRow(icon: 'download', title: 'Tải dữ liệu của tôi', subtitle: 'GDPR / Nghị định 13'),
                SettingsRow(
                  icon: 'trash',
                  title: 'Xoá tài khoản',
                  danger: true,
                  onTap: widget.onDeleteAccount,
                ),
              ]),

              _section('Khác', [
                SettingsRow(icon: 'chat', title: 'Gửi phản hồi'),
                SettingsRow(icon: 'info', title: 'Về HNAG', subtitle: 'Version 1.2.0'),
                SettingsRow(
                  icon: 'logout',
                  title: 'Đăng xuất',
                  danger: true,
                  onTap: widget.onSignOut == null ? null : () => _confirmSignOut(context),
                ),
              ]),
            ],
          ),
        );
      }),
    );
  }

  Widget _section(String title, List<SettingsRow> rows) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Builder(builder: (context) {
        final t = context.hnag;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(title.toUpperCase(),
                style: HnagType.caps.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
              ),
            ),
            HnagCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    HnagListItem(
                      leadingIcon: rows[i].icon,
                      title: rows[i].title,
                      subtitle: rows[i].subtitle,
                      trailing: rows[i].trailing ?? (rows[i].onTap != null
                          ? HnagIcon('chevR', color: t.textMuted, size: 18)
                          : null),
                      onTap: rows[i].onTap,
                      danger: rows[i].danger,
                    ),
                    if (i < rows.length - 1) const HnagDivider(),
                  ],
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _pickTheme() async {
    final v = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _bottomChoices('Giao diện', {
        'system': 'Theo hệ thống',
        'light':  'Sáng',
        'dark':   'Tối',
      }, _theme),
    );
    if (v != null) {
      setState(() => _theme = v);
      widget.onThemeChanged?.call(v);
    }
  }

  Future<void> _pickLanguage() async {
    final v = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _bottomChoices('Ngôn ngữ', {'vi': 'Tiếng Việt', 'en': 'English'}, _language),
    );
    if (v != null) {
      setState(() => _language = v);
      widget.onLanguageChanged?.call(v);
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final t = Theme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text('Bạn chắc muốn đăng xuất chứ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Huỷ')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: t.colorScheme.error),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (ok == true) await widget.onSignOut?.call();
  }

  Widget _bottomChoices(String title, Map<String, String> choices, String current) {
    return Builder(builder: (context) {
      final t = context.hnag;
      return Container(
        decoration: BoxDecoration(
          color: t.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(HnagRadius.xl)),
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: t.borderStrong, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text(title, style: HnagType.h2.copyWith(color: t.text, fontFamily: HnagFonts.display)),
            const SizedBox(height: 16),
            for (final entry in choices.entries)
              HnagListItem(
                leadingIcon: current == entry.key ? 'check' : 'chevR',
                title: entry.value,
                onTap: () => Navigator.pop(context, entry.key),
              ),
          ],
        ),
      );
    });
  }
}
