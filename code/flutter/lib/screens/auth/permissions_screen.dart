// Permissions screen — 4 toggleable cards (Location/Notif/Camera/Mic) +
// privacy reassurance + "Tiếp tục" CTA.
// Mirrors design/m-onboard.jsx#Screen_Permissions.

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../../design/tokens.dart';
import '../../design/theme.dart';
import '../../widgets/ds/ds.dart';

class PermissionsScreen extends StatefulWidget {
  /// `onComplete` is called after the user taps "Tiếp tục"; map carries
  /// whether each permission was opted in. Caller decides actual prompt.
  final Future<void> Function(Map<String, bool> grants) onComplete;
  final VoidCallback? onBack;
  final int stepIndex;
  final int totalSteps;
  const PermissionsScreen({
    super.key,
    required this.onComplete,
    this.onBack,
    this.stepIndex = 2,
    this.totalSteps = 8,
  });

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  final Map<String, bool> _grants = {
    'location': true,
    'notifications': true,
    'camera': false,
    'microphone': false,
  };
  bool _busy = false;

  Future<void> _toggle(String key, bool v) async {
    if (!v) {
      setState(() => _grants[key] = false);
      return;
    }
    // Ask for the actual permission
    final perm = switch (key) {
      'location'      => ph.Permission.location,
      'notifications' => ph.Permission.notification,
      'camera'        => ph.Permission.camera,
      'microphone'    => ph.Permission.microphone,
      _               => null,
    };
    if (perm != null) {
      final status = await perm.request();
      if (!mounted) return;
      setState(() => _grants[key] = status.isGranted);
    } else {
      setState(() => _grants[key] = v);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HnagThemeScope(
      dark: false,
      child: Builder(builder: (context) {
        final t = context.hnag;
        final items = [
          ('location',      'pin',  'Vị trí',     'Tìm quán gần · giao nhanh'),
          ('notifications', 'bell', 'Thông báo',  '"Trời mưa rồi — phở nhé?"'),
          ('camera',        'cam',  'Máy ảnh',    'Quét tủ lạnh, chấm món'),
          ('microphone',    'mic',  'Micro',      'Voice "Hey Hà"'),
        ];

        return Scaffold(
          backgroundColor: t.bg,
          appBar: HnagAppBar(
            title: '',
            transparent: true,
            leading: HnagIconButton(
              icon: 'chevL',
              onPressed: widget.onBack ?? () => Navigator.maybePop(context),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  '${widget.stepIndex} / ${widget.totalSteps}',
                  style: HnagType.mono.copyWith(color: t.textMuted),
                ),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cấp quyền để Hà giúp bạn tốt nhất',
                          style: HnagType.d3.copyWith(color: t.text, fontFamily: HnagFonts.display),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Riêng tư là ưu tiên — bạn kiểm soát mọi quyền.',
                          style: HnagType.bodyLg.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                        ),
                        const SizedBox(height: 28),
                        for (final item in items) ...[
                          _PermissionRow(
                            iconName: item.$2,
                            title: item.$3,
                            subtitle: item.$4,
                            on: _grants[item.$1] ?? false,
                            onToggle: (v) => _toggle(item.$1, v),
                          ),
                          const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 12),
                        HnagCard(
                          variant: CardVariant.soft,
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const HnagIcon('lock', size: 18, color: HnagColors.brand500),
                              const SizedBox(width: 10),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: HnagType.bodySm.copyWith(color: t.text, fontFamily: HnagFonts.body),
                                    children: const [
                                      TextSpan(text: 'Dữ liệu không bao giờ bán cho bên thứ 3. Bạn có thể xem & xoá trong '),
                                      TextSpan(text: 'Cài đặt → Privacy', style: TextStyle(fontWeight: FontWeight.w700)),
                                      TextSpan(text: '.'),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: t.divider))),
                  child: HnagButton(
                    label: 'Tiếp tục',
                    size: BtnSize.lg,
                    fullWidth: true,
                    iconTrailing: 'arrowR',
                    loading: _busy,
                    onPressed: () async {
                      setState(() => _busy = true);
                      await widget.onComplete(Map<String, bool>.from(_grants));
                      if (mounted) setState(() => _busy = false);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final String iconName;
  final String title;
  final String subtitle;
  final bool on;
  final ValueChanged<bool> onToggle;

  const _PermissionRow({
    required this.iconName,
    required this.title,
    required this.subtitle,
    required this.on,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return HnagCard(
      variant: on ? CardVariant.def : CardVariant.outline,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: on ? t.brandSoft : t.bgMuted,
              borderRadius: BorderRadius.circular(HnagRadius.md),
            ),
            child: Center(child: HnagIcon(iconName, size: 20, color: on ? t.brand : t.textMuted)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: HnagType.h4.copyWith(color: t.text, fontFamily: HnagFonts.display)),
                const SizedBox(height: 2),
                Text(subtitle, style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),
              ],
            ),
          ),
          HnagSwitch(value: on, onChanged: onToggle),
        ],
      ),
    );
  }
}
