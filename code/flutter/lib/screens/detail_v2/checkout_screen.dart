// CheckoutScreen — address picker + payment method + delivery type + total.
//
// Payment integration is mocked. Real MoMo/ZaloPay/VNPay wire in Phase 8 (
// blocked by audit hnag-audit-2026-05 → forgeable payment webhook needs HMAC
// verify fix first).

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/theme.dart';
import '../../widgets/ds/ds.dart';
import 'cart_screen.dart' show CartItem;

enum DeliveryType { fast, eco, scheduled }
enum PaymentMethod { momo, zalopay, vnpay, cod, card }

class CheckoutScreen extends StatefulWidget {
  final List<CartItem> items;
  final int subtotalVnd;
  final int voucherDiscountVnd;
  final String defaultAddress;
  final Future<String?> Function() onPlaceOrder;
  const CheckoutScreen({
    super.key,
    required this.items,
    required this.subtotalVnd,
    this.voucherDiscountVnd = 0,
    this.defaultAddress = 'Q.3, TP.HCM — chọn địa chỉ',
    required this.onPlaceOrder,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  DeliveryType _delivery = DeliveryType.fast;
  PaymentMethod _payment = PaymentMethod.momo;
  late String _address;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _address = widget.defaultAddress;
  }

  int get _deliveryFee => switch (_delivery) {
    DeliveryType.fast      => 25000,
    DeliveryType.eco       => 15000,
    DeliveryType.scheduled => 18000,
  };

  int get _total => widget.subtotalVnd + _deliveryFee - widget.voucherDiscountVnd;

  String _vnd(int v) => '${v.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}₫';

  Future<void> _place() async {
    setState(() => _busy = true);
    try {
      final orderId = await widget.onPlaceOrder();
      if (mounted && orderId != null) {
        Navigator.maybePop(context, orderId);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
            title: 'Thanh toán',
            leading: HnagIconButton(icon: 'chevL', onPressed: () => Navigator.maybePop(context)),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            children: [
              // Address
              Text('GIAO TỚI', style: HnagType.caps.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),
              const SizedBox(height: 8),
              HnagCard(
                padding: const EdgeInsets.all(14),
                onTap: () {
                  // TODO Phase 5b: hook real address picker
                },
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: t.brandSoft, borderRadius: BorderRadius.circular(HnagRadius.sm)),
                      child: Center(child: HnagIcon('pin', color: t.brand)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_address.length > 32 ? '${_address.substring(0, 32)}…' : _address,
                            style: HnagType.label.copyWith(color: t.text, fontWeight: FontWeight.w600, fontFamily: HnagFonts.body),
                          ),
                          const SizedBox(height: 2),
                          Text('Bấm để đổi địa chỉ',
                            style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                          ),
                        ],
                      ),
                    ),
                    HnagIcon('chevR', color: t.textMuted),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              // Delivery type
              Text('LOẠI GIAO HÀNG', style: HnagType.caps.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),
              const SizedBox(height: 8),
              _DeliveryPicker(value: _delivery, onChanged: (v) => setState(() => _delivery = v)),

              const SizedBox(height: 20),
              // Payment
              Text('THANH TOÁN', style: HnagType.caps.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),
              const SizedBox(height: 8),
              _PaymentPicker(value: _payment, onChanged: (v) => setState(() => _payment = v)),

              const SizedBox(height: 20),
              // Summary
              Text('TÓM TẮT', style: HnagType.caps.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),
              const SizedBox(height: 8),
              HnagCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _rowLine(t, 'Tạm tính (${widget.items.length} món)', _vnd(widget.subtotalVnd)),
                    _rowLine(t, 'Phí giao', _vnd(_deliveryFee)),
                    if (widget.voucherDiscountVnd > 0) _rowLine(t, 'Voucher', '-${_vnd(widget.voucherDiscountVnd)}', color: t.success),
                    const SizedBox(height: 8),
                    const HnagDivider(),
                    const SizedBox(height: 8),
                    _rowLine(t, 'Tổng', _vnd(_total), bold: true),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              HnagButton(
                label: 'Đặt đơn · ${_vnd(_total)}',
                variant: BtnVariant.gradient,
                size: BtnSize.xl,
                fullWidth: true,
                iconLeading: 'check',
                loading: _busy,
                onPressed: _busy ? null : _place,
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Bấm "Đặt đơn" = đồng ý điều khoản',
                  style: HnagType.bodySm.copyWith(color: t.textFaint, fontFamily: HnagFonts.body),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _rowLine(SemanticTokens t, String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: HnagType.body.copyWith(
            color: color ?? t.text,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            fontFamily: HnagFonts.body,
          )),
          Text(value, style: HnagType.body.copyWith(
            color: color ?? t.text,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            fontFamily: HnagFonts.body,
          )),
        ],
      ),
    );
  }
}

class _DeliveryPicker extends StatelessWidget {
  final DeliveryType value;
  final ValueChanged<DeliveryType> onChanged;
  const _DeliveryPicker({required this.value, required this.onChanged});

  static const _options = [
    (DeliveryType.fast,      '⚡', 'Nhanh', '15–25 phút · 25k'),
    (DeliveryType.eco,       '🌱', 'Eco',  '40–60 phút · 15k'),
    (DeliveryType.scheduled, '⏰', 'Hẹn giờ', 'Chọn giờ · 18k'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return Column(
      children: [
        for (final o in _options) ...[
          HnagCard(
            variant: value == o.$1 ? CardVariant.soft : CardVariant.outline,
            padding: const EdgeInsets.all(14),
            onTap: () => onChanged(o.$1),
            child: Row(
              children: [
                Text(o.$2, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.$3, style: HnagType.label.copyWith(color: t.text, fontWeight: FontWeight.w600, fontFamily: HnagFonts.body)),
                      Text(o.$4, style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),
                    ],
                  ),
                ),
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: value == o.$1 ? t.brand : t.borderStrong, width: 2),
                    color: value == o.$1 ? t.brand : Colors.transparent,
                  ),
                  child: value == o.$1 ? const Center(child: Icon(Icons.circle, size: 8, color: Colors.white)) : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _PaymentPicker extends StatelessWidget {
  final PaymentMethod value;
  final ValueChanged<PaymentMethod> onChanged;
  const _PaymentPicker({required this.value, required this.onChanged});

  static const _options = [
    (PaymentMethod.momo,    '🟣', 'MoMo',      'Ví điện tử'),
    (PaymentMethod.zalopay, '🔵', 'ZaloPay',   'Ví điện tử'),
    (PaymentMethod.vnpay,   '🟦', 'VNPay',     'QR · banking'),
    (PaymentMethod.cod,     '💵', 'COD',       'Trả tiền khi nhận'),
    (PaymentMethod.card,    '💳', 'Thẻ',       'Visa / Mastercard'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return Column(
      children: [
        for (final o in _options) ...[
          HnagCard(
            variant: value == o.$1 ? CardVariant.soft : CardVariant.outline,
            padding: const EdgeInsets.all(12),
            onTap: () => onChanged(o.$1),
            child: Row(
              children: [
                Text(o.$2, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.$3, style: HnagType.label.copyWith(color: t.text, fontWeight: FontWeight.w600, fontFamily: HnagFonts.body)),
                      Text(o.$4, style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body)),
                    ],
                  ),
                ),
                if (value == o.$1) HnagIcon('check', color: t.brand) else const SizedBox.shrink(),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}
