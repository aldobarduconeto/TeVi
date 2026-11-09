import 'device_permissions_service.dart';

import 'package:geolocator/geolocator.dart';

/// Retrieves user geographic position with smart caching, low battery consumption,
/// and fast fallback. Does not freeze UI or loop indefinitely.
Future<Position> locate({bool prompt = true}) async {
  if (prompt) {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      await const DevicePermissionsService().requestLocation();
    }
  }

  // Fast-path: return cached recent position (< 2 minutes old) without firing hardware
  try {
    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null &&
        DateTime.now().difference(lastKnown.timestamp).inMinutes < 2) {
      return lastKnown;
    }
  } catch (_) {}

  // Request balanced accuracy for ultra-fast response (< 1s) and low battery usage
  try {
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 8),
      ),
    );
  } catch (_) {
    // If real-time fix times out (e.g. indoors or backgrounded), fall back gracefully
    final fallback = await Geolocator.getLastKnownPosition();
    if (fallback != null) {
      return fallback;
    }
    rethrow;
  }
}
