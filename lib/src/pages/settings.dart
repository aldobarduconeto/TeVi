import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/app_theme_preference.dart';
import '../models/location_permission_info.dart';
import '../models/sync_info.dart';
import '../models/user_settings.dart';
import '../services/api.dart';
import '../services/device_permissions_service.dart';
import '../services/location_service.dart';
import '../services/media_service.dart';
import '../services/platform_support.dart';
import 'admin.dart';
import 'common.dart';
import 'components/apple_login_button.dart';
import 'components/google_login_button.dart';
import 'components/password_dialog.dart';
import 'components/profile_editor.dart';
import 'components/safe_meetup_dialog.dart';
import '../services/safe_meetup_service.dart';
import 'theme/app_theme.dart';
import 'theme/liquid_glass.dart';

class SettingsScreen extends StatefulWidget {
  final Api api;
  const SettingsScreen({
    super.key,
    required this.api,
    this.embedded = false,
    this.permissions = const DevicePermissionsService(),
  });
  final bool embedded;
  final DevicePermissionsService permissions;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool busy = false;
  late Future<SyncInfo> storage;
  late Future<LocationPermissionInfo> permissionStatus;
  String category = 'Tudo';

  // Workout state
  bool _workoutActive = false;
  String _workoutGoal = 'Hipertrofia';
  bool _loadingWorkout = false;

  Future<T> observe<T>(Future<T> future) {
    unawaited(future.then<void>((_) {}, onError: (Object _, StackTrace _) {}));
    return future;
  }

  @override
  void initState() {
    super.initState();
    storage = observe(widget.api.storageStatus());
    permissionStatus = observe(widget.permissions.status());
    _loadWorkoutStatus();
  }

