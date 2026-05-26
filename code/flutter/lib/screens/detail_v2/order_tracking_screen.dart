// OrderTrackingScreen — status timeline + driver info + ETA. WebSocket
// subscribe hook is left as a callback (Phase 11 wires backend WS).

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/theme.dart';
import '../../widgets/ds/ds.dart';

enum OrderStage { placed, cooking, picking, delivering, done }

class OrderTrackingScreen extends StatelessWidget {
  final String orderId;
  final String restaurantName;
  final OrderStage stage;
  final String etaText;
  final String? driverName;
  final String? driverPhone;
  final VoidCallback? onCallDriver;
  final VoidCallback? onCancel;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    required this.restaurantName,
    required this.stage,
    required this.etaText,
    this.driverName,
    this.driverPhone,
    this.onCallDriver,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return HnagThemeScope(
      dark: false,
      child: Builder(builder: (context) {
        final t = context.hnag;
        return Scaffold(
          backgroundColor: t.bg,
          appBar: HnagAppBar(
            title: 'Đơn #${orderId.substring(0, 6)}',
            subtitle: restaurantName,
            leading: HnagIconButton(icon: 'chevL', onPressed: () => Navigator.maybePop(context)),
            actions: [
              if (stage.index < OrderStage.delivering.index && onCancel != null)
                HnagButton(label: 'Huỷ', variant: BtnVariant.ghost, size: BtnSize.sm, onPressed: onCancel),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              // ETA hero
              HnagCard(
                variant: CardVariant.gradient,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const HnagBadge(label: 'ĐANG TRACKING', variant: BadgeVariant.glass, icon: 'package'),
                    const SizedBox(height: 12),
                    Text(
                      etaText,
                      style: HnagType.d2.copyWith(color: Colors.white, fontFamily: HnagFonts.display),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _stageLabel(stage),
                      style: HnagType.bodyLg.copyWith(color: Colors.white.withOpacity(0.85), fontFamily: HnagFonts.body),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              // Timeline
              Text('TIẾN ĐỘ', style: HnagType.caps.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),
              const SizedBox(height: 12),
              _Timeline(stage: stage),

              const SizedBox(height: 20),
              // Driver
              if (driverName != null) ...[
                Text('SHIPPER', style: HnagType.caps.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),
                const SizedBox(height: 8),
                HnagCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      HnagAvatar(name: driverName!, size: 48, status: HnagStatus.online),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(driverName!,
                              style: HnagType.h4.copyWith(color: t.text, fontFamily: HnagFonts.display),
                            ),
                            const SizedBox(height: 2),
                            Row(children: [
                              HnagIcon('star', size: 14, color: HnagColors.turmeric500),
                              const SizedBox(width: 4),
                              Text('4.9 · 1,243 chuyến',
                                style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                              ),
                            ]),
                          ],
                        ),
                      ),
                      HnagIconButton(icon: 'phone', variant: IconBtnVariant.soft, onPressed: onCallDriver),
                      const SizedBox(width: 6),
                      HnagIconButton(icon: 'chat', variant: IconBtnVariant.soft, onPressed: () {}),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
              // Note
              HnagCard(
                variant: CardVariant.soft,
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HnagIcon('info', color: t.brand),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Cập nhật realtime qua WebSocket. Nếu mất kết nối, pull-to-refresh.',
                        style: HnagType.bodySm.copyWith(color: t.text, fontFamily: HnagFonts.body),
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

  String _stageLabel(OrderStage s) => switch (s) {
    OrderStage.placed     => 'Quán đang xác nhận',
    OrderStage.cooking    => 'Đang nấu',
    OrderStage.picking    => 'Shipper đang đến quán',
    OrderStage.delivering => 'Đang giao tới bạn',
    OrderStage.done       => 'Đã giao 🎉',
  };
}

class _Timeline extends StatelessWidget {
  final OrderStage stage;
  const _Timeline({required this.stage});

  static const _steps = [
    (OrderStage.placed,     'Đặt đơn'),
    (OrderStage.cooking,    'Quán nhận + nấu'),
    (OrderStage.picking,    'Shipper lấy đơn'),
    (OrderStage.delivering, 'Đang giao'),
    (OrderStage.done,       'Đã giao'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return HnagCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < _steps.length; i++) _row(t, i),
        ],
      ),
    );
  }

  Widget _row(SemanticTokens t, int i) {
    final s = _steps[i];
    final done = stage.index >= s.$1.index;
    final active = stage.index == s.$1.index;
    final isLast = i == _steps.length - 1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? t.success : Colors.transparent,
                  border: done ? null : Border.all(color: active ? t.brand : t.borderStrong, width: 2),
                ),
                child: done
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : (active
                        ? Center(child: Container(width: 8, height: 8, decoration: BoxDecoration(color: t.brand, shape: BoxShape.circle)))
                        : null),
              ),
              if (!isLast)
                Container(width: 2, height: 28, color: done ? t.success.withOpacity(0.3) : t.divider),
            ],
          ),
          const SizedBox(width: 12),
          Padding(
            padding: EdgeInsets.only(top: 2, bottom: isLast ? 0 : 12),
            child: Text(s.$2,
              style: HnagType.label.copyWith(
                color: done ? t.text : t.textMuted,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                fontFamily: HnagFonts.body,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
