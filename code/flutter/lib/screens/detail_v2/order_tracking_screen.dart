// OrderTrackingScreen — status timeline + driver info + ETA, wired to
// backend WebSocket for live `order:update` events.

import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../api/auth_service.dart';
import '../../design/tokens.dart';
import '../../design/theme.dart';
import '../../widgets/ds/ds.dart';

enum OrderStage { placed, cooking, picking, delivering, done }

OrderStage _stageFromString(String? s) => switch (s) {
  'placed' || 'new' || 'intent' => OrderStage.placed,
  'cooking' || 'preparing'      => OrderStage.cooking,
  'picking' || 'ready'          => OrderStage.picking,
  'delivering' || 'shipping'    => OrderStage.delivering,
  'done' || 'delivered'         => OrderStage.done,
  _                              => OrderStage.placed,
};

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  final String restaurantName;
  final OrderStage stage;
  final String etaText;
  final String? driverName;
  final String? driverPhone;
  final VoidCallback? onCallDriver;
  final VoidCallback? onCancel;
  final VoidCallback? onChatDriver;

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
    this.onChatDriver,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  late OrderStage _stage;
  late String _eta;
  io.Socket? _socket;
  Timer? _heartbeat;
  int _lastSeq = 0;
  DateTime? _retryAfter;

  @override
  void initState() {
    super.initState();
    _stage = widget.stage;
    _eta = widget.etaText;
    _connectSocket();
  }

  void _connectSocket() {
    final token = AuthService.instance.accessToken;
    if (token == null) return;
    if (_retryAfter != null && DateTime.now().isBefore(_retryAfter!)) return;
    _socket?.dispose();
    _socket = io.io(
      'wss://api.tothanhthuy.cloud',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(15000)
          .setReconnectionAttempts(20)
          .setAuth({'token': token})
          .build(),
    );
    _socket!.onConnect((_) {
      // user:{userId} room auto-joined by RealtimeGateway on JWT decode.
      // Start app-layer heartbeat (audit realtime-trace §10) so a half-
      // open NAT state surfaces in ≤30s instead of waiting for
      // socket.io's pingTimeout.
      _heartbeat?.cancel();
      _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
        try {
          _socket?.emit('ping', {'ts': DateTime.now().millisecondsSinceEpoch});
        } catch (_) {/* swallow */}
      });
    });
    _socket!.on('order:update', (data) {
      if (!mounted || data is! Map) return;
      // Filter: only this order.
      if (data['orderId'] != widget.orderId) return;
      // Dedup + ordering via server-stamped _seq (audit realtime-trace §3, §4).
      final seq = (data['_seq'] as num?)?.toInt() ?? 0;
      if (seq > 0 && seq <= _lastSeq) return;
      if (seq > 0) _lastSeq = seq;
      setState(() {
        _stage = _stageFromString(data['status'] as String?);
        if (data['eta'] is String) _eta = data['eta'] as String;
      });
    });
    _socket!.on('force_disconnect', (data) {
      if (data is! Map) return;
      final retryAfterSec = (data['retryAfterSec'] as num?)?.toInt() ?? 60;
      _retryAfter = DateTime.now().add(Duration(seconds: retryAfterSec));
      _socket?.dispose();
      _socket = null;
      _heartbeat?.cancel();
    });
    _socket!.connect();
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    _socket?.dispose();
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
          appBar: HnagAppBar(
            title: 'Đơn #${widget.orderId.substring(0, widget.orderId.length.clamp(0, 6))}',
            subtitle: widget.restaurantName,
            leading: HnagIconButton(icon: 'chevL', onPressed: () => Navigator.maybePop(context)),
            actions: [
              if (_stage.index < OrderStage.delivering.index && widget.onCancel != null)
                HnagButton(label: 'Huỷ', variant: BtnVariant.ghost, size: BtnSize.sm, onPressed: widget.onCancel),
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
                      _eta,
                      style: HnagType.d2.copyWith(color: Colors.white, fontFamily: HnagFonts.display),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _stageLabel(_stage),
                      style: HnagType.bodyLg.copyWith(color: Colors.white.withOpacity(0.85), fontFamily: HnagFonts.body),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              // Timeline
              Text('TIẾN ĐỘ', style: HnagType.caps.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),
              const SizedBox(height: 12),
              _Timeline(stage: _stage),

              const SizedBox(height: 20),
              // Driver
              if (widget.driverName != null) ...[
                Text('SHIPPER', style: HnagType.caps.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),
                const SizedBox(height: 8),
                HnagCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      HnagAvatar(name: widget.driverName!, size: 48, status: HnagStatus.online),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.driverName!,
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
                      HnagIconButton(icon: 'phone', variant: IconBtnVariant.soft, onPressed: widget.onCallDriver),
                      const SizedBox(width: 6),
                      HnagIconButton(icon: 'chat', variant: IconBtnVariant.soft, onPressed: widget.onChatDriver ?? () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('💬 Chat shipper sẽ mở Zalo/Telegram khi đối tác hỗ trợ'),
                          duration: Duration(seconds: 3),
                        ));
                      }),
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
