// Cart persistence store.
//
// Audit hnag-audit-2026-05 §5-Flutter / §B-Cart: the cart used to live
// purely in-memory inside CartScreen's State. Closing the app mid-checkout
// (call interrupts, OS kill, user backgrounds 10 minutes) wiped the cart
// — major retention killer on a food-discovery flow.
//
// `CartStore` serializes the cart to flutter_secure_storage so it survives
// process restarts and even uninstall-on-reinstall on Android (when secure
// storage is backed by Keystore + Android Backup, which it is by default).
//
// Surface: load() / save() / clear(). The screen calls save() inside its
// existing onChange callback; the route that opens the screen calls load()
// first and hands the items in as the initial value. No state-management
// framework introduced — keeps the diff small.

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../screens/detail_v2/cart_screen.dart';

class CartSnapshot {
  final List<CartItem> items;
  final String? restaurantId;
  final String? restaurantName;
  final int deliveryFeeVnd;
  final DateTime savedAt;

  const CartSnapshot({
    required this.items,
    required this.restaurantId,
    required this.restaurantName,
    required this.deliveryFeeVnd,
    required this.savedAt,
  });

  bool get isEmpty => items.isEmpty;
}

class CartStore {
  static const _key = 'hnag.cart.v1';

  // Secure storage instance. Use a single static so widget tests can swap
  // the platform implementation via `FlutterSecureStorage.setMockInitialValues`.
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Load the persisted cart. Returns null if there's no saved cart, the
  /// payload can't be parsed, or the cart is older than 24h (a stale cart
  /// is more user-hostile than a fresh empty one — the menu / prices may
  /// have changed, restaurant may have closed). Adjust TTL via maxAge.
  static Future<CartSnapshot?> load({Duration maxAge = const Duration(hours: 24)}) async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.tryParse(json['savedAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      if (DateTime.now().difference(savedAt) > maxAge) {
        await clear();
        return null;
      }
      final items = (json['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((m) => CartItem(
                id: m['id'] as String,
                name: m['name'] as String,
                imageUrl: m['imageUrl'] as String?,
                foodSlug: m['foodSlug'] as String? ?? '',
                unitPriceVnd: (m['unitPriceVnd'] as num).toInt(),
                qty: (m['qty'] as num?)?.toInt() ?? 1,
                note: m['note'] as String?,
              ))
          .toList();
      return CartSnapshot(
        items: items,
        restaurantId: json['restaurantId'] as String?,
        restaurantName: json['restaurantName'] as String?,
        deliveryFeeVnd: (json['deliveryFeeVnd'] as num?)?.toInt() ?? 0,
        savedAt: savedAt,
      );
    } catch (_) {
      // Corrupt payload — wipe so we don't keep failing forever.
      await clear();
      return null;
    }
  }

  static Future<void> save(CartSnapshot snap) async {
    final payload = jsonEncode({
      'items': snap.items
          .map((it) => {
                'id': it.id,
                'name': it.name,
                'imageUrl': it.imageUrl,
                'foodSlug': it.foodSlug,
                'unitPriceVnd': it.unitPriceVnd,
                'qty': it.qty,
                'note': it.note,
              })
          .toList(),
      'restaurantId': snap.restaurantId,
      'restaurantName': snap.restaurantName,
      'deliveryFeeVnd': snap.deliveryFeeVnd,
      'savedAt': snap.savedAt.toIso8601String(),
    });
    await _storage.write(key: _key, value: payload);
  }

  static Future<void> clear() => _storage.delete(key: _key);
}
