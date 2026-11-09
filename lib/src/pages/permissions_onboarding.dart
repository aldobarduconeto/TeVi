import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme/app_theme.dart';
import 'theme/liquid_glass.dart';

class PermissionsOnboardingScreen extends StatefulWidget {
  const PermissionsOnboardingScreen({super.key, required this.onCompleted});

  final VoidCallback onCompleted;

  static const String prefKey = 'tevi_permissions_onboarded_v1';

  static Future<bool> hasCompleted() async {
    final prefs = SharedPreferencesAsync();
    return await prefs.getBool(prefKey) ?? false;
  }

  static Future<void> markCompleted() async {
    final prefs = SharedPreferencesAsync();
    await prefs.setBool(prefKey, true);
  }

  @override
  State<PermissionsOnboardingScreen> createState() =>
      _PermissionsOnboardingScreenState();
}

class _PermissionsOnboardingScreenState
    extends State<PermissionsOnboardingScreen> with WidgetsBindingObserver {
  bool locationGranted = false;
  bool microphoneGranted = false;
  bool cameraGranted = false;
  bool photosGranted = false;
  bool notificationsGranted = false;
  bool checking = true;
  bool requesting = false;
  bool _popupOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkCurrentStatuses().then((_) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_popupOpen) {
            _showWelcomePermissionsPopup();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkCurrentStatuses();
    }
  }

  Future<void> _checkCurrentStatuses() async {
    final loc = await Permission.locationWhenInUse.isGranted ||
        await Permission.location.isGranted;
    final mic = await Permission.microphone.isGranted;
    final cam = await Permission.camera.isGranted;
    final pho = await Permission.photos.isGranted ||
        await Permission.storage.isGranted;
    final notif = await Permission.notification.isGranted;

    if (mounted) {
      setState(() {
        locationGranted = loc;
        microphoneGranted = mic;
        cameraGranted = cam;
        photosGranted = pho;
        notificationsGranted = notif;
        checking = false;
      });
    }
  }

  Future<void> _requestSingle(
    Permission permission, [
    void Function(void Function())? setModalState,
  ]) async {
    await permission.request();
    await _checkCurrentStatuses();
    if (setModalState != null && mounted) {
      setModalState(() {});
    }
  }

  Future<void> _requestAll([void Function(void Function())? setModalState]) async {
    if (requesting) return;
    setState(() => requesting = true);
    if (setModalState != null) {
      setModalState(() => requesting = true);
    }

    try {
      await [
        Permission.locationWhenInUse,
        Permission.microphone,
        Permission.camera,
        Permission.photos,
        Permission.notification,
      ].request();

      await _checkCurrentStatuses();
      if (setModalState != null && mounted) {
        setModalState(() {});
      }
    } finally {
      if (mounted) {
        setState(() => requesting = false);
        if (setModalState != null) {
          setModalState(() => requesting = false);
        }
      }
    }
  }

  Future<void> _finish() async {
    await PermissionsOnboardingScreen.markCompleted();
    widget.onCompleted();
  }

  bool get allEssentialGranted =>
      locationGranted && microphoneGranted && (photosGranted || cameraGranted);

  void _showWelcomePermissionsPopup() {
    if (_popupOpen || !mounted) return;
    _popupOpen = true;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (modalContext) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          final isDark = Theme.of(modalContext).brightness == Brightness.dark;

          return Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141724) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.16)
                    : Colors.white.withValues(alpha: 0.8),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: modalContext.coral.withValues(alpha: 0.18),
                  blurRadius: 36,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Barra de arraste
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Ícone e Título de Boas-Vindas
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: [
                                modalContext.coral.withValues(alpha: 0.25),
                                const Color(0xFF6F4BD8).withValues(alpha: 0.35),
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Image.asset(
                            'assets/branding/app_icon.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Boas-vindas ao Tevi! 🎉',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: modalContext.ink,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Conexões no mundo real com privacidade',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: modalContext.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'Para conectar você a pessoas por onde seus caminhos se cruzarem, precisamos ativar algumas permissões essenciais no seu dispositivo:',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: modalContext.muted,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Lista de Permissões Compacta em Liquid Glass
                    _buildModalPermissionItem(
                      modalContext: modalContext,
                      icon: Icons.location_on_rounded,
                      title: 'Localização Aproximada',
                      tag: 'Privacidade Total',
                      tagColor: const Color(0xFF6F4BD8),
                      description:
                          'Detecta cruzamentos sem salvar trajetos ou coordenadas exatas.',
                      granted: locationGranted,
                      onGrant: () => _requestSingle(
                        Permission.locationWhenInUse,
                        setModalState,
                      ),
                    ),
                    const SizedBox(height: 10),

                    _buildModalPermissionItem(
                      modalContext: modalContext,
                      icon: Icons.mic_rounded,
                      title: 'Microfone',
                      tag: 'Áudio P2P',
                      tagColor: modalContext.coral,
                      description:
                          'Para mensagens de voz e chamadas diretas criptografadas.',
                      granted: microphoneGranted,
                      onGrant: () => _requestSingle(
                        Permission.microphone,
                        setModalState,
                      ),
                    ),
                    const SizedBox(height: 10),

                    _buildModalPermissionItem(
                      modalContext: modalContext,
                      icon: Icons.camera_alt_rounded,
                      title: 'Câmera e Fotos',
                      tag: 'Perfil & Mídia',
                      tagColor: const Color(0xFF2E7D32),
                      description:
                          'Para selecionar foto de perfil e mídias no chat P2P.',
                      granted: cameraGranted && photosGranted,
                      onGrant: () async {
                        await Permission.camera.request();
                        await Permission.photos.request();
                        await _checkCurrentStatuses();
                        if (mounted) setModalState(() {});
                      },
                    ),
                    const SizedBox(height: 10),

                    _buildModalPermissionItem(
                      modalContext: modalContext,
                      icon: Icons.notifications_rounded,
                      title: 'Notificações',
                      tag: 'Segundo Plano',
                      tagColor: const Color(0xFFE65100),
                      description:
                          'Avisa quando houver novos cruzamentos e mensagens.',
                      granted: notificationsGranted,
                      onGrant: () => _requestSingle(
                        Permission.notification,
                        setModalState,
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Botão Principal no Popup
                    FilledButton(
                      onPressed: requesting
                          ? null
                          : () async {
                              await _requestAll(setModalState);
                              if (allEssentialGranted && modalContext.mounted) {
                                Navigator.pop(modalContext);
                                await _finish();
                              }
                            },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        backgroundColor: modalContext.coral,
                        elevation: 3,
                        shadowColor: modalContext.coral.withValues(alpha: 0.35),
                      ),
                      child: requesting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  allEssentialGranted
                                      ? Icons.arrow_forward_rounded
                                      : Icons.verified_user_rounded,
                                  size: 19,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  allEssentialGranted
                                      ? 'Continuar para o Aplicativo'
                                      : 'Permitir Recursos e Continuar',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 10),

                    // Continuar mesmo assim
                    TextButton(
                      onPressed: () {
                        Navigator.pop(modalContext);
                      },
                      child: Text(
                        'Conhecer o app primeiro',
                        style: TextStyle(
                          color: modalContext.muted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      _popupOpen = false;
      if (mounted) setState(() {});
    });
  }

  Widget _buildModalPermissionItem({
    required BuildContext modalContext,
    required IconData icon,
    required String title,
    required String tag,
    required Color tagColor,
    required String description,
    required bool granted,
    required VoidCallback onGrant,
  }) {
    return LiquidGlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: granted
                  ? const Color(0xFF2E7D32).withValues(alpha: 0.14)
                  : modalContext.coral.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 20,
              color: granted ? const Color(0xFF2E7D32) : modalContext.coral,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: tagColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: tagColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: modalContext.muted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (granted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, size: 12, color: Color(0xFF2E7D32)),
                  SizedBox(width: 3),
                  Text(
                    'Ativo',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            )
          else
            TextButton(
              onPressed: onGrant,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Permitir',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: modalContext.coral,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: checking
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 580),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 10),

                        // Banner de Apresentação Hero Tevi
                        LiquidGlassContainer(
                          borderRadius: 28,
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Container(
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(26),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      context.coral.withValues(alpha: 0.3),
                                      const Color(0xFF6F4BD8).withValues(alpha: 0.4),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: context.coral.withValues(alpha: 0.25),
                                      blurRadius: 24,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Image.asset(
                                  'assets/branding/app_icon.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'Tevi',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.2,
                                  color: context.ink,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: context.coral.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'CONEXÕES NO MUNDO REAL',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                    color: context.coral,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Aproxime-se de pessoas onde seus caminhos se cruzam, com segurança e controle total dos seus dados.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: context.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 3 Pilares do Tevi Apresentados
                        _buildFeatureCard(
                          icon: Icons.directions_walk_rounded,
                          color: const Color(0xFF6F4BD8),
                          title: '1. Cruzamento de Caminhos',
                          description:
                              'Identifica encontros casuais quando você cruza com outras pessoas na sua rotina (parques, cafés, metrô).',
                        ),
                        const SizedBox(height: 12),

                        _buildFeatureCard(
                          icon: Icons.shield_rounded,
                          color: context.coral,
                          title: '2. Armazenamento 100% Local',
                          description:
                              'Seus dados ficam exclusivamente no seu celular, sem envio para servidores na nuvem. Sem gravação de rotas e sem rastreamento.',
                        ),
                        const SizedBox(height: 12),

                        _buildFeatureCard(
                          icon: Icons.chat_bubble_outline_rounded,
                          color: const Color(0xFF2E7D32),
                          title: '3. Chat Direto P2P via WebRTC',
                          description:
                              'Comunicação direta entre dispositivos sem intermediários, com indicador de visualização e presença.',
                        ),
                        const SizedBox(height: 28),

                        // Botão Principal para Abrir o Popup de Permissões ou Continuar
                        FilledButton(
                          onPressed: () {
                            if (allEssentialGranted) {
                              _finish();
                            } else {
                              _showWelcomePermissionsPopup();
                            }
                          },
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                            backgroundColor: context.coral,
                            elevation: 4,
                            shadowColor: context.coral.withValues(alpha: 0.35),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                allEssentialGranted
                                    ? Icons.arrow_forward_rounded
                                    : Icons.celebration_rounded,
                                size: 20,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                allEssentialGranted
                                    ? 'Entrar no Tevi'
                                    : 'Configurar Permissões e Começar',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Botão secundário para quem quiser prosseguir
                        Center(
                          child: TextButton.icon(
                            onPressed: _finish,
                            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                            label: const Text('Continuar para login'),
                            style: TextButton.styleFrom(
                              foregroundColor: context.muted,
                              textStyle: const TextStyle(fontSize: 12.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return LiquidGlassContainer(
      borderRadius: 22,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: context.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
