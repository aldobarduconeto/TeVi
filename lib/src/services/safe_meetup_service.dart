import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/safe_meetup_model.dart';
import '../pages/components/fake_call_screen.dart';

/// Serviço 100% local de segurança para encontros presenciais.
/// Controla o timer de check-in, código de coação, falsa chamada de emergência
/// e emissão de SOS silencioso para contato de confiança.
class SafeMeetupService extends ChangeNotifier {
  SafeMeetupService({SharedPreferencesAsync? prefs})
      : _prefs = prefs ?? SharedPreferencesAsync() {
    _initialize();
  }

  static final SafeMeetupService instance = SafeMeetupService();

  final SharedPreferencesAsync _prefs;
  static const _configKey = 'tevi.safe_meetup.config.v1';
  static const _sessionKey = 'tevi.safe_meetup.session.v1';

  SafeMeetupConfig _config = const SafeMeetupConfig();
  SafeMeetupSession? _session;

  Timer? _countdownTimer;
  Timer? _fakeCallTimer;
  int? _fakeCallCountdown;

  SafeMeetupConfig get config => _config;
  SafeMeetupSession? get session => _session;
  bool get isEnabled => _config.enabled;
  bool get hasActiveMeetup => isEnabled && (_session?.isActive ?? false);
  int? get scheduledFakeCallCountdown => _fakeCallCountdown;

  bool isMeetupActiveFor(String partnerId) =>
      hasActiveMeetup && _session?.partnerId == partnerId;

  /// Permite ao usuário habilitar ou desabilitar o Modo Encontro Seguro a qualquer momento.
  Future<void> setEnabled(bool enabled) async {
    if (_config.enabled == enabled) return;
    _config = _config.copyWith(enabled: enabled);
    await _prefs.setString(_configKey, jsonEncode(_config.toJson()));

    // Se desabilitado, limpa timers e cancela qualquer sessão ativa em execução
    if (!enabled) {
      _countdownTimer?.cancel();
      _countdownTimer = null;
      cancelScheduledFakeCall();
      if (_session != null && _session!.isActive) {
        _session!.status = SafeMeetupStatus.cancelled;
        await _saveSession();
      }
    }
    notifyListeners();
  }

