import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../api/hnag_api.dart';

class PremiumPlan {
  final String id;
  final String label;
  final int priceVnd;
  final String? badge;
  final String period;
  final int? saveBps; // basis points saved vs monthly
  const PremiumPlan({required this.id, required this.label, required this.priceVnd, this.badge, required this.period, this.saveBps});
}

const kPlans = <PremiumPlan>[
  PremiumPlan(id: 'yearly',  label: '1 năm',   priceVnd: 399000, period: '/năm',   badge: 'Tiết kiệm 32%', saveBps: 3200),
  PremiumPlan(id: 'monthly', label: '1 tháng', priceVnd: 49000,  period: '/tháng'),
  PremiumPlan(id: 'trial',   label: 'Thử 7 ngày', priceVnd: 0,    period: 'miễn phí'),
];

class PremiumScreen extends StatefulWidget {
  final Future<void> Function(String planId) onSubscribe;
  const PremiumScreen({super.key, required this.onSubscribe});
  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  String _selected = 'yearly';
  final _api = HnagApi();
  bool _busy = false;

  Future<void> _subscribe() async {
    setState(() => _busy = true);
    try {
      if (_selected == 'trial') {
        final r = await _api.startCheckout('trial', 'trial');
        if (!mounted) return;
        if (r?['isPremium'] == true) {
          _showResult('🎉 Đã kích hoạt dùng thử 7 ngày!', 'Tận hưởng HNAG+ nhé.');
        }
      } else {
        final r = await _api.startCheckout(_selected, 'vietqr');
        if (!mounted) return;
        if (r == null) { _showResult('Lỗi', 'Không tạo được thanh toán. Thử lại sau.'); return; }
        final status = r['status'] as String?;
        if (status == 'awaiting_transfer') {
          _showVietQR(r);
        } else if (status == 'manual') {
          _showResult('Chuyển khoản thủ công',
              'Số tiền: ${_fmt(r['amountVnd'])}₫\nNội dung: ${r['memo']}\n\nCổng tự động chưa bật — liên hệ admin hoặc dùng mã khuyến mãi.');
        } else {
          _showResult('Đang xử lý', 'Trạng thái: $status');
        }
      }
      await widget.onSubscribe(_selected);
    } catch (e) {
      if (mounted) _showResult('Lỗi', '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _redeemPromo() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Nhập mã khuyến mãi'),
        content: TextField(controller: ctrl, autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'VD: BETA2026')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Huỷ')),
          TextButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('Áp dụng')),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;
    setState(() => _busy = true);
    try {
      final r = await _api.redeemPromo(code);
      if (!mounted) return;
      if (r?['isPremium'] == true) {
        _showResult('🎉 Kích hoạt thành công!', 'Bạn đã là HNAG+ tới ${_date(r?['premiumUntil'])}.');
      }
    } catch (e) {
      if (mounted) _showResult('Mã không hợp lệ', '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showResult(String title, String body) {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [TextButton(onPressed: () { Navigator.pop(c); Navigator.pop(context); }, child: const Text('OK'))],
    ));
  }

  void _showVietQR(Map<String, dynamic> r) {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text('Quét mã chuyển khoản'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        if (r['qrUrl'] != null)
          CachedNetworkImage(
            imageUrl: r['qrUrl'] as String,
            height: 240,
            fit: BoxFit.contain,
            placeholder: (_, __) => const SizedBox(height: 240, child: Center(child: CircularProgressIndicator())),
            errorWidget: (_, __, ___) => const Text('Không tải được mã QR'),
          ),
        const SizedBox(height: 8),
        Text('Số tiền: ${_fmt(r['amountVnd'])}₫', style: AppTypography.bodyLg),
        Text('Nội dung: ${r['memo']}', style: AppTypography.caption),
        const SizedBox(height: 8),
        Text('Premium kích hoạt tự động khi nhận được tiền.',
            textAlign: TextAlign.center, style: AppTypography.caption.copyWith(color: Colors.grey.shade600)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Đã hiểu'))],
    ));
  }

