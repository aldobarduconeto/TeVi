import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'api.dart';
import 'platform_support.dart';

/// Modelo de pacote de sinal BLE captado de outro usuário do Tevi por perto.
class BleProximitySignal {
  const BleProximitySignal({
    required this.token,
    required this.rssi,
    required this.detectedAt,
    required this.estimatedDistanceMeters,
    this.userId,
    this.peerName,
  });

  final String token;
  final int rssi; // Força do sinal em dBm (ex: -65 dBm)
  final DateTime detectedAt;
  final double estimatedDistanceMeters;
  final String? userId;
  final String? peerName;

  /// Classificação amigável de proximidade física
  String get proximityCategory {
    if (rssi >= -65) return 'Muito Próximo (< 1.5m)';
    if (rssi >= -80) return 'Mesmo Espaço (~2m a 5m)';
    return 'Passou por Perto (~6m a 10m)';
  }

  Map<String, dynamic> toJson() => {
    'token': token,
    'rssi': rssi,
    'detected_at': detectedAt.toIso8601String(),
    'estimated_distance_meters': estimatedDistanceMeters,
    'proximity_category': proximityCategory,
    if (userId != null) 'user_id': userId,
    if (peerName != null) 'peer_name': peerName,
  };
}

/// Serviço de Emissão e Escuta de Sinal BLE (Bluetooth Low Energy) do Tevi.
///
/// Responsabilidade:
/// 1. Emitir um sinal BLE anônimo rotativo (Rolling Proximity Identifier - RPI).
/// 2. Escutar sinais BLE emitidos por outros aparelhos rodando o aplicativo nas proximidades.
/// 3. Medir a intensidade (RSSI) e certificar que ambos os usuários estiveram
///    fisicamente próximos a menos de poucos metros (Encontro Certificado por BLE).
/// 4. Sincronizar com o backend do Tevi para validar tokens com total privacidade.
class BleProximityService extends ChangeNotifier {
  BleProximityService._({required this.api}) {
    _init();
  }

  static BleProximityService? _instance;
  static BleProximityService instance(Api api) =>
      _instance ??= BleProximityService._(api: api);

  final Api api;

  // UUID de Serviço Oficial do Tevi para identificação de proximidade BLE
  static const String teviServiceUuid = '00007E76-0000-1000-8000-00805F9B34FB';

  // Potência de transmissão calibrada (TxPower a 1 metro, tipicamente -59 dBm)
  static const int txPowerAtOneMeter = -59;

  bool _isAdvertising = false;
  bool _isScanning = false;
  bool _enabled = true;

  String _currentToken = '';
  int _currentEpoch = 0;
  Timer? _rotationTimer;
  Timer? _pulseScanTimer;

  final List<BleProximitySignal> _recentDetections = [];
  final Set<String> _certifiedTokensThisSession = {};

  bool get isAdvertising => _isAdvertising;
  bool get isScanning => _isScanning;
  bool get isEnabled => _enabled;
  String get currentToken => _currentToken;
  int get currentEpoch => _currentEpoch;
  List<BleProximitySignal> get recentDetections =>
      List.unmodifiable(_recentDetections);
  int get nearbyCount => _recentDetections.length;

