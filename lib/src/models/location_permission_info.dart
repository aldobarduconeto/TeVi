import 'package:geolocator/geolocator.dart';

class LocationPermissionInfo {
  const LocationPermissionInfo(this.permission, this.enabled);
  final LocationPermission permission;
  final bool enabled;
  bool get granted =>
      permission == LocationPermission.whileInUse ||
      permission == LocationPermission.always;
  String get description => !enabled
      ? 'Localização do dispositivo desativada.'
      : granted
      ? 'Localização permitida durante o uso do aplicativo.'
      : permission == LocationPermission.deniedForever
      ? 'Permissão bloqueada. Altere nos ajustes do dispositivo.'
      : 'Localização ainda não autorizada.';
}
