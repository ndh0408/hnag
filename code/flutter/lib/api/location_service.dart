import 'package:geolocator/geolocator.dart';

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
}