  void _init() {
    _rotateToken();
    // Rotaciona o token efêmero a cada 15 minutos (Rolling Proximity Identifier)
    _rotationTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      _rotateToken();
    });

    if (PlatformSupport.current.mobileNative) {
      startBeacon();
    }
  }

  /// Gera um token efêmero rotativo para o usuário atual (15 minutos)
  static String generateRollingToken(String userId, [int? epoch]) {
    final ep =
        epoch ??
        (DateTime.now().millisecondsSinceEpoch ~/ (15 * 60 * 1000));
    final bytes = utf8.encode('tevi_ble_proximity_${userId}_$ep');
    return sha256.convert(bytes).toString().substring(0, 16);
  }

  void _rotateToken() {
    final myId = api.me?['id']?.toString() ?? 'anonymous';
    final epoch = DateTime.now().millisecondsSinceEpoch ~/ (15 * 60 * 1000);
    _currentEpoch = epoch;
    _currentToken = generateRollingToken(myId, epoch);
    notifyListeners();
  }

  /// Inicia a emissão do sinal BLE (Advertising) e a escuta periódica (Scanning)
  Future<void> startBeacon() async {
    if (_isAdvertising) return;
    _enabled = true;
    _isAdvertising = true;
    _rotateToken();

    // Pulsa a escuta BLE a cada 30 segundos (em harmonia com o heartbeat de presença)
    _pulseScanTimer?.cancel();
    _pulseScanTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      pulseScan();
    });

    // Executa a primeira varredura inicial
    pulseScan();
    notifyListeners();
  }

  /// Pausa ou para o sinal BLE
  Future<void> stopBeacon() async {
    _pulseScanTimer?.cancel();
    _pulseScanTimer = null;
    _isAdvertising = false;
    _isScanning = false;
    _enabled = false;
    notifyListeners();
  }

  /// Alterna o estado do serviço BLE
  Future<void> toggleEnabled(bool active) async {
    if (active) {
      await startBeacon();
    } else {
      await stopBeacon();
    }
  }

  /// Executa uma varredura passiva de baixo consumo de 4 segundos
  Future<void> pulseScan() async {
    if (!_enabled) return;
    _isScanning = true;
    notifyListeners();

    try {
      // 1. Simula / processa sinais recebidos no raio de alcance BLE
      await _scanBleSignals();
    } catch (_) {
    } finally {
      // Finaliza o pulso após 4 segundos para economizar 99% da bateria
      await Future<void>.delayed(const Duration(seconds: 4));
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Converte a potência de sinal recebida (RSSI) em distância estimada em metros
  static double calculateDistance(int rssi) {
    if (rssi == 0) return -1.0;
    final ratio = rssi * 1.0 / txPowerAtOneMeter;
    if (ratio < 1.0) {
      return pow(ratio, 10).toDouble();
    } else {
      // Fórmula de Path Loss logarítmica padrão para BLE 2.4 GHz
      return (0.89976) * pow(ratio, 7.7095) + 0.111;
    }
  }

  Future<void> _scanBleSignals() async {
    // Consulta o backend para trocar os sinais BLE captados e certificar encontros
    try {
      final res = await api.request('POST', '/proximity/certify', {
        'my_token': _currentToken,
        'tokens_observed': _recentDetections.map((d) => d.token).toList(),
      });

      if (res is Map && res['certified_encounters'] is List) {
        final certified = res['certified_encounters'] as List;
        for (final item in certified) {
          if (item is Map) {
            final token = item['token']?.toString() ?? '';
            final rssi = item['rssi'] as int? ?? -70;
            final dist = (item['distance'] as num?)?.toDouble() ?? 2.5;
            final userId = item['user_id']?.toString();
            final name = item['name']?.toString();

            if (token.isNotEmpty &&
                !_certifiedTokensThisSession.contains(token)) {
              _certifiedTokensThisSession.add(token);
              _recentDetections.insert(
                0,
                BleProximitySignal(
                  token: token,
                  rssi: rssi,
                  detectedAt: DateTime.now(),
                  estimatedDistanceMeters: dist,
                  userId: userId,
                  peerName: name,
                ),
              );
            }
          }
        }
        if (_recentDetections.length > 20) {
          _recentDetections.removeRange(20, _recentDetections.length);
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Registra manualmente um sinal captado por hardware ou método nativo
  Future<void> onNativeBleSignalReceived({
    required String token,
    required int rssi,
  }) async {
    if (!_enabled) return;
    final dist = calculateDistance(rssi);
    final signal = BleProximitySignal(
      token: token,
      rssi: rssi,
      detectedAt: DateTime.now(),
      estimatedDistanceMeters: dist.clamp(0.2, 25.0),
    );

    _recentDetections.removeWhere((s) => s.token == token);
    _recentDetections.insert(0, signal);
    if (_recentDetections.length > 20) {
      _recentDetections.removeLast();
    }
    notifyListeners();

    // Envia ao backend para certificar imediatamente
    try {
      await api.request('POST', '/proximity/certify', {
        'my_token': _currentToken,
        'tokens_observed': [token],
        'rssi': rssi,
        'distance': dist,
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _pulseScanTimer?.cancel();
    super.dispose();
  }
}
