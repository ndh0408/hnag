import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/attribution.dart';

/// Restaurant map — see docs/08-MAP-SOCIAL.md.
/// Uses Mapbox custom style (cyberpunk dark) with food pins.
class FoodMapScreen extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final List<({String id, String name, double lat, double lng, String category, bool trending})> pins;
  final ValueChanged<String>? onPinTap;
  const FoodMapScreen({super.key, required this.initialLat, required this.initialLng, this.pins = const [], this.onPinTap});

  @override
  State<FoodMapScreen> createState() => _FoodMapScreenState();
}

class _FoodMapScreenState extends State<FoodMapScreen> {
  MapboxMap? _map;
  String _styleUri = 'mapbox://styles/mapbox/dark-v11';
  bool _heatmap = false;
  Set<String> _filters = {'open_now'};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        MapWidget(
          key: const ValueKey('food-map'),
          styleUri: _styleUri,
          cameraOptions: CameraOptions(
            center: Point(coordinates: Position(widget.initialLng, widget.initialLat)),
            zoom: 14,
          ),
          onMapCreated: (m) async {
            _map = m;
            await m.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
            await m.compass.updateSettings(CompassSettings(enabled: false));
            await _addPins();
          },
        ),
        Positioned(top: 0, left: 0, right: 0, child: SafeArea(child: _filterBar())),
        Positioned(right: 16, bottom: 110, child: _mapControls()),
        Positioned(left: 0, right: 0, bottom: 0, child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _bottomSheet(),
            const DataAttribution(dense: true),
          ]),
        )),
      ]),
    );
  }

  Future<void> _addPins() async {
    if (_map == null) return;
    final annotationManager = await _map!.annotations.createPointAnnotationManager();
    for (final p in widget.pins) {
      await annotationManager.create(PointAnnotationOptions(
        geometry: Point(coordinates: Position(p.lng, p.lat)),
        textField: p.trending ? '🔥' : _categoryEmoji(p.category),
        textSize: 22,
      ));
    }
  }

  String _categoryEmoji(String c) => switch (c) {
        'noodle' => '🍜', 'rice' => '🍚', 'grill' => '🍢', 'snack' => '🥡',
        'dessert' => '🍰', 'drink' => '☕', 'seafood' => '🦞', _ => '🍽'
      };

  Widget _filterBar() {
    final chips = [
      ('open_now', 'Mở cửa ngay', Icons.access_time),
      ('within_1km', '< 1km', Icons.near_me),
      ('cheap', 'Dưới 100k', Icons.attach_money),
      ('top_rated', '⭐ 4.5+', Icons.star_rounded),
      ('deal', 'Có deal', Icons.local_offer),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        IconButton.filled(
          onPressed: () => Navigator.pop(context),
          style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.95)),
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: chips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final (id, label, icon) = chips[i];
                final sel = _filters.contains(id);
                return FilterChip(
                  label: Text(label),
                  avatar: Icon(icon, size: 16, color: sel ? Colors.white : null),
                  selected: sel,
                  selectedColor: AppColors.phoOrange,
                  labelStyle: TextStyle(color: sel ? Colors.white : null),
                  backgroundColor: Colors.white.withOpacity(0.95),
                  onSelected: (v) => setState(() => v ? _filters.add(id) : _filters.remove(id)),
                );
              },
            ),
          ),
        ),
      ]),
    );
  }

  Widget _mapControls() {
    return Column(children: [
      _ctrlBtn(_heatmap ? Icons.layers : Icons.layers_outlined, () {
        setState(() => _heatmap = !_heatmap);
      }, label: _heatmap ? 'Heat' : 'Pins'),
      const SizedBox(height: 8),
      _ctrlBtn(Icons.my_location, () async {
        // _map?.flyTo(...)
      }),
      const SizedBox(height: 8),
      _ctrlBtn(Icons.style_outlined, () {
        setState(() {
          _styleUri = _styleUri.contains('dark') ? 'mapbox://styles/mapbox/streets-v12' : 'mapbox://styles/mapbox/dark-v11';
        });
        _map?.loadStyleURI(_styleUri);
      }),
    ]);
  }

  Widget _ctrlBtn(IconData icon, VoidCallback onTap, {String? label}) {
    return Material(
      color: Colors.white.withOpacity(0.95),
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 44, height: 44, child: Icon(icon, color: AppColors.phoOrange)),
      ),
    );
  }

  Widget _bottomSheet() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.md,
      ),
      child: Row(children: [
        const Icon(Icons.restaurant, color: AppColors.phoOrange),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${widget.pins.length} quán quanh bạn', style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600)),
          Text('Tap pin để xem chi tiết', style: AppTypography.caption.copyWith(color: Colors.grey.shade600)),
        ])),
        FilledButton.icon(
          onPressed: () {},
          style: FilledButton.styleFrom(backgroundColor: AppColors.phoOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.full))),
          icon: const Icon(Icons.list, size: 16),
          label: const Text('List'),
        ),
      ]),
    );
  }
}
