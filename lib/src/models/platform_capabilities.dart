import 'package:flutter/foundation.dart';

/// Supported application targets: Android and iOS exclusively.
class PlatformCapabilities {
  const PlatformCapabilities({
    required this.target,
    this.web = false,
    this.secureContext = true,
  });

  final TargetPlatform target;
  final bool web;
  final bool secureContext;

  bool get mobileNative =>
      !web &&
      (target == TargetPlatform.android || target == TargetPlatform.iOS);
  bool get supported => mobileNative;
  bool get location => supported;
  bool get microphone => supported;
  bool get cameraCapture => supported;
  bool get openSystemSettings => supported;
  bool get googleLogin => supported;
  bool get appleLogin => supported;
  String get name => target == TargetPlatform.android
      ? 'Android'
      : target == TargetPlatform.iOS
      ? 'iOS'
      : 'Plataforma não suportada';
  String get permissionHelp =>
      'Gerencie câmera, microfone, fotos e localização nos ajustes do aplicativo.';
}
