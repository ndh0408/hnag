import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Real location context for the home header: actual district + live weather,
/// resolved from the device GPS via free, key-less services.
class LocationContext {
  final String place; // e.g. "Quận 7, TP.HCM"
  final int? tempC; // e.g. 31
  final String? weather; // e.g. "nắng"
  const LocationContext({required this.place, this.tempC, this.weather});

  /// Single line for the header, e.g. "Quận 7, TP.HCM · 31° nắng".
  String get line {
    if (tempC == null) return place;
    final w = weather != null && weather!.isNotEmpty ? ' $weather' : '';
    return '$place · $tempC°$w';
  }

  static const fallbackLine = 'TP.HCM';
}

/// Device location for "nearby" / map features, with graceful fallback so the
/// app never blocks if permission is denied or GPS is unavailable.
class LocationService {
  /// Fallback when location is unavailable (HCM center).
  static const ({double lat, double lng}) fallback = (lat: 10.7769, lng: 106.7009);

  static Future<({double lat, double lng})> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return fallback;

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return fallback;
      }

      // Fast path: a cached fix is instant; a cold GPS fix can take >8s, so we
      // keep last-known as a fallback instead of dropping all the way to HCM.
      final last = await Geolocator.getLastKnownPosition();
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        ).timeout(const Duration(seconds: 15));
        return (lat: pos.latitude, lng: pos.longitude);
      } catch (_) {
        if (last != null) return (lat: last.latitude, lng: last.longitude);
        return fallback;
      }
    } catch (_) {
      return fallback;
    }
  }

  /// Resolve the real district + current weather from the device GPS.
  /// Uses key-less services: BigDataCloud (reverse geocode) + Open-Meteo (weather).
  static Future<LocationContext> context() async {
    final pos = await current();
    String place = LocationContext.fallbackLine;
    int? temp;
    String? cond;

    // Reverse geocode -> real district name.
    try {
      final r = await http.get(Uri.parse(
        'https://api.bigdatacloud.net/data/reverse-geocode-client'
        '?latitude=${pos.lat}&longitude=${pos.lng}&localityLanguage=vi',
      )).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body) as Map<String, dynamic>;
        final district = _district(j);
        final city = _shortCity((j['city'] as String?) ?? (j['principalSubdivision'] as String?));
        final parts = [if (district != null) district, if (city != null) city];
        if (parts.isNotEmpty) place = parts.join(', ');
      }
    } catch (e) {
      debugPrint('LocationContext geocode error: $e');
    }

    // Live weather.
    try {
      final r = await http.get(Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${pos.lat}&longitude=${pos.lng}&current=temperature_2m,weather_code',
      )).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final cur = (jsonDecode(r.body) as Map<String, dynamic>)['current'] as Map<String, dynamic>?;
        final t = cur?['temperature_2m'];
        if (t is num) temp = t.round();
        final code = cur?['weather_code'];
        if (code is num) cond = _weatherVi(code.toInt());
      }
    } catch (e) {
      debugPrint('LocationContext weather error: $e');
    }

    return LocationContext(place: place, tempC: temp, weather: cond);
  }

  /// Pick the most district-like entry from BigDataCloud's admin hierarchy.
  static String? _district(Map<String, dynamic> j) {
    final admin = (j['localityInfo'] as Map<String, dynamic>?)?['administrative'];
    if (admin is List) {
      for (final a in admin) {
        final name = (a is Map ? a['name'] as String? : null)?.trim();
        if (name == null || name.isEmpty) continue;
        if (name.startsWith('Quận') || name.startsWith('Huyện') ||
            name.startsWith('Thị xã') || name.contains('Thành phố Thủ Đức')) {
          return name;
        }
      }
    }
    final locality = (j['locality'] as String?)?.trim();
    if (locality != null && locality.isNotEmpty) return locality;
    return null;
  }

  static String? _shortCity(String? city) {
    if (city == null || city.trim().isEmpty) return null;
    final c = city.trim();
    if (c.contains('Hồ Chí Minh') || c.toLowerCase().contains('ho chi minh')) return 'TP.HCM';
    if (c.contains('Hà Nội') || c.toLowerCase().contains('hanoi')) return 'Hà Nội';
    return c.replaceFirst('Thành phố ', 'TP.').replaceFirst('Tỉnh ', '');
  }

  /// WMO weather code -> short Vietnamese label.
  static String _weatherVi(int code) {
    if (code == 0) return 'trời quang';
    if (code <= 2) return 'ít mây';
    if (code == 3) return 'nhiều mây';
    if (code == 45 || code == 48) return 'sương mù';
    if (code >= 51 && code <= 57) return 'mưa phùn';
    if (code >= 61 && code <= 67) return 'mưa';
    if (code >= 71 && code <= 77) return 'tuyết';
    if (code >= 80 && code <= 82) return 'mưa rào';
    if (code >= 85 && code <= 86) return 'mưa tuyết';
    if (code >= 95) return 'dông';
    return 'mát';
  }
}
