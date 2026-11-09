import '../services/platform_support.dart';
import '../services/location_service.dart';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'theme/app_theme.dart';
import 'theme/liquid_glass.dart';
import 'components/crossing_popup.dart';
import '../services/map_launcher_service.dart';
import 'components/social_links_bar.dart';
import 'components/workout_section.dart';
import '../services/api.dart';
import 'common.dart';

class DiscoverScreen extends StatefulWidget {
  final Api api;
  final VoidCallback onMatches;
  const DiscoverScreen({super.key, required this.api, required this.onMatches});
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  List<dynamic> people = [];
  bool loading = true, locating = false;
  String? error;
  String filter = 'Todos';
  final Set<String> pending = {};
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final result = await widget.api.request('GET', '/encounters');
      if (mounted) {
        setState(() {
          people = result;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> action(Map<String, dynamic> person, String action) async {
    final context = this.context;
    if (pending.contains(person['id'])) return;
    setState(() => pending.add(person['id']));
    await attempt(context, () async {
      final result = await widget.api.request(
        'POST',
        '/people/${person['id']}/$action',
      );
      await load();
      if (!context.mounted) return;
      if (result['match_id'] != null) {
        final region = result['region'] ??
            person['region'] ??
            'Cruzamento por proximidade';
        final go = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            icon: Icon(Icons.favorite, color: context.coral, size: 52),
            title: const Text(
              'Os caminhos se encontraram!',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Você e ${person['name']} demonstraram interesse mútuo.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: context.lavender,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: context.coral.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: context.coral.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.place_rounded,
                              color: context.coral,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Local do encontro',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  region,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => MapLauncherService.openMapLocation(
                            regionName: region,
                          ),
                          icon: const Icon(Icons.map_outlined, size: 16),
                          label: const Text('Consultar local no Maps'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Continuar explorando'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                onPressed: () => Navigator.pop(c, true),
                label: const Text('Ir para conversas'),
              ),
            ],
          ),
        );
        if (go == true) widget.onMatches();
      } else {
        toast(
          context,
          action == 'hide'
              ? 'Perfil ocultado.'
              : action == 'block'
              ? 'Pessoa bloqueada.'
              : action == 'unlike'
              ? 'Curtida desfeita.'
              : 'Interesse guardado em segredo.',
        );
      }
    });
    if (mounted) setState(() => pending.remove(person['id']));
  }

  Future<void> checkIn() async {
    final context = this.context;
    setState(() => locating = true);
    await attempt(context, () async {
      final p = await locate();
      final result = await widget.api.request('POST', '/presence', {
        'lat': p.latitude,
        'lon': p.longitude,
        'accuracy': p.accuracy,
        'observed_at': p.timestamp.millisecondsSinceEpoch / 1000,
      });
      if (context.mounted) {
        toast(
          context,
          result['private_zone'] == true
              ? 'Você está em uma zona privada. Nenhum cruzamento foi registrado.'
              : 'Localização atualizada. Novos cruzamentos aparecem após 15 minutos.',
        );
      }
      await load();
    });
    if (mounted) setState(() => locating = false);
  }

  Future<void> filters() async {
    final context = this.context;
    final s = widget.api.settings;
    var ages = RangeValues(
      (s['min_age'] as num).toDouble(),
      (s['max_age'] as num).toDouble(),
    );
    String interest = s['interest'];
    int days = s['period_days'];
    final save = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, change) => AlertDialog(
          title: Text('Seu jeito de encontrar'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Idade: ${ages.start.round()} a ${ages.end.round()} anos'),
                RangeSlider(
                  values: ages,
                  min: 18,
                  max: 110,
                  divisions: 92,
                  labels: RangeLabels(
                    '${ages.start.round()}',
                    '${ages.end.round()}',
                  ),
                  onChanged: (v) => change(() => ages = v),
                ),
                DropdownButtonFormField<int>(
                  initialValue: days,
                  decoration: InputDecoration(labelText: 'Período'),
                  items: [1, 3, 7]
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(
                            v == 1 ? 'Últimas 24 horas' : 'Últimos $v dias',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => change(() => days = v!),
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: interest,
                  decoration: InputDecoration(labelText: 'Interesse'),
                  items:
                      [
                            '',
                            'Café',
                            'Música',
                            'Cinema',
                            'Arte',
                            'Viagens',
                            'Corrida',
                            'Livros',
                            'Fotografia',
                          ]
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text(
                                v.isEmpty ? 'Todos os interesses' : v,
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => change(() => interest = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text('Aplicar filtros'),
            ),
          ],
        ),
      ),
    );
    if (save == true && context.mounted) {
      await attempt(context, () async {
        await widget.api.updateSettings({
          'min_age': ages.start.round(),
          'max_age': ages.end.round(),
          'period_days': days,
          'interest': interest,
        });
        await load();
      });
    }
  }

