import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../api/hnag_api.dart';
import '../api/location_service.dart';
import '../widgets/attribution.dart';
import 'map_screen.dart';

class NearbyRestaurantsScreen extends StatefulWidget {
  final double lat;
  final double lng;
  const NearbyRestaurantsScreen({super.key, this.lat = 10.776, this.lng = 106.700});

  @override
  State<NearbyRestaurantsScreen> createState() => _NearbyRestaurantsScreenState();
}

class _NearbyRestaurantsScreenState extends State<NearbyRestaurantsScreen> {
  final _api = HnagApi();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _openOnly = true;
  late double _lat = widget.lat;
  late double _lng = widget.lng;

  @override
  void initState() {
    super.initState();
    _initLocationAndLoad();
  }

  Future<void> _initLocationAndLoad() async {
    final loc = await LocationService.current();
    if (mounted) { _lat = loc.lat; _lng = loc.lng; }
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _api.nearbyRestaurants(
      lat: _lat, lng: _lng, radius: 5000, openNow: _openOnly,
    );
    if (!mounted) return;
    setState(() { _items = items; _loading = false; });
  }

  void _openMap() {
    final pins = <({String id, String name, double lat, double lng, String category, bool trending})>[];
    for (final r in _items) {
      final lat = (r['lat'] as num?)?.toDouble();
      final lng = (r['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final tags = (r['cuisine_tags'] as List?)?.cast<String>() ?? const [];
      final rating = double.tryParse('${r['rating_avg']}') ?? 0;
      pins.add((
        id: (r['id'] as String?) ?? '',
        name: (r['name'] as String?) ?? '',
        lat: lat,
        lng: lng,
        category: tags.isNotEmpty ? tags.first : 'restaurant',
        trending: rating >= 4.5,
      ));
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FoodMapScreen(initialLat: _lat, initialLng: _lng, pins: pins),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quán gần đây'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Xem bản đồ',
            onPressed: _items.isEmpty ? null : _openMap,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4, vertical: AppSpacing.x2),
          child: Row(children: [
            FilterChip(
              label: const Text('Mở cửa ngay'),
              selected: _openOnly,
              selectedColor: AppColors.phoOrange,
              labelStyle: TextStyle(color: _openOnly ? Colors.white : null),
              onSelected: (v) { setState(() => _openOnly = v); _load(); },
            ),
            const Spacer(),
            if (!_loading) Text('${_items.length} quán', style: AppTypography.caption.copyWith(color: Colors.grey.shade600)),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.phoOrange))
              : _items.isEmpty
                  ? Center(child: Text('Chưa tìm thấy quán quanh đây', style: AppTypography.bodyMd.copyWith(color: Colors.grey.shade600)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.x3),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x3),
                      itemBuilder: (_, i) => _card(_items[i]),
                    ),
        ),
        const SafeArea(top: false, child: DataAttribution(dense: true)),
      ]),
    );
  }

  Widget _card(Map<String, dynamic> r) {
    final name = (r['name'] as String?) ?? '';
    final cover = (r['cover_image'] as String?) ?? '';
    final city = (r['city'] as String?) ?? '';
    final district = (r['district'] as String?) ?? '';
    final rating = double.tryParse('${r['rating_avg']}') ?? 0;
    final ratingCount = (r['rating_count'] as int?) ?? 0;
    final priceLvl = (r['price_level'] as int?) ?? 0;
    final dist = r['distance_m'];
    final distStr = dist is num
        ? (dist < 1000 ? '${dist.round()}m' : '${(dist / 1000).toStringAsFixed(1)}km')
        : '';

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.sm,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: cover.isNotEmpty
                ? CachedNetworkImage(imageUrl: cover, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(color: Colors.grey.shade200))
                : Container(color: Colors.grey.shade200, child: const Icon(Icons.restaurant)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.x3),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: AppTypography.headingSm, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.star_rounded, size: 16, color: AppColors.turmeric),
              Text(' ${rating.toStringAsFixed(1)}', style: AppTypography.caption.copyWith(fontWeight: FontWeight.w700)),
              Text(' (${ratingCount})', style: AppTypography.caption.copyWith(color: Colors.grey.shade600)),
              const SizedBox(width: 8),
              Text('·', style: AppTypography.caption.copyWith(color: Colors.grey.shade400)),
              const SizedBox(width: 8),
              Text('₫' * (priceLvl.clamp(1, 4)), style: AppTypography.caption.copyWith(color: AppColors.phoOrange, fontWeight: FontWeight.w800)),
              const Spacer(),
              if (distStr.isNotEmpty) Text(distStr, style: AppTypography.caption.copyWith(color: Colors.grey.shade600)),
            ]),
            const SizedBox(height: 4),
            Text([district, city].where((s) => s.isNotEmpty).join(', '),
                style: AppTypography.caption.copyWith(color: Colors.grey.shade600)),
          ]),
        ),
      ]),
    );
  }
}
