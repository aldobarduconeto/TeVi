import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/safe_meetup_model.dart';
import '../../services/safe_meetup_service.dart';
import '../common.dart';
import '../theme/app_theme.dart';

/// Abre a folha de configurações e controle do Encontro Seguro.
void showSafeMeetupSheet(
  BuildContext context, {
  required String partnerName,
  required String partnerId,
  String? region,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (c) => _SafeMeetupSheetContent(
      partnerName: partnerName,
      partnerId: partnerId,
      region: region,
    ),
  );
}

class _SafeMeetupSheetContent extends StatefulWidget {
  const _SafeMeetupSheetContent({
    required this.partnerName,
    required this.partnerId,
    this.region,
  });

  final String partnerName;
  final String partnerId;
  final String? region;

  @override
  State<_SafeMeetupSheetContent> createState() =>
      _SafeMeetupSheetContentState();
}

class _SafeMeetupSheetContentState extends State<_SafeMeetupSheetContent> {
  final service = SafeMeetupService.instance;
  late int _selectedDuration;
  late TextEditingController _locationController;

  @override
  void initState() {
    super.initState();
    _selectedDuration = service.config.defaultDurationMinutes;
    _locationController = TextEditingController(
      text: widget.region ?? service.session?.locationNote ?? '',
    );
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final session = service.session;
        final hasActive = service.hasActiveMeetup;
        final isDue = session?.status == SafeMeetupStatus.checkInDue;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0A0C14) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark ? Colors.white12 : const Color(0xFFE2E6F2),
              width: 1,
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(context).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de arrasto
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Cabeçalho
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDue
                          ? const Color(0xFFFF3B30).withValues(alpha: 0.15)
                          : context.coral.withValues(alpha: isDark ? 0.22 : 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isDue
                          ? Icons.warning_amber_rounded
                          : Icons.shield_rounded,
                      color: isDue ? const Color(0xFFFF3B30) : context.coral,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDue
                              ? 'Check-in Vencido!'
                              : hasActive
                                  ? 'Encontro Seguro Ativo'
                                  : 'Modo Encontro Seguro',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          hasActive
                              ? 'Com ${session?.partnerName ?? widget.partnerName}'
                              : 'Segurança e tranquilidade em tempo real',
                          style: TextStyle(fontSize: 12, color: context.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: 'Ajustar Contato e PIN',
                    onPressed: () => _editTrustedContact(context),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              if (hasActive)
                _buildActiveSessionView(context, session!, isDue)
              else
                _buildStartMeetupView(context),
            ],
          ),
        );
      },
    );
  }

  // --- MODO ATIVO ---
  Widget _buildActiveSessionView(
    BuildContext context,
    SafeMeetupSession session,
    bool isDue,
  ) {
    return Column(
      children: [
        // Card do Timer (RepaintBoundary isola o redesenho dos segundos)
        RepaintBoundary(
          child: Container(
            padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDue
                ? const Color(0x22FF3B30)
                : context.coral.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDue ? const Color(0xFFFF3B30) : context.coral.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              Text(
                session.formattedRemaining,
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: isDue ? const Color(0xFFFF3B30) : context.coral,
                  letterSpacing: -1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isDue
                    ? 'Por favor, confirme que você está bem!'
                    : 'Tempo restante até o próximo check-in de segurança',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDue ? const Color(0xFFFF3B30) : context.muted,
                ),
              ),
            ],
          ),
        ),
        ),

        const SizedBox(height: 16),

        // Botão Principal: Fazer Check-in (Estou bem)
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: isDue ? const Color(0xFFFF3B30) : context.coral,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
          label: const Text(
            'Fazer Check-in (Confirmar que estou bem)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: () => _showPinDialog(context),
        ),

        const SizedBox(height: 10),

        // Botões de Ações Rápidas
        Row(
          children: [
            // Estender +30min
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add_alarm_rounded, size: 18),
                label: const Text('+30 min'),
                onPressed: () async {
                  await service.extendMeetup(30);
                  if (context.mounted) {
                    toast(context, 'Encontro estendido em 30 minutos.');
                  }
                },
              ),
            ),
            const SizedBox(width: 8),

            // Falsa Chamada
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.phone_callback_rounded, size: 18),
                label: Text(
                  service.scheduledFakeCallCountdown != null
                      ? 'Em ${service.scheduledFakeCallCountdown}s'
                      : 'Falsa Ligação',
                ),
                onPressed: () {
                  service.scheduleFakeCall(context: context, delaySeconds: 15);
                  Navigator.pop(context);
                  toast(context, '📞 Chamada programada para daqui a 15 segundos!');
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Botão SOS Manual
        TextButton.icon(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFFF3B30),
          ),
          icon: const Icon(Icons.emergency_rounded, size: 18),
          label: const Text('Disparar SOS Silencioso Imediato'),
          onPressed: () async {
            if (await confirm(
              context,
              'Disparar Alerta SOS?',
              'Sua mensagem de emergência e dados do encontro serão enviados para o contato de confiança cadastrado.',
            )) {
              final ok = await service.triggerSilentSos(
                reason: 'Acionado manualmente pelo usuário no aplicativo.',
              );
              if (context.mounted) {
                toast(
                  context,
                  ok
                      ? 'Alerta emitido para o contato de confiança!'
                      : 'Não foi possível enviar o alerta. Verifique o telefone.',
                );
              }
            }
          },
        ),
      ],
    );
  }

  // --- MODO CONFIGURAR NOVO ENCONTRO ---
  Widget _buildStartMeetupView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Contato de Confiança Cadastrado
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF131622)
                : const Color(0xFFF6F7FB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: service.config.hasTrustedContact
                  ? Colors.green.withValues(alpha: 0.3)
                  : Colors.orange.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Icon(
                service.config.hasTrustedContact
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
                color: service.config.hasTrustedContact
                    ? Colors.green
                    : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.config.hasTrustedContact
                          ? 'Contato de Socorro: ${service.config.trustedContactName}'
                          : 'Nenhum contato de socorro cadastrado',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    Text(
                      service.config.hasTrustedContact
                          ? service.config.trustedContactPhone
                          : 'Configure um telefone para receber alertas silenciosos.',
                      style: TextStyle(color: context.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _editTrustedContact(context),
                child: Text(service.config.hasTrustedContact ? 'Editar' : 'Adicionar'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Local ou Ponto de Encontro
        TextField(
          controller: _locationController,
          decoration: const InputDecoration(
            labelText: 'Local do encontro (opcional)',
            hintText: 'Ex.: Café Floresta, Parque Ibirapuera',
            prefixIcon: Icon(Icons.place_outlined),
          ),
        ),

        const SizedBox(height: 16),

        // Duração do Encontro
        const Text(
          'Duração estimada do encontro:',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [30, 45, 60, 90, 120].map((mins) {
            final isSelected = _selectedDuration == mins;
            return ChoiceChip(
              label: Text('$mins min'),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (_) => setState(() => _selectedDuration = mins),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),

        // Botão Iniciar Encontro Seguro
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: context.coral,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: const Icon(Icons.shield_rounded),
          label: const Text(
            'Iniciar Modo Encontro Seguro',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          onPressed: () async {
            await service.startMeetup(
              partnerId: widget.partnerId,
              partnerName: widget.partnerName,
              locationNote: _locationController.text.trim(),
              durationMinutes: _selectedDuration,
            );
            if (context.mounted) {
              Navigator.pop(context);
              toast(
                context,
                '🛡️ Modo Encontro Seguro ativo para $_selectedDuration minutos!',
              );
            }
          },
        ),

        const SizedBox(height: 12),

        // Botão Agendar Falsa Ligação Imediata
        OutlinedButton.icon(
          icon: const Icon(Icons.phone_callback_rounded, size: 18),
          label: const Text('📞 Falsa Ligação Rápida (em 20s)'),
          onPressed: () {
            service.scheduleFakeCall(context: context, delaySeconds: 20);
            Navigator.pop(context);
            toast(context, '📞 Chamada programada para daqui a 20 segundos!');
          },
        ),
      ],
    );
  }

  // --- DIÁLOGO DO PIN ---
  void _showPinDialog(BuildContext context) {
    final pinController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Colors.blueAccent),
            SizedBox(width: 10),
            Text('Tudo bem por aí?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Confirme que você está em segurança digitando seu PIN de 4 dígitos.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                letterSpacing: 14,
                fontWeight: FontWeight.bold,
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                counterText: '',
                hintText: '••••',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tentativas restantes: ${service.session?.attemptsLeft ?? 3}',
              style: TextStyle(fontSize: 11, color: context.muted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final pin = pinController.text.trim();
              if (pin.length < 4) return;
              Navigator.pop(c);

              final result = await service.submitCheckIn(pin);
              if (context.mounted) {
                switch (result) {
                  case CheckInResult.success:
                    Navigator.pop(context); // Fecha o sheet
                    toast(context, '✓ Check-in confirmado! Você está seguro.');
                    break;
                  case CheckInResult.duressTriggered:
                    Navigator.pop(context); // Fecha o sheet
                    // Disfarce para o agressor: mostra mensagem normal, mas SOS já foi disparado
                    toast(context, '✓ Check-in concluído.');
                    break;
                  case CheckInResult.incorrectPin:
                    toast(
                      context,
                      'PIN incorreto! Restam ${service.session?.attemptsLeft} tentativas.',
                    );
                    break;
                  case CheckInResult.attemptsExhausted:
                    Navigator.pop(context);
                    toast(context, '🚨 Tentativas esgotadas! Alerta SOS emitido.');
                    break;
                  case CheckInResult.noActiveSession:
                    break;
                }
              }
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  // --- DIÁLOGO DE CONFIGURAÇÃO DO CONTATO E PIN ---
  void _editTrustedContact(BuildContext context) {
    final cfg = service.config;
    final nameController = TextEditingController(text: cfg.trustedContactName);
    final phoneController = TextEditingController(text: cfg.trustedContactPhone);
    final pinController = TextEditingController(text: cfg.pinCode);
    final duressController = TextEditingController(text: cfg.duressCode);
    final fakeCallerController = TextEditingController(text: cfg.fakeCallerName);

    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Configurações do Encontro Seguro'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Contato de Emergência (SMS/WhatsApp):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome do contato',
                  hintText: 'Ex.: Mãe, Amiga Ana',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telefone com DDD',
                  hintText: 'Ex.: 11999998888',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'PIN de Segurança:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: 'PIN de Confirmação (Estou Bem)',
                  hintText: 'Ex.: 1234',
                  counterText: '',
                  prefixIcon: Icon(Icons.pin_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: duressController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: 'Código de Coação (Dispara SOS silencioso)',
                  hintText: 'Ex.: 9999',
                  counterText: '',
                  prefixIcon: Icon(Icons.shield_outlined),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Se alguém te obrigar a digitar o PIN, use o Código de Coação. A tela fechará normalmente, mas um SOS será emitido em segundo plano.',
                style: TextStyle(fontSize: 10, color: Colors.grey, height: 1.3),
              ),
              const SizedBox(height: 16),
              const Text(
                'Falsa Ligação:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: fakeCallerController,
                decoration: const InputDecoration(
                  labelText: 'Nome de quem está "ligando"',
                  hintText: 'Ex.: Mãe, Trabalho, Portaria',
                  prefixIcon: Icon(Icons.phone_in_talk_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              await service.updateConfig(
                cfg.copyWith(
                  trustedContactName: nameController.text.trim(),
                  trustedContactPhone: phoneController.text.trim(),
                  pinCode: pinController.text.trim().isNotEmpty
                      ? pinController.text.trim()
                      : '1234',
                  duressCode: duressController.text.trim().isNotEmpty
                      ? duressController.text.trim()
                      : '9999',
                  fakeCallerName: fakeCallerController.text.trim().isNotEmpty
                      ? fakeCallerController.text.trim()
                      : 'Mãe',
                ),
              );
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
