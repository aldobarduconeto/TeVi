/// Estados possíveis de um Encontro Seguro.
enum SafeMeetupStatus {
  idle,
  active,
  checkInDue,
  sosTriggered,
  completed,
  cancelled,
}

/// Configurações gerais e persistentes de segurança do usuário.
class SafeMeetupConfig {
  const SafeMeetupConfig({
    this.enabled = true,
    this.trustedContactName = 'Contato de Confiança',
    this.trustedContactPhone = '',
    this.pinCode = '1234',
    this.duressCode = '9999',
    this.defaultDurationMinutes = 45,
    this.fakeCallerName = 'Mãe',
    this.customSosMessage =
        'Olá! Ativei o Modo Encontro Seguro do Tevi. Se você recebeu este alerta, '
        'não consegui confirmar meu check-in de segurança a tempo ou acionei socorro silencioso. '
        'Por favor, tente me ligar imediatamente.',
  });

  final bool enabled;
  final String trustedContactName;
  final String trustedContactPhone;
  final String pinCode;
  final String duressCode;
  final int defaultDurationMinutes;
  final String fakeCallerName;
  final String customSosMessage;

  bool get hasTrustedContact =>
      trustedContactPhone.trim().isNotEmpty &&
      trustedContactPhone.replaceAll(RegExp(r'\D'), '').length >= 8;

  SafeMeetupConfig copyWith({
    bool? enabled,
    String? trustedContactName,
    String? trustedContactPhone,
    String? pinCode,
    String? duressCode,
    int? defaultDurationMinutes,
    String? fakeCallerName,
    String? customSosMessage,
  }) => SafeMeetupConfig(
    enabled: enabled ?? this.enabled,
    trustedContactName: trustedContactName ?? this.trustedContactName,
    trustedContactPhone: trustedContactPhone ?? this.trustedContactPhone,
    pinCode: pinCode ?? this.pinCode,
    duressCode: duressCode ?? this.duressCode,
    defaultDurationMinutes:
        defaultDurationMinutes ?? this.defaultDurationMinutes,
    fakeCallerName: fakeCallerName ?? this.fakeCallerName,
    customSosMessage: customSosMessage ?? this.customSosMessage,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'trustedContactName': trustedContactName,
    'trustedContactPhone': trustedContactPhone,
    'pinCode': pinCode,
    'duressCode': duressCode,
    'defaultDurationMinutes': defaultDurationMinutes,
    'fakeCallerName': fakeCallerName,
    'customSosMessage': customSosMessage,
  };

  factory SafeMeetupConfig.fromJson(Map<String, dynamic> json) =>
      SafeMeetupConfig(
        enabled: json['enabled'] as bool? ?? true,
        trustedContactName:
            json['trustedContactName'] as String? ?? 'Contato de Confiança',
        trustedContactPhone: json['trustedContactPhone'] as String? ?? '',
        pinCode: json['pinCode'] as String? ?? '1234',
        duressCode: json['duressCode'] as String? ?? '9999',
        defaultDurationMinutes:
            json['defaultDurationMinutes'] as int? ?? 45,
        fakeCallerName: json['fakeCallerName'] as String? ?? 'Mãe',
        customSosMessage:
            json['customSosMessage'] as String? ??
            'Olá! Ativei o Modo Encontro Seguro do Tevi. Se você recebeu este alerta, '
            'não consegui confirmar meu check-in de segurança a tempo ou acionei socorro silencioso.',
      );
}

/// Sessão ativa de um encontro presencial monitorado pelo app.
class SafeMeetupSession {
  SafeMeetupSession({
    required this.sessionId,
    required this.partnerId,
    required this.partnerName,
    this.locationNote = '',
    required this.startTime,
    required this.targetEndTime,
    this.status = SafeMeetupStatus.active,
    this.attemptsLeft = 3,
  });

  final String sessionId;
  final String partnerId;
  final String partnerName;
  final String locationNote;
  final DateTime startTime;
  DateTime targetEndTime;
  SafeMeetupStatus status;
  int attemptsLeft;

  bool get isActive =>
      status == SafeMeetupStatus.active || status == SafeMeetupStatus.checkInDue;

  Duration get remainingDuration {
    final now = DateTime.now();
    if (now.isAfter(targetEndTime)) return Duration.zero;
    return targetEndTime.difference(now);
  }

  int get remainingSeconds => remainingDuration.inSeconds;
  int get remainingMinutes => remainingDuration.inMinutes;

  String get formattedRemaining {
    final rem = remainingDuration;
    final minutes = rem.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = rem.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (rem.inHours > 0) {
      return '${rem.inHours}h ${minutes}m';
    }
    return '$minutes:$seconds';
  }

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'partnerId': partnerId,
    'partnerName': partnerName,
    'locationNote': locationNote,
    'startTime': startTime.toIso8601String(),
    'targetEndTime': targetEndTime.toIso8601String(),
    'status': status.name,
    'attemptsLeft': attemptsLeft,
  };

  factory SafeMeetupSession.fromJson(Map<String, dynamic> json) =>
      SafeMeetupSession(
        sessionId: json['sessionId'] as String,
        partnerId: json['partnerId'] as String,
        partnerName: json['partnerName'] as String,
        locationNote: json['locationNote'] as String? ?? '',
        startTime: DateTime.parse(json['startTime'] as String),
        targetEndTime: DateTime.parse(json['targetEndTime'] as String),
        status: SafeMeetupStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => SafeMeetupStatus.idle,
        ),
        attemptsLeft: json['attemptsLeft'] as int? ?? 3,
      );
}
