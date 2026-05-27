// CartScreen — list cart items with qty steppers + voucher + total + checkout CTA.
//
// Persistence: every mutation calls CartStore.save() so an app kill or OS
// background-eviction does not wipe the cart. CartStore.load() runs at the
// route entry (caller responsibility — usually app.dart / go_router).

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/theme.dart';
import '../../state/cart_store.dart';
import '../../widgets/ds/ds.dart';

class CartItem {
  final String id;
  final String name;
  final String? imageUrl;
  final String foodSlug;
  final int unitPriceVnd;
  int qty;
  final String? note;
  CartItem({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.foodSlug,
    required this.unitPriceVnd,
    this.qty = 1,
    this.note,
  });

  int get subtotal => unitPriceVnd * qty;
}

class CartScreen extends StatefulWidget {
  final List<CartItem> items;
  final String restaurantName;
  final String? restaurantId;
  final int deliveryFeeVnd;
  final void Function(List<CartItem> items)? onChange;
  final void Function(List<CartItem> items, int total) onCheckout;

  const CartScreen({
    super.key,
    required this.items,
    required this.restaurantName,
    this.restaurantId,
    required this.deliveryFeeVnd,
    required this.onCheckout,
    this.onChange,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late List<CartItem> _items;
  String? _voucher;
  int _voucherDiscount = 0;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.items);
  }

  int get _subtotal => _items.fold<int>(0, (s, it) => s + it.subtotal);
  int get _total => _subtotal + widget.deliveryFeeVnd - _voucherDiscount;

  void _delta(int i, int d) {
    setState(() {
      _items[i].qty = (_items[i].qty + d).clamp(0, 99);
      if (_items[i].qty == 0) _items.removeAt(i);
    });
    widget.onChange?.call(_items);
    _persist();
  }

  /// Persist asynchronously — never block UI on disk write. We intentionally
  /// drop errors: a failed persist is annoying-but-non-fatal (cart simply
  /// won't survive an app kill that hour), and surfacing the error to the
  /// user mid-cart would be more disruptive than the loss it would prevent.
  Future<void> _persist() async {
    try {
      if (_items.isEmpty) {
        await CartStore.clear();
        return;
      }
      await CartStore.save(CartSnapshot(
        items: _items,
        restaurantId: widget.restaurantId,
        restaurantName: widget.restaurantName,
        deliveryFeeVnd: widget.deliveryFeeVnd,
        savedAt: DateTime.now(),
      ));
    } catch (_) {/* drop — see comment above */}
  }

  void _applyVoucher() {
    setState(() {
      _voucher = 'HOMNAY10';
      _voucherDiscount = (_subtotal * 0.1).round();
    });
  }

  String _vnd(int v) => '${v.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}₫';

