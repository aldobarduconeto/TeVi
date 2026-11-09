import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'api.dart';
import 'ble_proximity_service.dart';
import 'location_service.dart';
import 'platform_support.dart';

/// Serviço compartilhado de localização e presença do Tevi.
///
/// Comportamento otimizado:
/// 1. Quando o Modo Workout está ATIVO:
///    - Usa os dados estritamente de localização para buscar ativamente parceiros
///      que também estão treinando por perto (/workout/status e /workout/people)
///      com intervalo adaptativo de 15 segundos.
/// 2. Quando o Modo Workout NÃO está ativo:
///    - Executa uma checagem periódica adaptativa a cada 30 SEGUNDOS.
/// 3. Elimina o loop ocupado (busy loop) de 1 segundo:
///    - Não consome CPU/bateria com Timer de 1s acordando o processador 60x por minuto.
///    - `secondsUntilNextCheck` é calculado sob demanda em O(1).
///    - Cache de permissão de geolocalização reduz chamadas na ponte de plataforma nativa.
class LocationHeartbeatService extends ChangeNotifier {
  LocationHeartbeatService({required this.api}) {
    _init();
  }

  static LocationHeartbeatService? _instance;
  static LocationHeartbeatService instance(Api api) =>
      _instance ??= LocationHeartbeatService(api: api);

  final Api api;

  // Estado do Modo de Presença (Workout, Shopping, Passeio, Coworking, etc.)
  bool _workoutActive = false;
  String _workoutGoal = 'Hipertrofia';
  String _activityMode = 'workout';
  String _modeEmoji = '💪';
  String _modeName = 'Workout & Treino';
  List<Map<String, dynamic>> _workoutPartners = [];

  // Estado da Localização
  DateTime? _lastLocationCheck;
  bool _isLocating = false;
  Position? _lastPosition;
  String? _lastRegion;

  Timer? _heartbeatTimer;
  bool? _hasLocationPermission;
  DateTime? _lastPermissionCheck;

  bool get isWorkoutActive => _workoutActive;
  String get workoutGoal => _workoutGoal;
  String get activityMode => _activityMode;
  String get modeEmoji => _modeEmoji;
  String get modeName => _modeName;
  List<Map<String, dynamic>> get workoutPartners => _workoutPartners;
  DateTime? get lastLocationCheck => _lastLocationCheck;
  bool get isLocating => _isLocating;
  Position? get lastPosition => _lastPosition;
  String? get lastRegion => _lastRegion;

  /// Retorna dinamicamente os segundos restantes até a próxima checagem periódica
  /// calculados sob demanda, eliminando timers de 1s e notificações de rebuild desnecessárias.
  int get secondsUntilNextCheck {
    if (_lastLocationCheck == null) return 0;
    final interval = _workoutActive ? 15 : 30;
    final elapsed = DateTime.now().difference(_lastLocationCheck!).inSeconds;
    final remaining = interval - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  void _init() {
    _startHeartbeatTimer();
    // Executa a primeira checagem imediatamente
    checkLocation(force: true);
  }

  void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    final intervalSeconds = _workoutActive ? 15 : 30;
    _heartbeatTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) => checkLocation(),
    );
  }

  /// Alterna o modo Workout / atividade com ajuste adaptativo imediato do timer.
  Future<void> toggleWorkout({bool? targetState, String? mode, String? goal}) async {
    final nextState = targetState ?? !_workoutActive;
    final nextMode = mode ?? _activityMode;
    final nextGoal = goal ?? _workoutGoal;

    _workoutActive = nextState;
    if (mode != null) _activityMode = nextMode;
    if (goal != null) _workoutGoal = nextGoal;

    _startHeartbeatTimer();

    try {
      await api.request('POST', '/workout', {
        'action': nextState ? 'start' : 'stop',
        'mode': nextMode,
        'goal': nextGoal,
      });

      if (nextState) {
        await checkLocation(force: true);
      } else {
        _workoutPartners = [];
        await checkLocation(force: true);
      }
    } catch (_) {}

    notifyListeners();
  }

  Future<bool> _isLocationAuthorized() async {
    if (!PlatformSupport.current.location) return false;
    final now = DateTime.now();
    // Cache de permissão por 60 segundos para evitar chamadas IPC nativas repetitivas
    if (_hasLocationPermission != null &&
        _lastPermissionCheck != null &&
        now.difference(_lastPermissionCheck!).inSeconds < 60) {
      return _hasLocationPermission!;
    }
    _lastPermissionCheck = now;
    final permission = await Geolocator.checkPermission();
    _hasLocationPermission = (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always);
    return _hasLocationPermission!;
  }

  /// Executa a checagem de localização e busca de pessoas.
  Future<void> checkLocation({bool force = false}) async {
    if (_isLocating && !force) return;
    _isLocating = true;

    try {
      // 1. Verifica permissão de localização com cache de bridge
      if (await _isLocationAuthorized()) {
        final pos = await locate(prompt: false);
        _lastPosition = pos;
        _lastLocationCheck = DateTime.now();

        // Dispara pulso do sinal BLE para certificar proximidade física
        if (api.settings['ble_proximity'] != false) {
          BleProximityService.instance(api).pulseScan();
        }

        // Registra presença no radar
        if (api.settings['discovery'] == true &&
            api.settings['invisible'] != true) {
          await api.request('POST', '/presence', {
            'lat': pos.latitude,
            'lon': pos.longitude,
            'accuracy': pos.accuracy,
            'observed_at': pos.timestamp.millisecondsSinceEpoch / 1000,
          });
        }
      }

      // 2. Sincroniza estado do Workout / Modos e busca pessoas ativas por perto
      final workoutRes = await api.request('GET', '/workout');
      if (workoutRes is Map) {
        final serverActive = workoutRes['active'] == true;
        if (serverActive != _workoutActive) {
          _workoutActive = serverActive;
          _startHeartbeatTimer();
        }
        if (workoutRes['mode'] != null) {
          _activityMode = workoutRes['mode'].toString();
        }
        if (workoutRes['mode_emoji'] != null) {
          _modeEmoji = workoutRes['mode_emoji'].toString();
        }
        if (workoutRes['mode_name'] != null) {
          _modeName = workoutRes['mode_name'].toString();
        }
        if (workoutRes['goal'] != null && workoutRes['goal'].toString().isNotEmpty) {
          _workoutGoal = workoutRes['goal'].toString();
        }
        if (_workoutActive && workoutRes['people'] is List) {
          _workoutPartners = (workoutRes['people'] as List)
              .map((p) => Map<String, dynamic>.from(p as Map))
              .toList();
        } else {
          _workoutPartners = [];
        }
      }
    } catch (_) {
      // Resiliente a falhas temporárias de GPS/rede
    } finally {
      _isLocating = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }
}
