import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

class CoupleInfo {
  final String? partnerName;
  final String? partnerAvatar;
  final DateTime? anniversary;
  final int placesVisitedTogether;
  final String? topCuisine;
  const CoupleInfo({this.partnerName, this.partnerAvatar, this.anniversary, this.placesVisitedTogether = 0, this.topCuisine});
}

class CoupleModeScreen extends StatelessWidget {
  final CoupleInfo? couple;
  final Future<void> Function(String phoneOrUsername) onInvite;
  final VoidCallback? onDateNightPlan;
  final VoidCallback? onMemoryBook;
  const CoupleModeScreen({super.key, this.couple, required this.onInvite, this.onDateNightPlan, this.onMemoryBook});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Couple Mode', style: TextStyle(color: Colors.white)),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFFFF6B2B), Color(0xFFE63946), Color(0xFF6B4FA0)],
          ),
        ),
        child: SafeArea(child: couple == null ? _empty(context) : _active(context, couple!)),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final ctrl = TextEditingController();
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.x5),
      child: Column(
        children: [
          const Spacer(),
          Stack(alignment: Alignment.center, children: const [
            Text('💕', style: TextStyle(fontSize: 96)),
          ]).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1,1), end: const Offset(1.1,1.1), duration: 1.8.seconds),
          const SizedBox(height: 16),
          Text('Tìm bạn ăn cùng', style: AppTypography.displayLg.copyWith(color: Colors.white)),
          const SizedBox(height: 8),
          Text('Link tài khoản với người yêu / bạn thân.\nHà sẽ gợi ý món hợp cả 2.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd.copyWith(color: Colors.white.withOpacity(0.9))),
          const SizedBox(height: 28),
          TextField(
            controller: ctrl,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.15),
              hintText: 'Username hoặc số điện thoại',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.full), borderSide: BorderSide.none),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => onInvite(ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.phoOrange,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.full)),
            ),
            child: Text('Mời ăn cùng 💕', style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w700)),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _active(BuildContext context, CoupleInfo c) {
    final daysTogether = c.anniversary != null ? DateTime.now().difference(c.anniversary!).inDays : 0;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.x5),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _avatar('https://picsum.photos/seed/me/200'),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('💕', style: TextStyle(fontSize: 36))),
            _avatar(c.partnerAvatar ?? 'https://picsum.photos/seed/p/200'),
          ]),
          const SizedBox(height: 16),
          Text('Bạn & ${c.partnerName ?? "Partner"}', style: AppTypography.headingMd.copyWith(color: Colors.white)),
          if (daysTogether > 0) ...[
            const SizedBox(height: 4),
            Text('$daysTogether ngày cùng nhau',
                style: AppTypography.bodyMd.copyWith(color: Colors.white.withOpacity(0.85))),
          ],
          const SizedBox(height: 28),
          Row(children: [
            Expanded(child: _statTile('${c.placesVisitedTogether}', 'quán đã đi')),
            const SizedBox(width: 12),
            Expanded(child: _statTile(c.topCuisine ?? '?', 'cuisine #1')),
          ]),
          const SizedBox(height: 24),
          _actionCard(
            icon: '🌙', title: 'Date Night Wizard',
            subtitle: 'Hà lên kế hoạch buổi tối lãng mạn cho 2 đứa',
            onTap: onDateNightPlan,
          ),
          const SizedBox(height: 12),
          _actionCard(
            icon: '📔', title: 'Sách nhật ký',
            subtitle: 'Tất cả nơi 2 đứa đã ăn cùng nhau',
            onTap: onMemoryBook,
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _avatar(String url) => Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
        ),
      );

  Widget _statTile(String value, String label) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(AppRadii.lg)),
        child: Column(children: [
          Text(value, style: AppTypography.headingMd.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          Text(label, style: AppTypography.caption.copyWith(color: Colors.white.withOpacity(0.85))),
        ]),
      );

  Widget _actionCard({required String icon, required String title, required String subtitle, VoidCallback? onTap}) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: Row(children: [
            Text(icon, style: const TextStyle(fontSize: 36)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppTypography.headingSm.copyWith(color: Colors.white)),
              const SizedBox(height: 2),
              Text(subtitle, style: AppTypography.caption.copyWith(color: Colors.white.withOpacity(0.85))),
            ])),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ]),
        ),
      );
}
