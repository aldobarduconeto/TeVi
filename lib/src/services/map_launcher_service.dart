import 'package:url_launcher/url_launcher.dart';

class MapLauncherService {
  const MapLauncherService();

  /// Known coordinates for landmark points in metropolitan regions
  static final Map<String, (double, double)> _regionCoordinates = {
    'São Paulo (Pinheiros / Vila Madalena)': (-23.5587, -46.6833),
    'São Paulo (Região Central / Paulista)': (-23.5614, -46.6559),
    'São Paulo (Jardins / Itaim Bibi)': (-23.5828, -46.6781),
    'São Paulo (Vila Mariana / Moema)': (-23.5933, -46.6455),
    'São Paulo (Zona Sul)': (-23.6300, -46.6800),
    'São Paulo (Zona Norte)': (-23.5000, -46.6300),
    'São Paulo (Zona Leste)': (-23.5400, -46.5300),
    'São Paulo (Zona Oeste)': (-23.5600, -46.7200),
    'Rio de Janeiro (Copacabana / Ipanema)': (-22.9838, -43.2045),
    'Rio de Janeiro (Barra da Tijuca)': (-23.0003, -43.3658),
    'Rio de Janeiro (Centro / Lapa)': (-22.9112, -43.1812),
    'Rio de Janeiro (Tijuca)': (-22.9250, -43.2350),
    'Belo Horizonte (Savassi / Centro)': (-19.9350, -43.9350),
    'Belo Horizonte (Pampulha)': (-19.8550, -43.9780),
    'Curitiba (Batel / Centro)': (-25.4380, -49.2820),
    'Porto Alegre (Região Central / Moinhos)': (-30.0270, -51.2050),
    'Brasília (Plano Piloto)': (-15.7942, -47.8822),
    'Salvador (Orla / Barra)': (-13.0100, -38.5300),
    'Campinas (Região Central / Cambuí)': (-22.8980, -47.0500),
    'Florianópolis (Ilha)': (-27.5950, -48.5480),
  };

  /// Launch native Maps application (Google Maps on Android, Apple Maps / Google Maps on iOS)
  static Future<bool> openMapLocation({
    double? lat,
    double? lon,
    required String regionName,
  }) async {
    double? targetLat = lat;
    double? targetLon = lon;

    if (targetLat == null || targetLon == null) {
      final known = _regionCoordinates[regionName];
      if (known != null) {
        targetLat = known.$1;
        targetLon = known.$2;
      }
    }

    try {
      if (targetLat != null && targetLon != null) {
        final googleMapsUrl = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$targetLat,$targetLon',
        );
        if (await canLaunchUrl(googleMapsUrl)) {
          return await launchUrl(
            googleMapsUrl,
            mode: LaunchMode.externalApplication,
          );
        }
      }

      final query = Uri.encodeComponent(regionName);
      final searchUrl = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$query',
      );
      if (await canLaunchUrl(searchUrl)) {
        return await launchUrl(
          searchUrl,
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (_) {}
    return false;
  }
}