  Future<void> _loadWorkoutStatus() async {
    try {
      final res = await widget.api.request('GET', '/workout/status');
      if (mounted && res is Map) {
        setState(() {
          _workoutActive = res['active'] == true;
          if (res['goal'] != null && res['goal'].toString().isNotEmpty) {
            _workoutGoal = res['goal'].toString();
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleWorkout(bool active) async {
    if (_loadingWorkout) return;
    setState(() => _loadingWorkout = true);
    try {
      await widget.api.request('POST', '/workout/status', {
        'active': active,
        'goal': _workoutGoal,
      });
      if (mounted) {
        setState(() => _workoutActive = active);
        toast(
          context,
          active
              ? 'Modo Workout ativado! Você está visível para parceiros de treino.'
              : 'Modo Workout desativado.',
        );
      }
    } catch (e) {
      if (mounted) toast(context, 'Não foi possível alterar o Modo Workout.');
    } finally {
      if (mounted) setState(() => _loadingWorkout = false);
    }
  }

  void refreshStorage() {
    if (!mounted) return;
    final next = observe(api.storageStatus());
    setState(() {
      storage = next;
    });
  }

  void refreshPermissions() {
    if (!mounted) return;
    final next = observe(widget.permissions.status());
    setState(() {
      permissionStatus = next;
    });
  }

  String clockLabel(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  Future<void> discoveryPreferences() async {
    final context = this.context;
    final s = api.settings;
    var ages = RangeValues(
      (s['min_age'] as num).toDouble(),
      (s['max_age'] as num).toDouble(),
    );
    var days = s['period_days'] as int;
    var interest = s['interest'] as String;
    final interests = {
      '',
      'Café',
      'Música',
      'Cinema',
      'Arte',
      'Viagens',
      'Corrida',
      'Livros',
      'Fotografia',
      'Treino / Academia',
      interest,
    };
    final saved = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Preferências de descoberta'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Faixa de idade: ${ages.start.round()} a ${ages.end.round()} anos',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                RangeSlider(
                  values: ages,
                  min: 18,
                  max: 80,
                  divisions: 62,
                  labels: RangeLabels(
                    '${ages.start.round()}',
                    '${ages.end.round()}',
                  ),
                  onChanged: (v) => set(() => ages = v),
                ),
                const SizedBox(height: 16),
                Text(
                  'Cruzar caminhos nos últimos: $days ${days == 1 ? 'dia' : 'dias'}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Slider(
                  value: days.toDouble(),
                  min: 1,
                  max: 30,
                  divisions: 29,
                  label: '$days',
                  onChanged: (v) => set(() => days = v.round()),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Interesse compartilhado',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: interest,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  items: interests
                      .map(
                        (i) => DropdownMenuItem(
                          value: i,
                          child: Text(i.isEmpty ? 'Qualquer interesse' : i),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => set(() => interest = v ?? ''),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      await attempt(context, () async {
        await api.updateSettings({
          'min_age': ages.start.round(),
          'max_age': ages.end.round(),
          'period_days': days,
          'interest': interest,
        });
        if (context.mounted) toast(context, 'Preferências atualizadas.');
      });
    }
  }

  Future<void> resetPreferences() async {
    if (!await confirm(
      context,
      'Restaurar configurações?',
      'Esta ação redefine suas preferências de descoberta e alertas para os padrões seguros. Seu perfil e conversas continuam intactos.',
    )) {
      return;
    }
    await attempt(context, () async {
      await api.updateSettings({
        ...defaults,
        'timezone_offset': DateTime.now().timeZoneOffset.inMinutes,
      });
      if (mounted) {
        setState(() {});
        toast(context, 'Preferências restauradas para o padrão.');
      }
    });
  }

  Api get api => widget.api;
  void open(Widget page) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));

  Future<void> setting(String key, dynamic value) async {
    if (busy) return;
    setState(() => busy = true);
    await attempt(context, () async {
      await api.updateSettings({key: value});
      refreshStorage();
      if (mounted) toast(context, 'Preferência salva.');
    });
    if (mounted) setState(() => busy = false);
  }

  Future<void> edit() => editProfile(context, api);

  Future<void> password() => showPasswordDialog(context, api);

  Future<void> verify() async {
    final context = this.context;
    await attempt(context, () async {
      final status = await api.request('GET', '/verification');
      if (!context.mounted) return;
      if (status['status'] == 'pending') {
        toast(
          context,
          'Sua solicitação de verificação está salva e aguarda revisão.',
        );
        return;
      }
      if (!await confirm(
        context,
        'Solicitar selo de verificação?',
        PlatformSupport.current.cameraCapture
            ? 'Tire uma selfie para revisão segura de autenticidade. Não há reconhecimento facial automático comercial. A selfie é removida após a validação.'
            : 'Escolha uma foto do dispositivo para validação manual de perfil.',
      )) {
        return;
      }
      final photo = await pickPhoto(
        camera: PlatformSupport.current.cameraCapture,
      );
      if (photo == null) return;
      await api.request('POST', '/verification', {'selfie': photo});
      if (context.mounted) {
        toast(
          context,
          'Foto enviada com sucesso! Seu selo será ativado após análise.',
        );
      }
    });
  }

  void zones() => open(ZonesScreen(api: api));

  void blocks() => open(
    RemoteList(
      api: api,
      path: '/blocks',
      title: 'Pessoas bloqueadas',
      itemBuilder: (c, p, reload) => Card(
        child: ListTile(
          leading: const Icon(Icons.block),
          title: Text(p['name']),
          trailing: TextButton(
            onPressed: () async {
              if (await confirm(
                    c,
                    'Desbloquear usuário?',
                    'Essa pessoa voltará a poder cruzar caminhos com você no radar.',
                  ) &&
                  c.mounted) {
                await attempt(c, () async {
                  await api.request('DELETE', '/blocks/${p['id']}');
                  reload();
                });
              }
            },
            child: const Text('Desbloquear'),
          ),
        ),
      ),
    ),
  );

  void reports() => open(
    RemoteList(
      api: api,
      path: '/reports',
      title: 'Minhas denúncias',
      itemBuilder: (_, r, _) => Card(
        child: ListTile(
          leading: const Icon(Icons.flag_outlined),
          title: Text(r['reason']),
          subtitle: Text(r['detail']),
          trailing: Text(
            r['status'] == 'resolved' ? 'Revisada' : 'Em análise',
          ),
        ),
      ),
    ),
  );

  void tickets() => open(
    RemoteList(
      api: api,
      path: '/tickets',
      title: 'Meus atendimentos',
      itemBuilder: (_, r, _) => Card(
        child: ListTile(
          leading: const Icon(Icons.support_agent_rounded),
          title: Text(r['subject']),
          subtitle: Text(r['detail']),
          trailing: Text(r['status'] == 'resolved' ? 'Resolvido' : 'Aberto'),
        ),
      ),
    ),
  );

  Future<void> support() async {
    final context = this.context;
    final subject = await input(
      context,
      'Como podemos ajudar?',
      hint: 'Assunto do atendimento',
    );
    if (subject == null || subject.isEmpty || !context.mounted) return;
    final detail = await input(context, 'Conte os detalhes');
    if (detail == null || detail.isEmpty || !context.mounted) return;
    await attempt(context, () async {
      await api.request('POST', '/tickets', {
        'subject': subject,
        'detail': detail,
      });
      if (context.mounted) {
        toast(context, 'Solicitação enviada para nossa equipe.');
      }
    });
  }

  Future<void> export() async {
    final context = this.context;
    await attempt(context, () async {
      final data = await api.request('GET', '/export');
      if (!context.mounted) return;
      final pretty = const JsonEncoder.withIndent('  ').convert(data);
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Seus dados (LGPD / Privacidade)'),
          content: SizedBox(
            width: 650,
            height: MediaQuery.sizeOf(context).height * .55,
            child: SingleChildScrollView(
              child: SelectableText(
                pretty,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Fechar'),
            ),
            FilledButton.icon(
              onPressed: () => copyText(c, pretty),
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copiar JSON'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> clearMediaCache() async {
    if (!await confirm(
      context,
      'Limpar cache de mídia?',
      'Fotos e áudios temporários armazenados no dispositivo serão liberados para economizar espaço. Suas mensagens de texto não serão afetadas.',
    )) return;
    refreshStorage();
    if (mounted) toast(context, 'Cache temporário de mídia liberado!');
  }

  Widget section(
    String title,
    List<Widget> children, {
    IconData? icon,
    String? subtitle,
    String? badge,
  }) {
    final group = switch (title) {
      'Armazenamento e dados' => 'Dados',
      'Privacidade e descoberta' => 'Descoberta',
      'Conversas, notificações e som' => 'Notificações',
      'Segurança e suporte' => 'Segurança',
      'Sua conta' => 'Conta',
      'Aparência e tela OLED' => 'Aparência',
      'Workout e atividades' => 'Workout',
      'Permissões do dispositivo' => 'Permissões',
      _ => title,
    };
    if (category != 'Tudo' && category != group) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: context.coral, size: 22),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              if (badge != null) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: context.coral.withValues(alpha: isDark ? 0.22 : 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: context.coral,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: context.muted, height: 1.4),
            ),
          ],
          const SizedBox(height: 12),
          LiquidGlassContainer(
            padding: EdgeInsets.zero,
            borderRadius: 22,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Column(children: children),
            ),
          ),
        ],
      ),
    );
  }

  Widget toggle(
    String title,
    String subtitle,
    String key, {
    IconData? icon,
  }) => SwitchListTile(
    value: api.settings[key] == true,
    onChanged: busy ? null : (v) => setting(key, v),
    secondary: icon != null ? Icon(icon, color: context.muted) : null,
    title: Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
    subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, height: 1.4)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
  );

  Widget _buildThemeCard({
    required AppThemePreference pref,
    required AppThemePreference selectedPref,
    required Brightness systemBrightness,
  }) {
    final isSelected = pref == selectedPref;
    final isDarkOled = pref == AppThemePreference.dark;
    final isLight = pref == AppThemePreference.light;
    final isSystem = pref == AppThemePreference.system;
    final isScreenDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: busy ? null : () => setting('theme_mode', pref.value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? context.coral.withValues(alpha: isScreenDark ? 0.22 : 0.12)
                : (isScreenDark ? const Color(0xFF0C0E16) : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? context.coral
                  : (isScreenDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : const Color(0xFFE2E6F2)),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: context.coral.withValues(alpha: 0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mini preview thumbnail
              Container(
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isDarkOled
                      ? Colors.black
                      : (isLight ? const Color(0xFFF6F7FB) : null),
                  gradient: isSystem
                      ? const LinearGradient(
                          colors: [Colors.black, Color(0xFFF6F7FB)],
                          stops: [0.5, 0.5],
                        )
                      : null,
                  border: Border.all(
                    color: isDarkOled
                        ? const Color(0xFF262A3B)
                        : const Color(0xFFD7DCE8),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Icon(
                    isDarkOled
                        ? Icons.dark_mode_rounded
                        : (isLight
                            ? Icons.light_mode_rounded
                            : Icons.brightness_auto_rounded),
                    color: isDarkOled
                        ? const Color(0xFF8E6EFD)
                        : (isLight ? const Color(0xFF6F4BD8) : Colors.white),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      pref.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: isSelected ? context.coral : context.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle_rounded,
                      color: context.coral,
                      size: 15,
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                isDarkOled
                    ? 'Preto puro (#000000)'
                    : (isLight ? 'Lavanda suave' : 'Acompanha o SO'),
                style: TextStyle(
                  fontSize: 10,
                  color: context.muted,
                  height: 1.25,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: api,
    builder: (context, _) => content(context),
  );

  Widget content(BuildContext context) {
    final p = api.me;
    if (p == null) return const SizedBox.shrink();
    final s = api.settings;
    final currentThemePref = AppThemePreference.fromValue(s['theme_mode']);
    final systemBrightness = MediaQuery.platformBrightnessOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final categories = [
      'Tudo',
      'Aparência',
      'Workout',
      'Descoberta',
      'Notificações',
      'Dados',
      'Permissões',
      'Segurança',
      'Conta',
    ];

    final content = ListView(
      key: const PageStorageKey('settings-scroll'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: context.pageInsets,
      children: [
        PageTitle(
          'Seu aplicativo',
          'Configurações',
          'Privacidade, aparência, proximidade e dados. Tudo no seu controle.',
        ),

        // Category filter chips
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final cat = categories[idx];
              final isSelected = category == cat;
              return ChoiceChip(
                label: Text(cat),
                selected: isSelected,
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                onSelected: (_) => setState(() => category = cat),
              );
            },
          ),
        ),

        if (busy)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(),
          ),

        const SizedBox(height: 18),

        // User Profile Card
        LiquidGlassContainer(
          borderRadius: 24,
          padding: context.cardInsets,
          child: Row(
            children: [
              PersonAvatar(
                p,
                radius: MediaQuery.sizeOf(context).width < 400 ? 28 : 42,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${p['name']}, ${p['age']}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (p['verified'] == true) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_rounded, color: Colors.blueAccent, size: 18),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      p['goal']?.toString().isNotEmpty == true
                          ? p['goal'].toString()
                          : 'Procurando novas conexões',
                      style: TextStyle(fontSize: 12, color: context.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: context.coral.withValues(alpha: isDark ? 0.22 : 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        p['verified'] == true
                            ? '✓ Perfil Verificado'
                            : 'Toque para editar dados e fotos',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: context.coral,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: edit,
                tooltip: 'Editar perfil completo',
                icon: const Icon(Icons.edit_outlined, size: 18),
              ),
            ],
          ),
        ),

        // SEÇÃO: APARÊNCIA & TEMA OLED
        section(
          'Aparência e tela OLED',
          icon: Icons.palette_outlined,
          badge: isDark ? 'OLED Ativo' : null,
          subtitle: 'Escolha seu estilo visual ou economize bateria em telas OLED.',
          [
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Modo de Exibição',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'O tema escuro utiliza preto puro (#000000), desligando os pixels em telas OLED para economia máxima de bateria.',
                    style: TextStyle(color: context.muted, fontSize: 11, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _buildThemeCard(
                        pref: AppThemePreference.dark,
                        selectedPref: currentThemePref,
                        systemBrightness: systemBrightness,
                      ),
                      const SizedBox(width: 8),
                      _buildThemeCard(
                        pref: AppThemePreference.light,
                        selectedPref: currentThemePref,
                        systemBrightness: systemBrightness,
                      ),
                      const SizedBox(width: 8),
                      _buildThemeCard(
                        pref: AppThemePreference.system,
                        selectedPref: currentThemePref,
                        systemBrightness: systemBrightness,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Current Active Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF140F26)
                          : const Color(0xFFEDE7FB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: context.coral.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isDark
                              ? Icons.battery_charging_full_rounded
                              : Icons.wb_sunny_rounded,
                          size: 16,
                          color: context.coral,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            currentThemePref == AppThemePreference.system
                                ? 'Automático: Seguindo seu dispositivo (${systemBrightness == Brightness.dark ? 'Escuro OLED' : 'Claro'}).'
                                : currentThemePref == AppThemePreference.dark
                                    ? 'Tema Escuro OLED (#000000): Pixels pretos desligados, economia de bateria ativa.'
                                    : 'Tema Claro: Interface suave em tons de lavanda e alto contraste solar.',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFD6C8FF) : const Color(0xFF4A329A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Accessibility & scale
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Escala do texto',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      Text(
                        '${(s['text_scale'] as num? ?? 100).round()}%',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: context.coral,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: (s['text_scale'] as num? ?? 100).toDouble(),
                    min: 80,
                    max: 130,
                    divisions: 5,
                    label: '${(s['text_scale'] as num? ?? 100).round()}%',
                    onChanged: busy
                        ? null
                        : (v) => setting('text_scale', v.round()),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F121C) : const Color(0xFFF7F8FC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Tevi: Aproxime-se de pessoas onde seus caminhos se cruzam.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            toggle(
              'Reduzir animações',
              'Transições instantâneas para acessibilidade e menor consumo.',
              'reduce_motion',
              icon: Icons.motion_photos_off_rounded,
            ),
            toggle(
              'Efeito Vidro Líquido (Liquid Glass Blur)',
              'Ativa desfoque translúcido e reflexos dinâmicos nos cartões.',
              'liquid_glass_blur',
              icon: Icons.blur_on_rounded,
            ),
          ],
        ),

        // SEÇÃO: WORKOUT & ATIVIDADES FÍSICAS
        section(
          'Workout e atividades',
          icon: Icons.fitness_center_rounded,
          badge: _workoutActive ? 'Treinando Agora' : null,
          subtitle: 'Conecte-se com pessoas com metas de treino e academia.',
          [
            SwitchListTile(
              value: _workoutActive,
              onChanged: _loadingWorkout ? null : _toggleWorkout,
              secondary: Icon(
                Icons.local_fire_department_rounded,
                color: _workoutActive ? const Color(0xFFFF7A28) : context.muted,
              ),
              title: const Text(
                'Modo Workout Ativo',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                _workoutActive
                    ? 'Seu status está visível no radar de parceiros de treino.'
                    : 'Ative para encontrar pessoas treinando no mesmo momento.',
                style: const TextStyle(fontSize: 11, height: 1.4),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.sports_gymnastics_rounded),
              title: const Text('Meta de treino principal'),
              subtitle: Text('Foco atual: $_workoutGoal'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final goals = [
                  'Hipertrofia',
                  'Emagrecimento',
                  'Resistência',
                  'Funcional',
                  'Corrida',
                  'Yoga e mobilidade',
                  'Crossfit',
                ];
                final selected = await showDialog<String>(
                  context: context,
                  builder: (c) => SimpleDialog(
                    title: const Text('Escolha sua meta'),
                    children: goals
                        .map(
                          (g) => SimpleDialogOption(
                            onPressed: () => Navigator.pop(c, g),
                            child: Row(
                              children: [
                                Icon(
                                  g == _workoutGoal
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked,
                                  color: g == _workoutGoal ? context.coral : context.muted,
                                  size: 18,
                                ),
                                const SizedBox(width: 12),
                                Text(g),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                );
                if (selected != null && mounted) {
                  setState(() => _workoutGoal = selected);
                  try {
                    await widget.api.request('POST', '/workout/status', {
                      'active': _workoutActive,
                      'goal': selected,
                    });
                    if (mounted) toast(context, 'Meta atualizada para $selected.');
                  } catch (_) {}
                }
              },
            ),
            const Divider(height: 1),
            toggle(
              'Notificar parceiros de treino próximos',
              'Receba avisos discretos quando usuários com metas parecidas estiverem por perto.',
              'notify_workout',
              icon: Icons.notifications_active_outlined,
            ),

          ],
        ),

        // SEÇÃO: PRIVACIDADE E DESCOBERTA
        section(
          'Privacidade e descoberta',
          icon: Icons.radar_rounded,
          subtitle: 'Controle como e quando seus caminhos se cruzam com outras pessoas.',
          [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF00C853).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF00C853).withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.shield_rounded,
                    color: Color(0xFF00C853),
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Armazenamento 100% Local (On-Device)',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00C853),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Seus dados NÃO são enviados para nenhum servidor na nuvem nem para dispositivos externos. Conversas, histórico de cruzamentos, modos de treino e preferências ficam armazenados exclusivamente na memória segura deste aparelho.',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            toggle(
              'Participar dos cruzamentos',
              'Habilita o radar para registrar encontros por proximidade.',
              'discovery',
              icon: Icons.explore_outlined,
            ),
            toggle(
              'Modo Invisível (Ghost Mode)',
              'Navegue pelo aplicativo sem registrar presença ou aparecer no radar alheio.',
              'invisible',
              icon: Icons.visibility_off_outlined,
            ),
            toggle(
              'Certificação de proximidade por BLE',
              'Emite e escuta sinais Bluetooth Low Energy para certificar com precisão que os aparelhos estiveram próximos.',
              'ble_proximity',
              icon: Icons.bluetooth_searching_rounded,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.tune_rounded),
              title: const Text('Preferências de busca e cruzamento'),
              subtitle: Text(
                '${s['min_age']}–${s['max_age']} anos • últimos ${s['period_days']} dias • ${s['interest'] == '' ? 'todos os interesses' : s['interest']}',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: busy ? null : discoveryPreferences,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.schedule_rounded),
              title: const Text('Horário ativo de participação'),
              subtitle: Text(
                '${clockLabel(s['start_hour'], s['start_minute'] ?? 0)} às ${clockLabel(s['end_hour'], s['end_minute'] ?? 0)} • horário local',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final start = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                    hour: s['start_hour'],
                    minute: s['start_minute'] ?? 0,
                  ),
                );
                if (start == null || !context.mounted) return;
                final end = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                    hour: s['end_hour'] == 24 ? 0 : s['end_hour'],
                    minute: s['end_minute'] ?? 0,
                  ),
                );
                if (end != null && context.mounted) {
                  await attempt(
                    context,
                    () => api.updateSettings({
                      'start_hour': start.hour,
                      'end_hour': end.hour == 0 && end.minute == 0
                          ? 24
                          : end.hour,
                      'start_minute': start.minute,
                      'end_minute': end.minute,
                      'timezone_offset': DateTime.now().timeZoneOffset.inMinutes,
                    }),
                  );
                }
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('Zonas privadas (Casa e Trabalho)'),
              subtitle: const Text(
                'Impede registros em um raio de 500 metros em locais protegidos.',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: zones,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('Restaurar perfis ocultados'),
              subtitle: const Text('Perfis que você descartou poderão reaparecer.'),
              onTap: () => attempt(context, () async {
                await api.request('POST', '/hidden/restore');
                if (context.mounted) {
                  toast(context, 'Perfis ocultados restaurados com sucesso.');
                }
              }),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined),
              title: const Text('Apagar histórico de cruzamentos'),
              subtitle: const Text('Remove registros de encontros passados. Seus matches continuam salvos.'),
              onTap: () async {
                if (await confirm(
                      context,
                      'Apagar histórico de cruzamentos?',
                      'Essa ação remove os pontos de cruzamento registrados. Suas conversas e conexões existentes não serão apagadas.',
                    ) &&
                    context.mounted) {
                  await attempt(context, () async {
                    await api.request('DELETE', '/history');
                    if (context.mounted) toast(context, 'Histórico de cruzamentos apagado.');
                  });
                }
              },
            ),
          ],
        ),

        // SEÇÃO: CONVERSAS, NOTIFICAÇÕES E SOM
        section(
          'Conversas, notificações e som',
          icon: Icons.notifications_outlined,
          subtitle: 'Alertas discretos, confirmações e feedback tátil.',
          [
            toggle(
              'Confirmação de leitura',
              'Informa nas conversas quando a outra pessoa leu sua mensagem.',
              'read_receipts',
              icon: Icons.done_all_rounded,
            ),
            toggle(
              'Efeitos sonoros',
              'Sons sutis de confirmação ao conectar ou enviar mensagens.',
              'sound_effects',
              icon: Icons.volume_up_outlined,
            ),
            toggle(
              'Feedback háptico (Vibração)',
              'Vibração suave ao detectar um encontro por proximidade.',
              'haptic_feedback',
              icon: Icons.vibration_rounded,
            ),
            const Divider(height: 1),
            toggle(
              'Notificar novos matches',
              'Avisos imediatos ao desbloquear conexão mútua.',
              'notify_matches',
              icon: Icons.favorite_border_rounded,
            ),
            toggle(
              'Notificar mensagens',
              'Avisos discretos na barra, sem prévia de conteúdo pessoal.',
              'notify_messages',
              icon: Icons.chat_bubble_outline_rounded,
            ),
            toggle(
              'Notificar cruzamentos de caminhos',
              'Aviso sutil ao passar pelo mesmo local de alguém compatível.',
              'notify_encounters',
              icon: Icons.people_outline_rounded,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.nightlight_outlined),
              title: const Text('Horário silencioso (Não Perturbe)'),
              subtitle: Text(
                '${clockLabel(s['quiet_start'], s['quiet_start_minute'] ?? 0)} às ${clockLabel(s['quiet_end'], s['quiet_end_minute'] ?? 0)} • alertas silenciados',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final start = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                    hour: s['quiet_start'],
                    minute: s['quiet_start_minute'] ?? 0,
                  ),
                );
                if (start == null || !context.mounted) return;
                final end = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                    hour: s['quiet_end'],
                    minute: s['quiet_end_minute'] ?? 0,
                  ),
                );
                if (end != null && context.mounted) {
                  await attempt(
                    context,
                    () => api.updateSettings({
                      'quiet_start': start.hour,
                      'quiet_end': end.hour,
                      'quiet_start_minute': start.minute,
                      'quiet_end_minute': end.minute,
                    }),
                  );
                }
              },
            ),
          ],
        ),

        // SEÇÃO: ARMAZENAMENTO E DADOS
        section(
          'Armazenamento e dados',
          icon: Icons.storage_rounded,
          subtitle: 'Controle os dados salvos localmente no seu dispositivo.',
          [
            FutureBuilder<SyncInfo>(
              future: storage,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const ListTile(
                    leading: Icon(Icons.cloud_off_rounded),
                    title: Text('Armazenamento local operando em modo offline.'),
                  );
                }
                if (!snapshot.hasData) {
                  return const ListTile(
                    leading: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    title: Text('Calculando espaço utilizado…'),
                  );
                }
                return const ListTile(
                  leading: Icon(
                    Icons.phonelink_lock_rounded,
                    color: Color(0xFF00C853),
                  ),
                  title: Text('Modo Estritamente Local (Zero Nuvem)'),
                  subtitle: Text(
                    'Operação 100% on-device. Todos os registros residem exclusivamente neste aparelho.',
                  ),
                );
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.cleaning_services_outlined),
              title: const Text('Limpar cache de mídia temporário'),
              subtitle: const Text('Libera espaço em disco sem apagar suas conversas.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: clearMediaCache,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: const Text('Exportar meus dados (LGPD)'),
              subtitle: const Text('Gera cópia completa de suas informações em formato JSON.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: export,
            ),
          ],
        ),

        // SEÇÃO: PERMISSÕES DO DISPOSITIVO
        section(
          'Permissões do dispositivo',
          icon: Icons.security_rounded,
          subtitle: 'Acessos exigidos para detecção de presença e mídias.',
          [
            FutureBuilder<LocationPermissionInfo>(
              future: permissionStatus,
              builder: (context, snapshot) {
                final status = snapshot.data;
                final authorized = status?.granted ?? false;
                final serviceOn = status?.enabled ?? false;
                return ListTile(
                  leading: Icon(
                    authorized && serviceOn
                        ? Icons.check_circle_rounded
                        : Icons.warning_amber_rounded,
                    color: authorized && serviceOn ? Colors.green : Colors.orange,
                  ),
                  title: const Text('Radar & Localização'),
                  subtitle: Text(
                    status?.description ?? 'Verificando permissões…',
                  ),
                  trailing: TextButton(
                    onPressed: () => attempt(context, widget.permissions.openSettings),
                    child: const Text('Ajustar'),
                  ),
                );
              },
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Text(
                'Bluetooth e localização são usados exclusivamente para encontrar pessoas próximas em tempo real. Câmera e microfone são acessados estritamente quando você decide enviar uma foto ou áudio.',
                style: TextStyle(fontSize: 11, height: 1.5, color: Colors.grey),
              ),
            ),
          ],
        ),

        // SEÇÃO: SEGURANÇA E SUPORTE
        section(
          'Segurança e suporte',
          icon: Icons.verified_user_outlined,
          subtitle: 'Criptografia ponta a ponta e ferramentas de proteção.',
          [
            Container(
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.coral.withValues(alpha: isDark ? 0.14 : 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.coral.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_rounded, color: context.coral, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Criptografia Ponta a Ponta Ativa',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Suas mensagens e áudios são cifrados com chaves seguras geradas neste dispositivo.',
                          style: TextStyle(fontSize: 11, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ListenableBuilder(
              listenable: SafeMeetupService.instance,
              builder: (context, _) {
                final safe = SafeMeetupService.instance;
                return Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(
                        Icons.shield_rounded,
                        color: Colors.blueAccent,
                      ),
                      title: const Text(
                        'Modo Encontro Seguro',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: const Text(
                        'Timer de check-in, código de coação e falsa ligação para encontros presenciais. Ativo por padrão.',
                        style: TextStyle(fontSize: 11, height: 1.4),
                      ),
                      value: safe.isEnabled,
                      onChanged: (v) async {
                        await safe.setEnabled(v);
                        if (context.mounted) {
                          toast(
                            context,
                            v
                                ? 'Modo Encontro Seguro ativado.'
                                : 'Modo Encontro Seguro desativado.',
                          );
                        }
                      },
                    ),
                    if (safe.isEnabled) ...[
                      const Divider(height: 1),
                      ListTile(
                        leading: const SizedBox(width: 24),
                        title: const Text('Ajustar contato, PIN e falsa ligação'),
                        subtitle: Text(
                          safe.config.hasTrustedContact
                              ? 'Contato: ${safe.config.trustedContactName} (${safe.config.trustedContactPhone})'
                              : 'Toque para cadastrar seu contato de emergência e PIN',
                          style: TextStyle(fontSize: 11, color: context.muted),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => showSafeMeetupSheet(
                          context,
                          partnerName: 'Encontro Geral',
                          partnerId: 'general',
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.verified_outlined),
              title: const Text('Solicitar selo de verificação'),
              subtitle: const Text('Revisão autêntica por selfie temporária.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: verify,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.block_rounded),
              title: const Text('Pessoas bloqueadas'),
              subtitle: const Text('Gerencie quem você impediu de cruzar seu caminho.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: blocks,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Acompanhar minhas denúncias'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: reports,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.support_agent_rounded),
              title: const Text('Falar com a equipe de suporte'),
              subtitle: const Text('Tire dúvidas ou reporte problemas.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: support,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.inbox_outlined),
              title: const Text('Meus chamados e atendimentos'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: tickets,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.tips_and_updates_outlined),
              title: const Text('Dicas para encontros seguros'),
              subtitle: const Text('Orientações de cuidado para encontros na vida real.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showDialog<void>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Conheça no seu tempo'),
                  content: const SingleChildScrollView(
                    child: Text(
                      '• Combine primeiros encontros sempre em lugares públicos e movimentados.\n\n'
                      '• Avise um amigo ou familiar de confiança sobre onde você vai e com quem.\n\n'
                      '• Cuide do seu próprio transporte e pertences.\n\n'
                      '• Jamais envie dinheiro, senhas ou dados bancários para qualquer usuário.\n\n'
                      '• Você tem o poder de encerrar uma conversa, bloquear ou denunciar a qualquer momento.',
                      style: TextStyle(height: 1.5, fontSize: 13),
                    ),
                  ),
                  actions: [
                    FilledButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Entendi'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // SEÇÃO: SUA CONTA E SESSÃO
        section(
          'Sua conta',
          icon: Icons.person_outline_rounded,
          subtitle: 'Acesse suas credenciais, redefina ajustes ou encerre a sessão.',
          [
            ListTile(
              leading: const Icon(Icons.alternate_email_rounded),
              title: const Text('E-mail conectado'),
              subtitle: SelectableText(p['email'] ?? 'Usuário Local'),
              trailing: const Icon(Icons.lock_outline, size: 18),
            ),
            if (p['auth_provider'] != 'google' && p['auth_provider'] != 'apple') ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.password_rounded),
                title: const Text('Alterar senha local'),
                subtitle: const Text('Atualiza sua senha e encerra outras sessões ativas.'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: busy ? null : password,
              ),
            ],
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.restore_rounded),
              title: const Text('Restaurar preferências padrão'),
              subtitle: const Text('Pausa a descoberta e volta aos valores originais.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: busy ? null : resetPreferences,
            ),
            if (p['role'] == 'admin') ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('Painel de moderação administrativa'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => open(AdminScreen(api: api)),
              ),
            ],
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.orange),
              title: const Text('Encerrar sessão (Sair)'),
              subtitle: const Text('Desconecta deste aparelho com segurança.'),
              onTap: () async {
                if (await confirm(
                  context,
                  'Deseja sair?',
                  'Você poderá se reconectar a qualquer momento.',
                )) {
                  if (context.mounted) attempt(context, api.logout);
                }
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                Icons.delete_forever_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Excluir minha conta permanentemente',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text('Apaga seu perfil, cruzamentos e fotos em definitivo.'),
              onTap: () async {
                if (!await confirm(
                  context,
                  'Excluir sua conta permanentemente?',
                  'Esta ação é irreversível. Todos os seus dados, fotos e conversas locais serão removidos em definitivo.',
                )) {
                  return;
                }
                if (!context.mounted) return;
                if (p['auth_provider'] == 'google') {
                  await showDialog<void>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Confirme com Google'),
                      content: SizedBox(
                        width: 320,
                        child: GoogleLoginButton(
                          api: api,
                          onToken: (token) async {
                            await api.deleteGoogleAccount(token);
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          },
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Cancelar'),
                        ),
                      ],
                    ),
                  );
                  return;
                }
                if (p['auth_provider'] == 'apple') {
                  await showDialog<void>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Confirme com a Apple'),
                      content: SizedBox(
                        width: 320,
                        child: AppleLoginButton(
                          api: api,
                          onToken: (token) async {
                            await api.deleteAppleAccount(token);
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          },
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Cancelar'),
                        ),
                      ],
                    ),
                  );
                  return;
                }
                final pw = await input(
                  context,
                  'Confirme sua senha atual',
                  secret: true,
                );
                if (pw != null && context.mounted) {
                  await attempt(context, () async {
                    await api.deleteAccount(pw);
                  });
                }
              },
            ),
          ],
        ),

        // SEÇÃO: SOBRE O TEVI
        if (category == 'Tudo' || category == 'Conta') ...[
          const SizedBox(height: 24),
          LiquidGlassContainer(
            padding: const EdgeInsets.all(16),
            borderRadius: 18,
            child: Row(
              children: [
                const TeviLogo(compact: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tevi v1.0.0 • Privacidade em 1º Lugar',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sem anúncios invasivos • Sem assinaturas ocultas • P2P Seguro',
                        style: TextStyle(color: context.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Tevi • Manifesto de Privacidade'),
                      content: const SingleChildScrollView(
                        child: Text(
                          'O Tevi foi desenhado sob a filosofia Local-First e Privacidade Absoluta:\n\n'
                          '1. Armazenamento 100% Local (On-Device): Todos os seus dados (perfil, conversas, preferências, histórico de encontros e modos) ficam salvos exclusivamente na memória segura do seu aparelho. NADA é enviado ou armazenado em servidores na nuvem nem em dispositivos externos.\n\n'
                          '2. Zero Nuvem e Sem Rastreamento: O Tevi não possui banco de dados centralizado em nuvem. Não fazemos perfilamento publicitário, não vendemos dados e não gravamos suas rotas ou trajetos.\n\n'
                          '3. Proximidade Física Direta (BLE): A certificação de cruzamento e os sinais de rádio Bluetooth Low Energy operam estritamente de aparelho para aparelho por ondas de rádio locais, sem passar pela internet ou triangulação externa.\n\n'
                          '4. Soberania Total do Usuário: Você tem controle total para apagar registros, pausar o radar, ativar o modo invisível ou exportar seus dados. Ao desinstalar o app, tudo é destruído imediatamente pois não existe cópia na web.',
                          style: TextStyle(height: 1.5, fontSize: 13),
                        ),
                      ),
                      actions: [
                        FilledButton(
                          onPressed: () => Navigator.pop(c),
                          child: const Text('Entendi'),
                        ),
                      ],
                    ),
                  ),
                  child: const Text('Sobre'),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 36),
        Center(
          child: Text(
            'tevi. • conexões onde a vida acontece\nSem pressa. No seu controle.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.muted, fontSize: 11, height: 1.8),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );

    return widget.embedded
        ? content
        : Scaffold(
            appBar: AppBar(title: const Text('Configurações')),
            body: content,
          );
  }
}

class ZonesScreen extends StatefulWidget {
  final Api api;
  const ZonesScreen({super.key, required this.api});
  @override
  State<ZonesScreen> createState() => _ZonesScreenState();
}

class _ZonesScreenState extends State<ZonesScreen> {
  late Future<dynamic> future;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    future = widget.api.request('GET', '/zones');
  }

  void reload() {
    if (!mounted) return;
    final next = widget.api.request('GET', '/zones');
    setState(() {
      future = next;
    });
  }

  Future<void> add() async {
    final context = this.context;
    final label = await input(
      context,
      'Nome da zona privada',
      hint: 'Ex.: Casa ou trabalho',
    );
    if (label == null || label.isEmpty || !context.mounted) return;
    setState(() => busy = true);
    await attempt(context, () async {
      final p = await locate();
      await widget.api.request('POST', '/zones', {
        'label': label,
        'lat': p.latitude,
        'lon': p.longitude,
      });
      reload();
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Zonas privadas')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: busy ? null : add,
      icon: const Icon(Icons.add_location_alt_outlined),
      label: Text(busy ? 'Localizando…' : 'Proteger local atual'),
    ),
    body: ListView(
      padding: context.cardInsets,
      children: [
        const Text(
          'Adicione o local onde você está para impedir registros em um raio de 500 metros. As coordenadas não aparecem para outras pessoas.',
          style: TextStyle(height: 1.6),
        ),
        const SizedBox(height: 20),
        FutureBuilder<dynamic>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return EmptyState(
                'Não foi possível carregar',
                '${snapshot.error}',
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final zones = snapshot.data as List;
            if (zones.isEmpty) {
              return const EmptyState(
                'Seus lugares, só seus',
                'Proteja sua casa e seu trabalho.',
                icon: Icons.shield_outlined,
              );
            }
            return Column(
              children: zones
                  .map(
                    (z) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.shield_outlined),
                        title: Text(z['label']),
                        subtitle: const Text('Raio protegido: 500 metros'),
                        trailing: IconButton(
                          tooltip: 'Remover zona',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            if (await confirm(
                                  context,
                                  'Remover zona?',
                                  'Este local deixará de ser protegido.',
                                ) &&
                                context.mounted) {
                              await attempt(context, () async {
                                await widget.api.request(
                                  'DELETE',
                                  '/zones/${z['id']}',
                                );
                                reload();
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 100),
      ],
    ),
  );
}