  String _fmt(dynamic v) {
    final n = (v is int) ? v : int.tryParse('$v') ?? 0;
    return n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');
  }
  String _date(dynamic v) {
    if (v == null) return '';
    try { final d = DateTime.parse('$v'); return '${d.day}/${d.month}/${d.year}'; } catch (_) { return '$v'; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.premium),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.x4, AppSpacing.x6, AppSpacing.x4, AppSpacing.x4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 32),
              Center(
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.18),
                    border: Border.all(color: Colors.white.withOpacity(0.5), width: 2.5),
                  ),
                  child: const Center(child: Text('✨', style: TextStyle(fontSize: 56))),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1,1), end: const Offset(1.08, 1.08), duration: 2.seconds),
              ),
              const SizedBox(height: AppSpacing.x4),
              Text('HNAG+',
                  textAlign: TextAlign.center,
                  style: AppTypography.display2xl.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
              Text('Hà cá nhân của bạn',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyLg.copyWith(color: Colors.white.withOpacity(0.92))),
              const SizedBox(height: AppSpacing.x6),
              _benefits(),
              const SizedBox(height: AppSpacing.x6),
              ...kPlans.map(_planCard),
              const SizedBox(height: AppSpacing.x4),
              ElevatedButton(
                onPressed: _busy ? null : _subscribe,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.phoOrange,
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.full)),
                ),
                child: _busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.phoOrange))
                    : Text(
                        _selected == 'trial' ? 'Bắt đầu dùng thử 7 ngày' : 'Đăng ký HNAG+ (VietQR)',
                        style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w700, fontSize: 17),
                      ),
              ),
              const SizedBox(height: 10),
              Center(child: TextButton(
                onPressed: _busy ? null : _redeemPromo,
                child: Text('Có mã khuyến mãi?',
                    style: AppTypography.bodyMd.copyWith(color: Colors.white, decoration: TextDecoration.underline)),
              )),
              const SizedBox(height: 4),
              Center(child: Text('Chuyển khoản VietQR · không cần thẻ',
                  style: AppTypography.caption.copyWith(color: Colors.white.withOpacity(0.78)))),
              const SizedBox(height: AppSpacing.x4),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _benefits() {
    final items = const [
      ('✨', 'AI gợi ý không giới hạn'),
      ('📅', 'Meal plan cả tháng'),
      ('🏋️', 'Macro tracking + Apple Health'),
      ('🎤', 'Hà voice tuỳ chỉnh giọng vùng miền'),
      ('🚫', 'Không quảng cáo'),
      ('👨‍🍳', '1000+ công thức chef'),
      ('🌟', 'Early access tính năng mới'),
      ('💎', 'Badge Premium trên profile'),
    ];
    return Column(children: items.map((b) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Text(b.$1, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(child: Text(b.$2, style: AppTypography.bodyLg.copyWith(color: Colors.white))),
      ]),
    )).toList());
  }

  Widget _planCard(PremiumPlan p) {
    final sel = _selected == p.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => setState(() => _selected = p.id),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(sel ? 0.22 : 0.08),
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: Colors.white.withOpacity(sel ? 0.9 : 0.25), width: sel ? 2.5 : 1),
          ),
          child: Row(children: [
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
              child: sel ? const Center(child: Icon(Icons.check, size: 14, color: Colors.white)) : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(p.label, style: AppTypography.headingSm.copyWith(color: Colors.white)),
                if (p.badge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadii.full)),
                    child: Text(p.badge!, style: AppTypography.labelSm.copyWith(color: AppColors.phoOrange)),
                  ),
                ],
              ]),
              const SizedBox(height: 4),
              Text(
                p.priceVnd == 0 ? '7 ngày miễn phí' : '${(p.priceVnd / 1000).round()}k₫ ${p.period}',
                style: AppTypography.bodyMd.copyWith(color: Colors.white.withOpacity(0.85)),
              ),
            ])),
          ]),
        ),
      ),
    );
  }
}
