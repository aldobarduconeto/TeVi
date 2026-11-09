import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tela ultra-realista de chamada telefônica simulada (Fake Escape Call).
/// Serve como saída educada e segura para encontros desconfortáveis.
class FakeCallScreen extends StatefulWidget {
  const FakeCallScreen({
    super.key,
    required this.callerName,
    this.callerNumber = 'Celular',
  });

  final String callerName;
  final String callerNumber;

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen>
    with SingleTickerProviderStateMixin {
  bool _callAccepted = false;
  int _callDurationSeconds = 0;
  Timer? _callDurationTimer;
  Timer? _vibrationTimer;

  bool _isMuted = false;
  bool _isSpeaker = false;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    // Vibração simulando toque telefônico a cada 1.5s
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (!_callAccepted && mounted) {
        HapticFeedback.vibrate();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _callDurationTimer?.cancel();
    _vibrationTimer?.cancel();
    super.dispose();
  }

  void _acceptCall() {
    _vibrationTimer?.cancel();
    HapticFeedback.mediumImpact();
    setState(() {
      _callAccepted = true;
    });

    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _callDurationSeconds++;
        });
      }
    });
  }

  void _endCall() {
    _callDurationTimer?.cancel();
    _vibrationTimer?.cancel();
    HapticFeedback.heavyImpact();
    Navigator.of(context).pop();
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _endCall();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _callAccepted
                ? _buildActiveCallUI()
                : _buildIncomingCallUI(),
          ),
        ),
      ),
    );
  }

  // --- TELA 1: CHAMADA RECEBIDA (RINGING) ---
  Widget _buildIncomingCallUI() {
    return Column(
      key: const ValueKey('incoming_call'),
      children: [
        const SizedBox(height: 48),

        // Nome e Tipo de Chamada
        Text(
          widget.callerName,
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          widget.callerNumber,
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.65),
          ),
        ),

        const Spacer(),

        // Avatar Pulsante Realista (RepaintBoundary isola o redesenho da animação)
        RepaintBoundary(
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.05).animate(
              CurvedAnimation(
                parent: _pulseController,
                curve: Curves.easeInOut,
              ),
            ),
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.person_rounded,
                size: 64,
                color: Colors.white,
              ),
            ),
          ),
        ),

        const Spacer(),

        // Ações Rápidas (Lembrar / Mensagem)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 50),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCallTopButton(
                icon: Icons.alarm_rounded,
                label: 'Lembrar',
                onTap: _endCall,
              ),
              _buildCallTopButton(
                icon: Icons.message_rounded,
                label: 'Mensagem',
                onTap: _endCall,
              ),
            ],
          ),
        ),

        const SizedBox(height: 48),

        // Botões de Atender (Verde) e Recusar (Vermelho)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 44),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Botão Recusar
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _endCall,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF3B30),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.call_end_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Recusar',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),

              // Botão Atender
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _acceptCall,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: Color(0xFF34C759),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x6634C759),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.call_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Atender',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 40),
      ],
    );
  }

  // --- TELA 2: CHAMADA ATIVA (IN CALL) ---
  Widget _buildActiveCallUI() {
    return Column(
      key: const ValueKey('active_call'),
      children: [
        const SizedBox(height: 48),

        // Nome do Contato
        Text(
          widget.callerName,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Contador da Chamada
        Text(
          _formatDuration(_callDurationSeconds),
          style: TextStyle(
            fontSize: 18,
            color: Colors.white.withValues(alpha: 0.8),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),

        const Spacer(),

        // Grade de Botões Realista de Chamada
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildInCallButton(
                    icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    label: 'Mudo',
                    active: _isMuted,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _isMuted = !_isMuted);
                    },
                  ),
                  _buildInCallButton(
                    icon: Icons.dialpad_rounded,
                    label: 'Teclado',
                    onTap: () => HapticFeedback.selectionClick(),
                  ),
                  _buildInCallButton(
                    icon: _isSpeaker
                        ? Icons.volume_up_rounded
                        : Icons.volume_down_rounded,
                    label: 'Alto-falante',
                    active: _isSpeaker,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _isSpeaker = !_isSpeaker);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildInCallButton(
                    icon: Icons.add_ic_call_rounded,
                    label: 'Adicionar',
                    onTap: () => HapticFeedback.selectionClick(),
                  ),
                  _buildInCallButton(
                    icon: Icons.videocam_rounded,
                    label: 'FaceTime',
                    onTap: () => HapticFeedback.selectionClick(),
                  ),
                  _buildInCallButton(
                    icon: Icons.account_circle_rounded,
                    label: 'Contatos',
                    onTap: () => HapticFeedback.selectionClick(),
                  ),
                ],
              ),
            ],
          ),
        ),

        const Spacer(),

        // Botão Finalizar Chamada (Vermelho Grande)
        GestureDetector(
          onTap: _endCall,
          child: Container(
            width: 74,
            height: 74,
            decoration: const BoxDecoration(
              color: Color(0xFFFF3B30),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x66FF3B30),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.call_end_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
        ),

        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildCallTopButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 26),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildInCallButton({
    required IconData icon,
    required String label,
    bool active = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? Colors.white : Colors.white.withValues(alpha: 0.14),
            ),
            child: Icon(
              icon,
              size: 28,
              color: active ? Colors.black : Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
