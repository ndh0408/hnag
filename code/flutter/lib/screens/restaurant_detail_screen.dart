import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';

class RestaurantDetailData {
  final String id;
  final String name;
  final String address;
  final String city;
  final String? phone;
  final double rating;
  final int ratingCount;
  final int priceLevel;
  final List<String> images;
  final List<({String name, int priceVnd})> menu;
  final Map<String, String> openHours;
  final bool isOpen;
  final int? waitMin;
  final List<String> cuisines;
  final List<String> vibes;
  final Map<String, String> deliveryLinks;
  final List<String> friendsBeenAvatars;
  const RestaurantDetailData({
    required this.id, required this.name, required this.address, required this.city,
    this.phone, required this.rating, required this.ratingCount, required this.priceLevel,
    this.images = const [], this.menu = const [], this.openHours = const {},
    this.isOpen = true, this.waitMin, this.cuisines = const [], this.vibes = const [],
    this.deliveryLinks = const {}, this.friendsBeenAvatars = const [],
  });
}

class RestaurantDetailScreen extends StatelessWidget {
  final RestaurantDetailData r;
  final VoidCallback? onDirections;
  final VoidCallback? onBookTable;
  final VoidCallback? onCallPhone;
  final ValueChanged<String>? onOrderVia;
  final VoidCallback? onClaim;
  const RestaurantDetailScreen({
    super.key, required this.r, this.onDirections, this.onBookTable,
    this.onCallPhone, this.onOrderVia, this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: r.images.isNotEmpty
                ? PageView.builder(itemCount: r.images.length, itemBuilder: (_, i) => CachedNetworkImage(imageUrl: r.images[i], fit: BoxFit.cover))
                : Container(color: Colors.grey.shade300),
          ),
        ),
        SliverToBoxAdapter(child: _info(context)),
        SliverToBoxAdapter(child: _liveStatus()),
        SliverToBoxAdapter(child: _actions()),
        SliverToBoxAdapter(child: _menuSection(context)),
        SliverToBoxAdapter(child: _deliverySection(context)),
        if (onClaim != null) SliverToBoxAdapter(child: _claimCta(context)),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ]),
    );
  }

  Widget _info(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(r.name, style: AppTypography.displayLg),
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.star_rounded, color: AppColors.turmeric, size: 18),
          Text(' ${r.rating.toStringAsFixed(1)} (${r.ratingCount}) · ', style: AppTypography.bodyMd),
          Text(List.filled(r.priceLevel, '\$').join(), style: AppTypography.bodyMd.copyWith(color: AppColors.basil, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.place_outlined, size: 16),
          const SizedBox(width: 4),
          Expanded(child: Text('${r.address}, ${r.city}', style: AppTypography.bodyMd)),
        ]),
        if (r.phone != null) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: onCallPhone,
            child: Row(children: [
              const Icon(Icons.phone, size: 16, color: AppColors.phoOrange),
              const SizedBox(width: 4),
              Text(r.phone!, style: AppTypography.bodyMd.copyWith(color: AppColors.phoOrange, decoration: TextDecoration.underline)),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6, children: [...r.cuisines, ...r.vibes].map((t) => Chip(
          label: Text(t), labelStyle: AppTypography.caption,
          visualDensity: VisualDensity.compact, side: BorderSide.none,
          backgroundColor: AppColors.phoOrange.withOpacity(0.1),
        )).toList()),
        if (r.friendsBeenAvatars.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(children: [
            SizedBox(
              height: 28,
              child: Stack(children: r.friendsBeenAvatars.take(4).toList().asMap().entries.map((e) {
                return Positioned(left: e.key * 18.0, child: CircleAvatar(
                  radius: 14, backgroundImage: NetworkImage(e.value),
                ));
              }).toList()),
            ),
            const SizedBox(width: 8),
            Text('${r.friendsBeenAvatars.length} bạn bè đã đến',
                style: AppTypography.caption.copyWith(color: Colors.grey.shade700)),
          ]),
        ],
      ]),
    );
  }

  Widget _liveStatus() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (r.isOpen ? AppColors.success : Colors.grey).withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: r.isOpen ? AppColors.success : Colors.grey, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(r.isOpen ? 'Đang mở' : 'Đóng cửa',
            style: AppTypography.bodyMd.copyWith(color: r.isOpen ? AppColors.success : Colors.grey.shade700, fontWeight: FontWeight.w600)),
        if (r.waitMin != null && r.isOpen) ...[
          const Spacer(),
          const Icon(Icons.access_time, size: 14, color: AppColors.warning),
          const SizedBox(width: 4),
          Text('~${r.waitMin} phút chờ', style: AppTypography.caption),
        ],
      ]),
    );
  }

  Widget _actions() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Row(children: [
        _actionTile(Icons.directions, 'Chỉ đường', onDirections),
        _actionTile(Icons.calendar_today_outlined, 'Đặt bàn', onBookTable),
        _actionTile(Icons.share_outlined, 'Chia sẻ', () {}),
      ]),
    );
  }

  Widget _actionTile(IconData icon, String label, VoidCallback? onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(children: [
            Icon(icon, color: AppColors.phoOrange),
            const SizedBox(height: 4),
            Text(label, style: AppTypography.caption),
          ]),
        ),
      ),
    );
  }

  Widget _menuSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Menu nổi bật', style: AppTypography.headingSm),
        const SizedBox(height: 8),
        ...r.menu.take(6).map((m) => Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md), side: BorderSide(color: Colors.grey.shade200)),
          child: ListTile(
            title: Text(m.name),
            trailing: Text('${(m.priceVnd / 1000).round()}k₫',
                style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700, color: AppColors.phoOrange)),
          ),
        )),
      ]),
    );
  }

  Widget _deliverySection(BuildContext context) {
    if (r.deliveryLinks.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Đặt giao qua', style: AppTypography.headingSm),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: r.deliveryLinks.keys.map((p) => ActionChip(
          label: Text(_partnerLabel(p)),
          avatar: Text(_partnerEmoji(p)),
          onPressed: () => onOrderVia?.call(p),
        )).toList()),
      ]),
    );
  }

  Widget _claimCta(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.x4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.warning.withOpacity(0.4)),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
        const SizedBox(width: 8),
        Expanded(child: Text('Là chủ quán này?', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600))),
        TextButton(onPressed: onClaim, child: const Text('Claim')),
      ]),
    );
  }

  String _partnerLabel(String p) => switch (p) {
        'grabfood' => 'GrabFood', 'shopeefood' => 'ShopeeFood', 'befood' => 'beFood', 'gojek' => 'Gojek', _ => p
      };
  String _partnerEmoji(String p) => switch (p) {
        'grabfood' => '🛵', 'shopeefood' => '🛒', 'befood' => '🚲', 'gojek' => '🏍', _ => '📦'
      };
}