  @override
  Widget build(BuildContext context) {
    return HnagThemeScope(
      dark: false,
      child: Builder(builder: (context) {
        final t = context.hnag;
        return Scaffold(
          backgroundColor: t.bg,
          appBar: HnagAppBar(
            title: 'Giỏ hàng',
            subtitle: widget.restaurantName,
            leading: HnagIconButton(icon: 'chevL', onPressed: () => Navigator.maybePop(context)),
          ),
          body: _items.isEmpty
              ? _empty(t)
              : Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _CartRow(
                          item: _items[i],
                          onPlus: () => _delta(i, 1),
                          onMinus: () => _delta(i, -1),
                        ),
                      ),
                    ),
                    _summary(t),
                  ],
                ),
        );
      }),
    );
  }

  Widget _empty(SemanticTokens t) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🛒', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 12),
          Text('Giỏ trống', style: HnagType.h2.copyWith(color: t.text, fontFamily: HnagFonts.display)),
          const SizedBox(height: 4),
          Text('Thêm món để bắt đầu',
            textAlign: TextAlign.center,
            style: HnagType.bodyLg.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
          ),
          const SizedBox(height: 20),
          HnagButton(
            label: 'Hỏi Hà gợi món',
            iconLeading: 'sparkle',
            variant: BtnVariant.gradient,
            size: BtnSize.lg,
            onPressed: () => Navigator.maybePop(context),
          ),
        ],
      ),
    ),
  );

  Widget _summary(SemanticTokens t) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: t.bgRaised,
        border: Border(top: BorderSide(color: t.divider)),
      ),
      child: Column(
        children: [
          // Voucher
          if (_voucher == null)
            HnagButton(
              label: 'Áp dụng voucher',
              iconLeading: 'voucher',
              variant: BtnVariant.outline,
              size: BtnSize.md,
              fullWidth: true,
              onPressed: _applyVoucher,
            )
          else
            HnagCard(
              variant: CardVariant.soft,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  HnagIcon('voucher', color: t.brand),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_voucher!,
                    style: HnagType.label.copyWith(color: t.text, fontWeight: FontWeight.w700, fontFamily: HnagFonts.body),
                  )),
                  Text('-${_vnd(_voucherDiscount)}',
                    style: HnagType.label.copyWith(color: t.success, fontWeight: FontWeight.w700, fontFamily: HnagFonts.body),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),
          _rowLine('Tạm tính', _vnd(_subtotal), t.text),
          _rowLine('Phí giao', _vnd(widget.deliveryFeeVnd), t.text),
          if (_voucherDiscount > 0) _rowLine('Giảm giá', '-${_vnd(_voucherDiscount)}', t.success),
          const HnagDivider(),
          const SizedBox(height: 8),
          _rowLine('Tổng', _vnd(_total), t.text, bold: true),
          const SizedBox(height: 12),
          HnagButton(
            label: 'Thanh toán · ${_vnd(_total)}',
            variant: BtnVariant.gradient,
            size: BtnSize.xl,
            fullWidth: true,
            iconTrailing: 'arrowR',
            onPressed: () => widget.onCheckout(_items, _total),
          ),
        ],
      ),
    );
  }

  Widget _rowLine(String label, String value, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
            style: HnagType.body.copyWith(color: color, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, fontFamily: HnagFonts.body),
          ),
          Text(value,
            style: HnagType.body.copyWith(color: color, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, fontFamily: HnagFonts.body),
          ),
        ],
      ),
    );
  }
}

class _CartRow extends StatelessWidget {
  final CartItem item;
  final VoidCallback onPlus;
  final VoidCallback onMinus;
  const _CartRow({required this.item, required this.onPlus, required this.onMinus});

  String _vnd(int v) => '${v.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}₫';

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return HnagCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(HnagRadius.sm),
            child: HnagPhoto(
              width: 64, height: 64,
              imageUrl: item.imageUrl,
              foodSlug: item.foodSlug,
              radius: HnagRadius.sm,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: HnagType.label.copyWith(color: t.text, fontWeight: FontWeight.w600, fontFamily: HnagFonts.body)),
                const SizedBox(height: 2),
                Text(_vnd(item.unitPriceVnd),
                  style: HnagType.bodySm.copyWith(color: t.brand, fontWeight: FontWeight.w700, fontFamily: HnagFonts.body),
                ),
                if (item.note != null && item.note!.isNotEmpty)
                  Text('Ghi chú: ${item.note}',
                    style: HnagType.bodySm.copyWith(color: t.textMuted, fontFamily: HnagFonts.body),
                  ),
              ],
            ),
          ),
          // Qty stepper
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Step(onTap: onMinus, icon: 'minus'),
              const SizedBox(width: 6),
              SizedBox(width: 22, child: Text('${item.qty}',
                textAlign: TextAlign.center,
                style: HnagType.label.copyWith(color: t.text, fontWeight: FontWeight.w700, fontFamily: HnagFonts.body),
              )),
              const SizedBox(width: 6),
              _Step(onTap: onPlus, icon: 'plus'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String icon;
  final VoidCallback onTap;
  const _Step({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.hnag;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: t.bgMuted,
          borderRadius: BorderRadius.circular(HnagRadius.sm),
        ),
        child: Center(child: HnagIcon(icon, size: 14, color: t.text)),
      ),
    );
  }
}