  Future<void> scanNearbyCrossings() async {
    final context = this.context;
    await attempt(context, () async {
      await widget.api.request('POST', '/presence', {
        'lat': -23.5587,
        'lon': -46.6833,
        'accuracy': 15,
        'observed_at': DateTime.now().millisecondsSinceEpoch / 1000,
        'region': 'São Paulo (Pinheiros / Vila Madalena)',
      });
      await load();
      if (context.mounted) {
        toast(context, 'Cruzamentos e caminhos ao redor atualizados!');
      }
    });
  }

  Future<void> invite() async {
    final context = this.context;
    await attempt(context, () async {
      final result = await widget.api.request('POST', '/invites');
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('Um oi, pessoalmente'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Mostre este código para quem você acabou de conhecer. Válido por 10 minutos, para uma pessoa.',
              ),
              SizedBox(height: 20),
              QrImageView(
                data: result['code'],
                size: 180,
                backgroundColor: Colors.white,
                semanticsLabel: 'Código de convite presencial',
              ),
              SelectableText(
                result['code'],
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                'O convite cria um cruzamento. A conversa ainda depende de interesse mútuo.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => copyText(c, result['code']),
              child: Text('Copiar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c),
              child: Text('Entendi'),
            ),
          ],
        ),
      );
    });
  }

  void detail(Map<String, dynamic> p) => showCrossingPopup(
    context: context,
    person: p,
    busy: pending.contains(p['id']),
    onLike: () => action(p, p['liked'] == '' ? 'like' : 'unlike'),
    onReject: () => action(p, 'hide'),
  );
  @override
  Widget build(BuildContext context) {
    final s = widget.api.settings;
    final active = s['discovery'] == true && s['invisible'] != true;
    final shown = people
        .where(
          (p) =>
              filter == 'Todos' ||
              (filter == 'Interesse salvo' ? p['liked'] != '' : p['count'] > 1),
        )
        .toList();
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        key: const PageStorageKey('discover-scroll'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: context.pageInsets,
        children: [
          PageTitle(
            'Descobrir',
            'Pessoas no seu caminho',
            'Um encontro pode virar uma boa conversa.',
            action: IconButton(
              onPressed: load,
              tooltip: 'Atualizar cruzamentos',
              icon: Icon(Icons.refresh_rounded, size: 21),
            ),
          ),
          Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: context.lavender,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      active ? Icons.radar_rounded : Icons.pause_rounded,
                      color: context.coral,
                      size: 22,
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          active ? 'Descoberta ativa' : 'Descoberta pausada',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Você escolhe quando aparecer.',
                          style: TextStyle(fontSize: 12, color: context.muted),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: active,
                    onChanged: (v) => attempt(context, () async {
                      await widget.api.updateSettings({
                        'discovery': v,
                        'invisible': false,
                      });
                      await load();
                    }),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed:
                    active && !locating && PlatformSupport.current.location
                    ? checkIn
                    : null,
                icon: Icon(
                  locating
                      ? Icons.hourglass_empty_rounded
                      : Icons.my_location_rounded,
                  size: 16,
                ),
                label: Text(
                  locating ? 'Localizando…' : 'Atualizar meu caminho',
                ),
              ),
              OutlinedButton.icon(
                onPressed: active ? invite : null,
                icon: const Icon(Icons.qr_code_rounded, size: 17),
                label: const Text('Convite presencial'),
              ),
              OutlinedButton.icon(
                onPressed: active ? scanNearbyCrossings : null,
                icon: const Icon(Icons.radar_rounded, size: 16),
                label: const Text('Escanear arredores'),
              ),
              TextButton(
                onPressed: active
                    ? () async {
                        final code = await input(
                          context,
                          'Inserir código do convite',
                        );
                        if (code != null &&
                            code.isNotEmpty &&
                            context.mounted) {
                          await attempt(context, () async {
                            await widget.api.request(
                              'POST',
                              '/invites/redeem',
                              {'code': code},
                            );
                            await load();
                          });
                        }
                      }
                    : null,
                child: Text('Tenho um código'),
              ),
            ],
          ),
          SizedBox(height: 16),
          WorkoutSection(api: widget.api),
          SizedBox(height: 34),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Seus cruzamentos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.4,
                  ),
                ),
              ),
              Text(
                '${shown.length}',
                style: TextStyle(fontSize: 12, color: context.muted),
              ),
              SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: filters,
                icon: Icon(Icons.tune_rounded, size: 16),
                label: Text('Filtros'),
              ),
            ],
          ),
          SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Todos', 'Interesse salvo', 'Caminhos recorrentes']
                .map(
                  (v) => ChoiceChip(
                    label: Text(v),
                    showCheckmark: false,
                    selected: filter == v,
                    onSelected: (_) => setState(() => filter = v),
                  ),
                )
                .toList(),
          ),
          SizedBox(height: 22),
          if (loading)
            Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (error != null)
            Card(
              child: Column(
                children: [
                  EmptyState(
                    'Não foi possível carregar',
                    error!,
                    icon: Icons.wifi_off_rounded,
                  ),
                  TextButton(onPressed: load, child: Text('Tentar novamente')),
                  SizedBox(height: 18),
                ],
              ),
            )
          else if (shown.isEmpty)
            Card(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 26),
                child: EmptyState(
                  'Novos caminhos começam aqui',
                  'Ative a descoberta e atualize seu caminho. Quando houver cruzamentos, eles aparecerão aqui após 15 minutos.',
                  icon: Icons.alt_route_rounded,
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, space) {
                final columns = space.maxWidth > 900
                    ? 3
                    : space.maxWidth > 580
                    ? 2
                    : 1;
                final width = (space.maxWidth - (columns - 1) * 16) / columns;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: shown.map((item) {
                    final p = Map<String, dynamic>.from(item);
                    return SizedBox(
                      width: width,
                      child: _CrossingCard(
                        person: p,
                        busy: pending.contains(p['id']),
                        onDetails: () => detail(p),
                        onLike: () =>
                            action(p, p['liked'] == '' ? 'like' : 'unlike'),
                        onReject: () => action(p, 'hide'),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded, size: 12, color: context.muted),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Curtidas privadas. Interesse mútuo. Sem localização exata.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: context.muted,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CrossingCard extends StatelessWidget {
  const _CrossingCard({
    required this.person,
    required this.busy,
    required this.onDetails,
    required this.onLike,
    required this.onReject,
  });
  final Map<String, dynamic> person;
  final bool busy;
  final VoidCallback onDetails, onLike, onReject;

  @override
  Widget build(BuildContext context) {
    final p = person;
    final liked = p['liked'] != '';
    final hasSocials = p['socials'] is Map && (p['socials'] as Map).isNotEmpty;

    return LiquidGlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(18),
      onTap: onDetails,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                children: [
                  PersonAvatar(p, radius: 29),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
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
                            '${p['name']}, ${p['age']}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -.4,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (p['verified'] == true) ...[
                          const SizedBox(width: 5),
                          Icon(Icons.verified_rounded, color: context.coral, size: 16),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 12, color: context.muted),
                        const SizedBox(width: 4),
                        Text(
                          p['period'] ?? 'Recentemente',
                          style: TextStyle(color: context.muted, fontSize: 11),
                        ),
                      ],
                    ),
                    if ((p['workout_goal'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.fitness_center_rounded, size: 11, color: Color(0xFFFF7A28)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Treino: ${p['workout_goal']}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF7A28),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              LiquidGlassIconButton(
                icon: Icons.open_in_full_rounded,
                iconSize: 16,
                size: 34,
                tooltip: 'Ver foto grande e redes sociais',
                onPressed: onDetails,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            p['bio'].toString().isEmpty
                ? 'Cruzaram caminhos na cidade.'
                : p['bio'],
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: context.ink, height: 1.5),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: (p['interests'] as List)
                .take(3)
                .map(
                  (v) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: context.lavender.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: context.coral.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Text(
                      v,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: context.ink,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          if (hasSocials) ...[
            const SizedBox(height: 12),
            SocialLinksBar(
              socials: Map<String, dynamic>.from(p['socials'] as Map),
              compact: true,
            ),
          ],
          const SizedBox(height: 12),
          Divider(color: context.line.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.place_rounded, size: 15, color: context.coral),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  p['region'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.ink,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => MapLauncherService.openMapLocation(
                  regionName: p['region'],
                ),
                icon: const Icon(Icons.map_outlined, size: 14),
                label: const Text('Maps', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: context.line),
                    foregroundColor: context.muted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: busy ? null : onReject,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Recusar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: liked ? context.lavender : context.coral,
                    foregroundColor: liked
                        ? context.coral
                        : Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 1,
                  ),
                  onPressed: busy ? null : onLike,
                  icon: Icon(
                    liked
                        ? Icons.favorite_rounded
                        : Icons.favorite_outline_rounded,
                    size: 18,
                  ),
                  label: Text(liked ? 'Match!' : 'Aceitar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> reportPerson(BuildContext context, Api api, String id) async {
  final reason = await showDialog<String>(
    context: context,
    builder: (c) => SimpleDialog(
      title: Text('O que aconteceu?'),
      children:
          [
                'Assédio',
                'Perfil falso',
                'Golpe ou spam',
                'Conteúdo impróprio',
                'Pessoa menor de idade',
                'Outro motivo',
              ]
              .map(
                (r) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(c, r),
                  child: Padding(padding: EdgeInsets.all(8), child: Text(r)),
                ),
              )
              .toList(),
    ),
  );
  if (reason == null || !context.mounted) return;
  final detail = await input(
    context,
    'Conte um pouco mais',
    hint: 'Detalhes para a equipe de moderação',
  );
  if (detail == null || !context.mounted) return;
  await attempt(context, () async {
    await api.request('POST', '/reports', {
      'target': id,
      'reason': reason,
      'detail': detail,
    });
    if (context.mounted) {
      toast(context, 'Denúncia salva. O envio depende do provedor conectado.');
    }
  });
}
