import '../models/user_settings.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'theme/liquid_glass.dart';
import '../services/api.dart';
import 'common.dart';
import 'discover.dart';
import 'conversations.dart';
import 'events.dart';
import 'profile.dart';
import 'settings.dart';
import '../services/location_heartbeat_service.dart';

class HomeScreen extends StatefulWidget {
  final Api api;
  const HomeScreen({super.key, required this.api});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Timer? heartbeat;
  bool foreground = true, checking = false;
  Set<String>? knownNotifications;

  @override
  void initState() {
    super.initState();
    LocationHeartbeatService.instance(widget.api);
    WidgetsBinding.instance.addObserver(this);
    _startHeartbeat(const Duration(seconds: 15));
  }

  void _startHeartbeat(Duration interval) {
    heartbeat?.cancel();
    heartbeat = Timer.periodic(interval, (_) => tick());
  }

  @override
  void dispose() {
    heartbeat?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasForeground = foreground;
    foreground = state == AppLifecycleState.resumed;
    if (!wasForeground && foreground) {
      _startHeartbeat(const Duration(seconds: 15));
      tick();
    } else if (wasForeground && !foreground) {
      _startHeartbeat(const Duration(seconds: 60));
    }
  }

  Future<void> tick() async {
    if (checking || widget.api.me == null) return;
    checking = true;
    try {
      final api = widget.api;
      final notifications = await api.request('GET', '/notifications') as List;
      if (!mounted) return;
      final fresh = notifications
          .where(
            (n) =>
                n['seen'] == 0 &&
                knownNotifications != null &&
                !knownNotifications!.contains(n['id']),
          )
          .toList();
      knownNotifications = notifications.map((n) => n['id'] as String).toSet();
      final s = api.settings;
      final local = DateTime.now();
      final quiet = timeWindowContains(
        local.hour * 60 + local.minute,
        s['quiet_start'] * 60 + (s['quiet_start_minute'] ?? 0),
        s['quiet_end'] * 60 + (s['quiet_end_minute'] ?? 0),
        fullDayWhenEqual: false,
      );
      if (fresh.isNotEmpty && !quiet && mounted && foreground) {
        toast(context, fresh.first['title']);
      }
      // LocationHeartbeatService gerencia seu ciclo adaptativo de 30s / 15s de forma autônoma
    } catch (_) {
      // Resilient error handling prevents background and foreground unhandled crashes
    } finally {
      checking = false;
    }
  }

