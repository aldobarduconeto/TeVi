import 'package:geolocator/geolocator.dart';

import '../models/api_exception.dart';
import '../models/location_permission_info.dart';
import 'platform_support.dart';

class DevicePermissionsService {
  const DevicePermissionsService();

  Future<LocationPermissionInfo> status() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    final permission = await Geolocator.checkPermission();
    return LocationPermissionInfo(permission, enabled);
  }

  Future<void> requestLocation() async {
    if (!PlatformSupport.current.location) {
      throw ApiException(PlatformSupport.current.permissionHelp);
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw ApiException(
        'Ative a localização nas configurações do dispositivo.',
      );
    }
    final current = await Geolocator.checkPermission();
    final permission = current == LocationPermission.denied
        ? await Geolocator.requestPermission()
        : current;
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw ApiException(
        'Autorize a localização nos ajustes do dispositivo.',
      );
    }
  }

  Future<void> openSettings() async {
    if (!PlatformSupport.current.openSystemSettings) {
      throw ApiException(PlatformSupport.current.permissionHelp);
    }
    if (!await Geolocator.openAppSettings()) {
      throw ApiException('Não foi possível abrir os ajustes do dispositivo.');
    }
  }
}