  Future<void> _initialize() async {
    try {
      final configJson = await _prefs.getString(_configKey);
      if (configJson != null) {
        _config = SafeMeetupConfig.fromJson(
          Map<String, dynamic>.from(jsonDecode(configJson) as Map),
        );
      }

      final sessionJson = await _prefs.getString(_sessionKey);
      if (sessionJson != null) {
        final restored = SafeMeetupSession.fromJson(
          Map<String, dynamic>.from(jsonDecode(sessionJson) as Map),
        );
        // Only resume if not already expired by more than 2 hours
        if (restored.isActive) {
          _session = restored;
          _startTimer();
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> updateConfig(SafeMeetupConfig newConfig) async {
    _config = newConfig;
    await _prefs.setString(_configKey, jsonEncode(newConfig.toJson()));
    notifyListeners();
  }

  /// Inicia uma nova sessão de Encontro Seguro com o parceiro.
  Future<void> startMeetup({
    required String partnerId,
    required String partnerName,
    String locationNote = '',
    int? durationMinutes,
  }) async {
    final minutes = durationMinutes ?? _config.defaultDurationMinutes;
    final now = DateTime.now();

    _session = SafeMeetupSession(
      sessionId: 'meetup_${now.millisecondsSinceEpoch}',
      partnerId: partnerId,
      partnerName: partnerName,
      locationNote: locationNote,
      startTime: now,
      targetEndTime: now.add(Duration(minutes: minutes)),
      status: SafeMeetupStatus.active,
      attemptsLeft: 3,
    );

    await _saveSession();
    _startTimer();
    HapticFeedback.mediumImpact();
    notifyListeners();
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_session == null || !_session!.isActive) {
        timer.cancel();
        return;
      }

      final remaining = _session!.remainingSeconds;
      if (remaining <= 0 && _session!.status == SafeMeetupStatus.active) {
        _session!.status = SafeMeetupStatus.checkInDue;
        _saveSession();
        // Emite vibração sutil de aviso de que o check-in venceu
        HapticFeedback.heavyImpact();
      }

      if (_session!.status == SafeMeetupStatus.checkInDue) {
        // Alerta periódico a cada 15s de atraso
        if (DateTime.now().second % 15 == 0) {
          HapticFeedback.vibrate();
        }
      }

      notifyListeners();
    });
  }

  /// Estende o encontro em [additionalMinutes] (ex: o encontro está ótimo).
  Future<void> extendMeetup(int additionalMinutes) async {
    if (_session == null) return;
    final baseTime = _session!.targetEndTime.isAfter(DateTime.now())
        ? _session!.targetEndTime
        : DateTime.now();

    _session!.targetEndTime = baseTime.add(Duration(minutes: additionalMinutes));
    _session!.status = SafeMeetupStatus.active;
    _session!.attemptsLeft = 3;

    await _saveSession();
    HapticFeedback.selectionClick();
    notifyListeners();
  }

  /// Submete o PIN de verificação.
  /// Suporta tanto o PIN regular quanto o código de coação (duress PIN).
  Future<CheckInResult> submitCheckIn(String enteredPin) async {
    if (_session == null) return CheckInResult.noActiveSession;

    final cleanPin = enteredPin.trim();

    // 1. Código de Coação acionado
    if (cleanPin == _config.duressCode.trim()) {
      _session!.status = SafeMeetupStatus.completed;
      await _saveSession();
      _countdownTimer?.cancel();

      // Dispara o SOS em segundo plano silenciosamente
      unawaited(
        triggerSilentSos(
          reason: 'Código de coação inserido pelo usuário.',
        ),
      );

      notifyListeners();
      return CheckInResult.duressTriggered;
    }

    // 2. PIN Correto
    if (cleanPin == _config.pinCode.trim()) {
      _session!.status = SafeMeetupStatus.completed;
      await _saveSession();
      _countdownTimer?.cancel();
      HapticFeedback.mediumImpact();
      notifyListeners();
      return CheckInResult.success;
    }

    // 3. PIN Incorreto
    _session!.attemptsLeft--;
    HapticFeedback.heavyImpact();
    await _saveSession();

    if (_session!.attemptsLeft <= 0) {
      unawaited(
        triggerSilentSos(
          reason: 'Número máximo de tentativas de PIN incorretas atingido.',
        ),
      );
      notifyListeners();
      return CheckInResult.attemptsExhausted;
    }

    notifyListeners();
    return CheckInResult.incorrectPin;
  }

  /// Cancela o encontro voluntariamente pelo usuário com validação de PIN.
  Future<bool> cancelMeetupWithPin(String enteredPin) async {
    final result = await submitCheckIn(enteredPin);
    return result == CheckInResult.success ||
        result == CheckInResult.duressTriggered;
  }

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Agenda uma Falsa Chamada de Emergência realista.
  void scheduleFakeCall({
    BuildContext? context,
    int delaySeconds = 20,
    String? callerName,
  }) {
    cancelScheduledFakeCall();
    final navigator = (context != null)
        ? Navigator.of(context, rootNavigator: true)
        : navigatorKey.currentState;
    final effectiveCallerName = callerName ?? _config.fakeCallerName;

    _fakeCallCountdown = delaySeconds;
    notifyListeners();

    _fakeCallTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_fakeCallCountdown == null || _fakeCallCountdown! <= 1) {
        t.cancel();
        _fakeCallCountdown = null;
        notifyListeners();

        // Abre a tela realista de chamada recebida
        navigator?.push(
          PageRouteBuilder<void>(
            opaque: false,
            pageBuilder: (_, __, ___) => FakeCallScreen(
              callerName: effectiveCallerName,
            ),
          ),
        );
      } else {
        _fakeCallCountdown = _fakeCallCountdown! - 1;
        notifyListeners();
      }
    });

    HapticFeedback.selectionClick();
  }

  void cancelScheduledFakeCall() {
    _fakeCallTimer?.cancel();
    _fakeCallTimer = null;
    _fakeCallCountdown = null;
    notifyListeners();
  }

  /// Dispara a mensagem de socorro SMS / WhatsApp para o contato de confiança.
  Future<bool> triggerSilentSos({String? reason}) async {
    if (_session != null) {
      _session!.status = SafeMeetupStatus.sosTriggered;
      await _saveSession();
    }

    final phone = _config.trustedContactPhone.replaceAll(RegExp(r'\D'), '');
    if (phone.isEmpty) {
      notifyListeners();
      return false;
    }

    final partner = _session?.partnerName ?? 'um encontro';
    final location = _session?.locationNote.isNotEmpty == true
        ? ' Local combinado: ${_session!.locationNote}.'
        : '';
    final reasonDetail = reason != null ? ' Motivo: $reason' : '';

    final fullMessage =
        '${_config.customSosMessage}\n\n'
        '• Encontro com: $partner.$location$reasonDetail\n'
        '• Horário de início: ${_session?.startTime.hour.toString().padLeft(2, '0')}:${_session?.startTime.minute.toString().padLeft(2, '0')}.\n'
        'Alerta emitido pelo Tevi Encontro Seguro.';

    final encoded = Uri.encodeComponent(fullMessage);
    final smsUri = Uri.parse('sms:$phone?body=$encoded');

    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        notifyListeners();
        return true;
      }
    } catch (_) {}

    // Fallback: Tenta abrir via WhatsApp
    try {
      final waUri = Uri.parse('https://wa.me/$phone?text=$encoded');
      if (await canLaunchUrl(waUri)) {
        await launchUrl(waUri, mode: LaunchMode.externalApplication);
        notifyListeners();
        return true;
      }
    } catch (_) {}

    notifyListeners();
    return false;
  }

  Future<void> _saveSession() async {
    if (_session == null) {
      await _prefs.remove(_sessionKey);
    } else {
      await _prefs.setString(_sessionKey, jsonEncode(_session!.toJson()));
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _fakeCallTimer?.cancel();
    super.dispose();
  }
}

enum CheckInResult {
  success,
  duressTriggered,
  incorrectPin,
  attemptsExhausted,
  noActiveSession,
}