  int selected = 0;
  static const labels = [
    'Descobrir',
    'Conversas',
    'Lugares',
    'Perfil',
    'Configurações',
  ];
  static const icons = [
    Icons.explore_outlined,
    Icons.chat_bubble_outline_rounded,
    Icons.place_outlined,
    Icons.person_outline_rounded,
    Icons.settings_outlined,
  ];
  static const activeIcons = [
    Icons.explore_rounded,
    Icons.chat_bubble_rounded,
    Icons.place_rounded,
    Icons.person_rounded,
    Icons.settings_rounded,
  ];
  static const subtitles = [
    'Pessoas que cruzaram caminhos com você',
    'Mensagens diretas e conexões P2P',
    'Locais e eventos de interesse em comum',
    'Suas informações e fotos no Tevi',
    'Preferências, privacidade e conta',
  ];
  void selectPage(int index) {
    if (selected == index) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => selected = index);
  }

  Widget get currentPage => switch (selected) {
    0 => DiscoverScreen(api: widget.api, onMatches: () => selectPage(1)),
    1 => ConversationsScreen(api: widget.api),
    2 => EventsScreen(api: widget.api),
    3 => ProfileScreen(api: widget.api),
    _ => SettingsScreen(api: widget.api, embedded: true),
  };

  void notifications() => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => RemoteList(
        api: widget.api,
        path: '/notifications',
        title: 'Notificações',
        itemBuilder: (c, item, reload) => Card(
          child: ListTile(
            contentPadding: EdgeInsets.all(18),
            leading: () {
              final title = (item['title'] ?? '').toString().trim();
              final runes = title.runes.toList();
              if (runes.isNotEmpty && runes.first > 127) {
                final emojiChar = String.fromCharCode(runes.first);
                return Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.coral.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    emojiChar,
                    style: const TextStyle(fontSize: 22),
                  ),
                );
              }
              return Icon(
                Icons.notifications_none_rounded,
                color: context.coral,
              );
            }(),
            title: Text(item['title']),
            subtitle: Text(item['body']),
            trailing: item['seen'] == 0
                ? IconButton(
                    tooltip: 'Marcar como lidas',
                    icon: Icon(Icons.done_all),
                    onPressed: () => attempt(c, () async {
                      await widget.api.request('POST', '/notifications');
                      reload();
                    }),
                  )
                : null,
          ),
        ),
      ),
    ),
  );
  void _confirmLogout() {
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text(
          'Deseja realmente sair? Suas conversas P2P e preferências locais permanecerão salvas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(c);
              widget.api.logout();
            },
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }

  /// Drawer fixo para tablets e telas amplas, utilizando as mesmas abas do BottomNavigationBar
  /// com design contemporâneo Liquid Glass e ergonomia otimizada para toque em telas grandes.
  Widget _buildFixedTabletDrawer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final me = widget.api.me ?? {};
    final displayName = (me['name'] ?? 'Você').toString();
    final isVerified = me['verified'] == true || me['verified'] == 1;

    return Container(
      width: 270,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131522) : const Color(0xFFFAF9FD),
        border: Border(
          right: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
            width: 1.2,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Cabeçalho de Marca Liquid Glass
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
              child: Row(
                children: [
                  const TeviLogo(),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: context.coral.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.coral.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'TABLET',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: context.coral,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // 2. Card de Mini Perfil do Usuário
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LiquidGlassContainer(
                borderRadius: 18,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                onTap: () => selectPage(3),
                child: Row(
                  children: [
                    PersonAvatar(me, radius: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (isVerified) ...[
                                const SizedBox(width: 4),
                                Icon(Icons.verified_rounded, size: 14, color: context.coral),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF4CAF50),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'P2P Ativo',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.muted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 18, color: context.muted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // 3. Título da Seção
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'MENU PRINCIPAL',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: context.muted,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 4. Lista das Mesmas Abas da BottomNavigationBar
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: labels.length,
                itemBuilder: (context, i) {
                  final isSelected = selected == i;
                  final label = labels[i] == 'Configurações' ? 'Ajustes' : labels[i];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => selectPage(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark
                                  ? const Color(0xFF6F4BD8).withValues(alpha: 0.28)
                                  : context.coral.withValues(alpha: 0.14))
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? context.coral.withValues(alpha: 0.35)
                                : Colors.transparent,
                            width: 1.2,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: context.coral.withValues(alpha: 0.12),
                                    blurRadius: 12,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? activeIcons[i] : icons[i],
                              size: 22,
                              color: isSelected ? context.coral : context.muted,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? context.ink : context.muted,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Container(
                                width: 5,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: context.coral,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // 5. Rodapé Informativo e Logout
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  LiquidGlassContainer(
                    borderRadius: 16,
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.shield_outlined, size: 20, color: context.coral),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Privacidade Total',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Sem rastreamento • 100% P2P',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: context.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _confirmLogout,
                    icon: Icon(Icons.logout_rounded, size: 17, color: context.muted),
                    label: Text(
                      'Sair da conta',
                      style: TextStyle(fontSize: 12.5, color: context.muted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Padrão de Tablet e telas amplas: largura >= 600dp (Android / iPad / foldables abertos)
        final isTablet = constraints.maxWidth >= 600;

        return Scaffold(
          // No tablet, a barra superior de telefone é desnecessária pois o Drawer Fixo organiza tudo
          appBar: isTablet
              ? null
              : AppBar(
                  toolbarHeight: 60,
                  title: const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: TeviLogo(),
                  ),
                  actions: [
                    IconButton(
                      onPressed: notifications,
                      tooltip: 'Notificações',
                      icon: const Icon(Icons.notifications_none_rounded),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
          body: Row(
            children: [
              // No tablet: Drawer fixo na lateral esquerda com as abas do app
              if (isTablet) _buildFixedTabletDrawer(context),

              // Área principal de conteúdo adaptativo para telas grandes
              Expanded(
                key: const ValueKey('page-content'),
                child: Column(
                  children: [
                    // Barra Superior Exclusiva do Tablet
                    if (isTablet)
                      Container(
                        height: 70,
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF141724)
                              : Colors.white,
                          border: Border(
                            bottom: BorderSide(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.06),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    labels[selected] == 'Configurações' ? 'Ajustes' : labels[selected],
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitles[selected],
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: context.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.wifi_tethering_rounded, size: 14, color: Color(0xFF4CAF50)),
                                  SizedBox(width: 5),
                                  Text(
                                    'P2P WebRTC Conectado',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2E7D32),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              onPressed: notifications,
                              tooltip: 'Notificações',
                              icon: const Icon(Icons.notifications_none_rounded, size: 22),
                            ),
                          ],
                        ),
                      ),

                    // Conteúdo Ativo com largura máxima ergonômica
                    Expanded(
                      key: const ValueKey('active-page'),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: SafeArea(
                            top: false,
                            bottom: false,
                            child: currentPage,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: isTablet || MediaQuery.viewInsetsOf(context).bottom > 0
              ? null
              : DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: context.line)),
                  ),
                  child: NavigationBar(
                    labelBehavior: constraints.maxWidth < 380 ||
                            MediaQuery.textScalerOf(context).scale(12) > 15
                        ? NavigationDestinationLabelBehavior.onlyShowSelected
                        : NavigationDestinationLabelBehavior.alwaysShow,
                    selectedIndex: selected,
                    onDestinationSelected: selectPage,
                    destinations: List.generate(
                      labels.length,
                      (i) => NavigationDestination(
                        key: ValueKey('navigation-$i'),
                        icon: Icon(icons[i], size: 22),
                        label: labels[i] == 'Configurações'
                            ? 'Ajustes'
                            : labels[i],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
